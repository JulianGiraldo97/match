/** Exposes original persistence exceptions when validating a deployment in another org. */
@IsTest
private with sharing class MatQuotePersistenceDiagnosticTest {
  @TestSetup
  static void setupData() {
    MatQuoteTestDataFactory.createScenario();
  }

  @IsTest
  static void savesStandardQuoteAndLinesInUserMode() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    MatQuoteData data = MatQuoteData.load(opportunity.Id);

    Test.startTest();
    // Call the real writer directly so the service cannot replace its exception.
    Id quoteId = MatQuoteRecordWriter.save(data, 'Diagnóstico de cotización');
    Test.stopTest();

    Quote savedQuote = [
      SELECT OpportunityId, Subtotal, TotalPrice, Discount
      FROM Quote
      WHERE Id = :quoteId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      opportunity.Id,
      savedQuote.OpportunityId,
      'Link the source opportunity.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa__c,
      savedQuote.Subtotal,
      'Preserve the source subtotal.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa_negociada__c,
      savedQuote.TotalPrice,
      'Preserve the negotiated total.'
    );
    Assert.areEqual(
      opportunity.Mat_Descuento__c.setScale(2, RoundingMode.HALF_UP),
      savedQuote.Discount.setScale(2, RoundingMode.HALF_UP),
      'Preserve the weighted discount.'
    );
    Assert.areEqual(
      data.services.size(),
      [
        SELECT COUNT()
        FROM QuoteLineItem
        WHERE QuoteId = :quoteId
        WITH SYSTEM_MODE
      ],
      'Save exactly one standard line per source service.'
    );
  }

  @IsTest
  static void savesAndLinksNativePdfInUserMode() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    MatQuoteData data = MatQuoteData.load(opportunity.Id);
    Id quoteId = MatQuoteRecordWriter.save(data, 'Diagnóstico de PDF');

    Test.startTest();
    Map<String, Id> savedIds = new MatQuotePdfFileWriter()
      .save(
        new QuoteDocument(
          QuoteId = quoteId,
          Document = Blob.valueOf('%PDF-1.4 diagnostic test')
        ),
        opportunity.Id
      );
    Test.stopTest();

    assertNativePdfLinks(savedIds, quoteId, opportunity.Id);
  }

  private static void assertNativePdfLinks(
    Map<String, Id> savedIds,
    Id quoteId,
    Id opportunityId
  ) {
    Assert.areEqual(
      quoteId,
      savedIds.get('quoteId'),
      'Return the saved Quote ID.'
    );
    QuoteDocument document = [
      SELECT QuoteId, ContentVersionDocumentId
      FROM QuoteDocument
      WHERE Id = :savedIds.get('quoteDocumentId')
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(quoteId, document.QuoteId, 'Store a native Quote PDF.');
    Assert.areEqual(
      savedIds.get('contentVersionId'),
      document.ContentVersionDocumentId,
      'Return its native version.'
    );
    ContentVersion version = [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id = :document.ContentVersionDocumentId
      WITH SYSTEM_MODE
    ];
    Assert.isNotNull(
      version.ContentDocumentId,
      'Salesforce must create the file.'
    );
    Assert.areEqual(
      savedIds.get('contentDocumentId'),
      version.ContentDocumentId,
      'Return the generated file.'
    );
    Set<Id> expectedLinks = new Set<Id>{ quoteId, opportunityId };
    List<ContentDocumentLink> links = [
      SELECT LinkedEntityId
      FROM ContentDocumentLink
      WHERE
        ContentDocumentId = :version.ContentDocumentId
        AND LinkedEntityId IN :expectedLinks
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      expectedLinks.size(),
      links.size(),
      'Link the same PDF to Quote and Opportunity.'
    );
  }
}
