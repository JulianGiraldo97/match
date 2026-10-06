/** Stores one native Quote PDF and shares Salesforce's generated file with Opportunity. */
public with sharing class MatQuotePdfFileWriter implements MatQuoteService.FileWriter {
  /**
   * Reads the latest saved PDF of the selected Quote with record and field access enforced.
   * @param quoteId Quote opened for preview and email.
   * @return Saved IDs without rerendering live opportunity data.
   * @throws AuraHandledException When the Quote PDF is unavailable or inaccessible.
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Id> getPreviewContext(Id quoteId) {
    if (quoteId == null || quoteId.getSObjectType() != Quote.SObjectType) {
      throw previewError();
    }
    try {
      List<QuoteDocument> documents = [
        SELECT Id, QuoteId, ContentVersionDocumentId
        FROM QuoteDocument
        WHERE QuoteId = :quoteId
        WITH USER_MODE
        ORDER BY CreatedDate DESC, Id DESC
        LIMIT 1
      ];
      if (documents.isEmpty()) {
        throw previewError();
      }
      QuoteDocument pdf = documents[0];
      ContentVersion version = [
        SELECT ContentDocumentId
        FROM ContentVersion
        WHERE Id = :pdf.ContentVersionDocumentId
        WITH USER_MODE
        LIMIT 1
      ];
      return savedIds(pdf, version.ContentDocumentId);
    } catch (QueryException error) {
      throw previewError();
    }
  }

  /**
   * Salesforce creates the ContentVersion and Quote file relationship on insertion.
   * @param pdf Native document containing the rendered bytes and Quote ID.
   * @param opportunityId Opportunity receiving the same file.
   * @return Saved record IDs for native preview and email navigation.
   */
  public Map<String, Id> save(QuoteDocument pdf, Id opportunityId) {
    insert as user pdf;
    QuoteDocument savedPdf = [
      SELECT Id, QuoteId, ContentVersionDocumentId
      FROM QuoteDocument
      WHERE Id = :pdf.Id
      WITH USER_MODE
      LIMIT 1
    ];
    ContentVersion version = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :savedPdf.ContentVersionDocumentId
      WITH USER_MODE
      LIMIT 1
    ];
    insert as user new ContentDocumentLink(
      ContentDocumentId = version.ContentDocumentId,
      LinkedEntityId = opportunityId,
      ShareType = 'V'
    );
    return savedIds(savedPdf, version.ContentDocumentId);
  }

  private static Map<String, Id> savedIds(QuoteDocument pdf, Id documentId) {
    return new Map<String, Id>{
      'quoteId' => pdf.QuoteId,
      'quoteDocumentId' => pdf.Id,
      'contentVersionId' => pdf.ContentVersionDocumentId,
      'contentDocumentId' => documentId
    };
  }

  private static AuraHandledException previewError() {
    AuraHandledException error = new AuraHandledException(
      Label.Mat_Quote_PreviewError
    );
    error.setMessage(Label.Mat_Quote_PreviewError);
    return error;
  }
}
