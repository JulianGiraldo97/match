/** Tests independent file creation, failures and the PDF boundary. */
@IsTest
private with sharing class MatQuoteServiceTest {
  @TestSetup
  static void setupData() {
    MatQuoteTestDataFactory.createScenario();
  }

  private with sharing class FakeRenderer implements MatQuoteService.PdfRenderer {
    private Boolean fails;
    private Blob result;
    private Id receivedId;
    private Integer statementsAtRender;
    FakeRenderer(Blob result, Boolean fails) {
      this.result = result;
      this.fails = fails;
    }
    public Blob render(Id opportunityId) {
      receivedId = opportunityId;
      statementsAtRender = Limits.getDmlStatements();
      if (fails) {
        throw new MatQuoteData.QuoteException('Synthetic renderer failure');
      }
      return result;
    }
  }

  @IsTest
  static void savesAndLinksThePdfAfterRendering() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    Blob contents = Blob.valueOf('%PDF-1.4 synthetic test PDF');
    FakeRenderer fake = new FakeRenderer(contents, false);
    MatQuoteService.renderer = fake;
    Test.startTest();
    Id documentId = MatQuoteService.generateQuote(opportunityId);
    Test.stopTest();
    ContentVersion version = [
      SELECT Id, Title, PathOnClient, VersionData
      FROM ContentVersion
      WHERE ContentDocumentId = :documentId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(
      EncodingUtil.base64Encode(contents),
      EncodingUtil.base64Encode(version.VersionData),
      'Save the returned PDF bytes.'
    );
    Assert.areEqual(
      opportunityId,
      fake.receivedId,
      'Render the selected opportunity.'
    );
    Assert.areEqual(
      0,
      fake.statementsAtRender,
      'No DML or savepoint may precede the callout.'
    );
    Assert.isTrue(
      version.PathOnClient.endsWith('.pdf'),
      'Save with a PDF extension.'
    );
    Assert.isTrue(
      version.Title.startsWith('Cotizacion_Cotización principal_'),
      'Name the file for the opportunity.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE
          ContentDocumentId = :documentId
          AND LinkedEntityId = :opportunityId
        WITH SYSTEM_MODE
      ],
      'Create the Files relationship.'
    );
    Quote quote = [
      SELECT Id, OpportunityId
      FROM Quote
      WHERE OpportunityId = :opportunityId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(
      opportunityId,
      quote.OpportunityId,
      'Create the standard related Quote.'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE ContentDocumentId = :documentId AND LinkedEntityId = :quote.Id
        WITH SYSTEM_MODE
      ],
      'Share the same PDF with Quote.'
    );
    QuoteDocument nativePdf = [
      SELECT ContentVersionDocumentId, QuoteId
      FROM QuoteDocument
      WHERE QuoteId = :quote.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(
      version.Id,
      nativePdf.ContentVersionDocumentId,
      'Email uses the same stored PDF version.'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Do not create a duplicate file for Quote PDFs.'
    );
    Assert.areEqual(
      0,
      Limits.getEmailInvocations(),
      'Generation does not send email.'
    );
  }

  @IsTest
  static void preservesPreviousGenerations() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    MatQuoteService.renderer = new FakeRenderer(
      Blob.valueOf('%PDF-1.4 quote'),
      false
    );
    Test.startTest();
    Id firstDocumentId = MatQuoteService.generateQuote(opportunityId);
    Id secondDocumentId = MatQuoteService.generateQuote(opportunityId);
    Test.stopTest();
    Assert.areNotEqual(
      firstDocumentId,
      secondDocumentId,
      'Each explicit invocation creates an independent file.'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :opportunityId
        WITH SYSTEM_MODE
      ],
      'Preserve both opportunity files.'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Quote
        WHERE OpportunityId = :opportunityId
        WITH SYSTEM_MODE
      ],
      'Each generation keeps an independent Quote.'
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM QuoteDocument WITH SYSTEM_MODE],
      'Preserve both native PDFs.'
    );
  }

  @IsTest
  static void returnsValidationErrorWithoutRenderingOrSaving() {
    Id opportunityId = MatQuoteTestDataFactory.getEmptyOpportunity().Id;
    FakeRenderer fake = new FakeRenderer(Blob.valueOf('%PDF-1.4'), false);
    MatQuoteService.renderer = fake;
    Test.startTest();
    try {
      MatQuoteService.generateQuote(opportunityId);
      Assert.fail('Empty quote generation must be blocked.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_NoServices,
        error.getMessage(),
        'Preserve the actionable validation message.'
      );
    }
    Test.stopTest();
    Assert.isNull(fake.receivedId, 'Do not render an invalid quote.');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Do not create an empty file.'
    );
  }

  @IsTest
  static void handlesRendererFailureWithoutSaving() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    MatQuoteService.renderer = new FakeRenderer(null, true);
    Test.startTest();
    try {
      MatQuoteService.generateQuote(opportunityId);
      Assert.fail('A rendering failure must not create a file.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_GenerationError,
        error.getMessage(),
        'Do not disclose technical errors.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Do not leave a partial file.'
    );
  }

  @IsTest
  static void rejectsEmptyPdfBytes() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    MatQuoteService.renderer = new FakeRenderer(Blob.valueOf(''), false);
    Test.startTest();
    try {
      MatQuoteService.generateQuote(opportunityId);
      Assert.fail('An empty render result must not be saved.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_GenerationError,
        error.getMessage(),
        'Report a rendering failure.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Do not leave a blank PDF.'
    );
  }

  @IsTest
  static void sanitizesFileNames() {
    Test.startTest();
    String title = MatQuoteService.buildTitle('Campaña / video: "especial"?');
    Test.stopTest();
    Assert.isTrue(
      title.startsWith('Cotizacion_Campaña _ video_ _especial__'),
      'Replace unsafe file-name characters.'
    );
    Assert.isFalse(title.contains('/'), 'No path separator may survive.');
  }

  private with sharing class FailingWriter implements MatQuoteService.FileWriter {
    public Map<String, Id> save(QuoteDocument pdf, Id opportunityId) {
      new MatQuotePdfFileWriter().save(pdf, opportunityId);
      throw new SyntheticWriteException('Synthetic failure after insertion');
    }
  }

  private with sharing class SyntheticWriteException extends Exception {
  }

  @IsTest
  static void rollsBackPartialFileWrites() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    MatQuoteService.renderer = new FakeRenderer(
      Blob.valueOf('%PDF-1.4 quote'),
      false
    );
    MatQuoteService.fileWriter = new FailingWriter();
    Test.startTest();
    try {
      MatQuoteService.generateQuote(opportunityId);
      Assert.fail('A failed write must be rolled back.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_SaveError,
        error.getMessage(),
        'Report a user-safe save error.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Remove a partially inserted PDF.'
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :opportunityId
        WITH SYSTEM_MODE
      ],
      'Remove the partial file relationship.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote WITH SYSTEM_MODE],
      'Roll back the Quote header.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM QuoteLineItem WITH SYSTEM_MODE],
      'Roll back the detail.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM PricebookEntry WITH SYSTEM_MODE],
      'Roll back newly registered prices.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM QuoteDocument WITH SYSTEM_MODE],
      'Remove the native document after a partial failure.'
    );
  }

  @IsTest
  static void returnsPreviewAndEmailContext() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    MatQuoteService.renderer = new FakeRenderer(
      Blob.valueOf('%PDF-1.4 quote'),
      false
    );
    Test.startTest();
    Map<String, Id> result = MatQuoteService.generateQuoteForPreview(
      opportunityId
    );
    Test.stopTest();
    QuoteDocument nativePdf = [
      SELECT QuoteId, ContentVersionDocumentId
      FROM QuoteDocument
      WHERE Id = :result.get('quoteDocumentId')
      WITH SYSTEM_MODE
    ];
    ContentVersion version = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :nativePdf.ContentVersionDocumentId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      nativePdf.QuoteId,
      result.get('quoteId'),
      'Open the generated Quote for email.'
    );
    Assert.areEqual(
      nativePdf.ContentVersionDocumentId,
      result.get('contentVersionId'),
      'Preview the saved version.'
    );
    Assert.areEqual(
      version.ContentDocumentId,
      result.get('contentDocumentId'),
      'Use the same file in Files.'
    );
    Assert.areEqual(
      result,
      MatQuotePdfFileWriter.getPreviewContext(result.get('quoteId')),
      'Reopen the same saved file from Quote.'
    );
  }

  @IsTest
  static void rejectsPreviewWithoutSavedPdf() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    Test.startTest();
    try {
      MatQuotePdfFileWriter.getPreviewContext(opportunityId);
      Assert.fail('Do not preview unrelated records.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_PreviewError,
        error.getMessage(),
        'Return a safe preview message.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsNullPreviewId() {
    Test.startTest();
    try {
      MatQuotePdfFileWriter.getPreviewContext(null);
      Assert.fail('Require a Quote ID.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_PreviewError,
        error.getMessage(),
        'Return a safe preview message.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsQuoteWithoutPdf() {
    MatQuoteData data = MatQuoteData.load(
      MatQuoteTestDataFactory.getPrimaryOpportunity().Id
    );
    Id quoteId = MatQuoteRecordWriter.save(data, 'Cotización sin PDF');
    Test.startTest();
    try {
      MatQuotePdfFileWriter.getPreviewContext(quoteId);
      Assert.fail('A Quote without a PDF cannot be emailed through preview.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        Label.Mat_Quote_PreviewError,
        error.getMessage(),
        'Explain that the saved PDF is unavailable.'
      );
    }
    Test.stopTest();
  }
}
