/** Renders a PDF, creates a Quote and its lines, and saves everything atomically. */
public with sharing class MatQuoteService {
  @TestVisible
  private static PdfRenderer renderer = new VisualforceRenderer();

  @TestVisible
  private static FileWriter fileWriter = new MatQuotePdfFileWriter();

  /** Persistence boundary allows testing rollback after a partially completed write. */
  public interface FileWriter {
    /** @param pdf Quote PDF to store. @param opportunityId Record to link. @return Saved IDs. */
    Map<String, Id> save(QuoteDocument pdf, Id opportunityId);
  }

  /** PDF boundary substituted by tests instead of calling the unsupported test renderer. */
  public interface PdfRenderer {
    /** @param opportunityId Opportunity to render. @return PDF bytes. */
    Blob render(Id opportunityId);
  }

  /**
   * Generates a quote from committed data and links it to the opportunity.
   * @param opportunityId Opportunity selected by the record action.
   * @return ContentDocument ID for the standard Salesforce file preview.
   * @throws AuraHandledException A user-safe validation, access or generation error.
   */
  @AuraEnabled
  public static Id generateQuote(Id opportunityId) {
    return generateQuoteForPreview(opportunityId).get('contentDocumentId');
  }

  /**
   * Generates the native Quote PDF and returns its preview and email context.
   * @param opportunityId Opportunity selected by the record action.
   * @return Quote, QuoteDocument, ContentVersion and ContentDocument IDs.
   * @throws AuraHandledException A user-safe validation, access or generation error.
   */
  @AuraEnabled
  public static Map<String, Id> generateQuoteForPreview(Id opportunityId) {
    MatQuoteData data;
    try {
      data = MatQuoteData.load(opportunityId);
    } catch (MatQuoteData.QuoteException error) {
      throw handledError(error.getMessage());
    }
    if (
      !ContentVersion.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isCreateable() ||
      !ContentVersion.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isAccessible() ||
      !Quote.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isCreateable() ||
      !Quote.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isUpdateable() ||
      !QuoteDocument.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isCreateable() ||
      !QuoteLineItem.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .isCreateable()
    ) {
      throw handledError(Label.Mat_Quote_PermissionError);
    }
    try {
      MatQuoteRecordWriter.validateLines(data.services);
    } catch (MatQuoteData.QuoteException error) {
      throw handledError(error.getMessage());
    }

    Blob pdf;
    // Render before any DML or savepoint: getContentAsPDF is a callout.
    try {
      pdf = renderer.render(opportunityId);
      if (pdf == null || pdf.size() == 0) {
        throw new MatQuoteData.QuoteException(Label.Mat_Quote_GenerationError);
      }
    } catch (Exception error) {
      throw handledError(Label.Mat_Quote_GenerationError);
    }

    String title = buildTitle(data.opportunity.Name);
    Savepoint beforeSave = Database.setSavepoint();
    try {
      Id quoteId = MatQuoteRecordWriter.save(data, title);
      return fileWriter.save(
        new QuoteDocument(QuoteId = quoteId, Document = pdf),
        opportunityId
      );
    } catch (MatQuoteData.QuoteException error) {
      Database.rollback(beforeSave);
      throw handledError(error.getMessage());
    } catch (Exception error) {
      Database.rollback(beforeSave);
      throw handledError(Label.Mat_Quote_SaveError);
    }
  }

  @TestVisible
  private static String buildTitle(String opportunityName) {
    String safeName = opportunityName.replaceAll(
      '[\\\\/:*?"<>|\\p{Cntrl}]',
      '_'
    );
    // Leave room within Salesforce's title/path limits for the prefix and timestamp.
    if (safeName.length() > 180) {
      safeName = safeName.substring(0, 180);
    }
    return 'Cotizacion_' +
      safeName +
      '_' +
      Datetime.now().format('yyyyMMdd_HHmmss_SSS');
  }

  private static AuraHandledException handledError(String message) {
    AuraHandledException error = new AuraHandledException(message);
    error.setMessage(message);
    return error;
  }

  private with sharing class VisualforceRenderer implements PdfRenderer {
    public Blob render(Id opportunityId) {
      PageReference pdfPage = Page.MatOpportunityQuote;
      pdfPage.getParameters().put('id', String.valueOf(opportunityId));
      return pdfPage.getContentAsPDF();
    }
  }
}
