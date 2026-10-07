/** Verifies standard Quote snapshots, price-book registration and line constraints. */
@IsTest
private with sharing class MatQuoteRecordWriterTest {
  @TestSetup
  static void setupData() {
    MatQuoteTestDataFactory.createScenario();
  }

  private with sharing class Renderer implements MatQuoteService.PdfRenderer {
    Boolean called = false;
    public Blob render(Id opportunityId) {
      called = true;
      return Blob.valueOf('%PDF-1.4 quote test');
    }
  }

  private static Id generate(Id opportunityId) {
    MatQuoteService.renderer = new Renderer();
    Test.startTest();
    Id documentId = MatQuoteService.generateQuote(opportunityId);
    Test.stopTest();
    return documentId;
  }

  private static Quote getQuote(Id opportunityId) {
    return [
      SELECT
        Id,
        OpportunityId,
        AccountId,
        Pricebook2Id,
        Description,
        Mat_Moneda__c,
        Mat_Cliente__c,
        Mat_Nombre_oportunidad__c,
        Mat_Fecha_generacion__c,
        Subtotal,
        TotalPrice,
        Discount,
        Mat_Tarifa_moneda_extranjera__c,
        Mat_Tarifa_negociada_moneda_extranjera__c,
        Mat_Tarifa__c,
        Mat_Tarifa_negociada__c,
        Mat_Descuento__c,
        IsSyncing
      FROM Quote
      WHERE OpportunityId = :opportunityId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static List<QuoteLineItem> getLines(Id quoteId) {
    return [
      SELECT
        Id,
        Quantity,
        UnitPrice,
        Discount,
        Product2Id,
        SortOrder,
        Mat_Nombre_servicio__c,
        Mat_Tarifa__c,
        Mat_Descuento__c,
        Mat_Tarifa_negociada__c,
        Mat_Servicio_de_oportunidad__c
      FROM QuoteLineItem
      WHERE QuoteId = :quoteId
      WITH SYSTEM_MODE
      ORDER BY SortOrder
    ];
  }

  @IsTest
  static void snapshotsTheOpportunityHeader() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    Assert.areEqual(
      opportunity.AccountId,
      quote.AccountId,
      'Keep the related account.'
    );
    Assert.areEqual(
      opportunity.Name,
      quote.Mat_Nombre_oportunidad__c,
      'Capture the opportunity name.'
    );
    Assert.areEqual(
      'Cliente de prueba cotización',
      quote.Mat_Cliente__c,
      'Capture the client name.'
    );
    Assert.areEqual(
      opportunity.Mat_Moneda__c,
      quote.Mat_Moneda__c,
      'Store the commercial currency.'
    );
    Assert.areEqual(
      opportunity.Condiciones_comerciales__c,
      quote.Description,
      'Store the conditions and newlines.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa__c,
      quote.Subtotal,
      'Standard subtotal uses the service tariffs.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa_negociada__c,
      quote.TotalPrice,
      'Standard total uses each line discount.'
    );
    Assert.areEqual(
      opportunity.Mat_Descuento__c.setScale(2, RoundingMode.HALF_UP),
      quote.Discount.setScale(2, RoundingMode.HALF_UP),
      'Standard discount reflects the weighted line discounts.'
    );
    Assert.isNotNull(
      quote.Mat_Fecha_generacion__c,
      'Keep the generation date.'
    );
    Assert.isFalse(
      quote.IsSyncing,
      'Do not synchronize changes back to the opportunity.'
    );
  }

  @IsTest
  static void leavesLegacyQuoteTotalsUnused() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    Assert.isNull(quote.Mat_Tarifa__c, 'Do not populate the legacy tariff.');
    Assert.isNull(
      quote.Mat_Tarifa_negociada__c,
      'Do not populate the legacy total.'
    );
    Assert.isNull(
      quote.Mat_Descuento__c,
      'Do not populate the legacy discount.'
    );
  }

  @IsTest
  static void snapshotsForeignCurrencyValues() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    update as system new Opportunity(
      Id = opportunity.Id,
      Mat_Moneda__c = 'USD'
    );
    // Existing currency automation sets the initial rate; then save the test rate.
    update as system new Opportunity(
      Id = opportunity.Id,
      Mat_Tasa_de_cambio__c = 4000
    );
    opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    Assert.areEqual('USD', quote.Mat_Moneda__c, 'Keep the quoted currency.');
    Assert.areEqual(
      opportunity.Mat_Tarifa_moneda_extranjera__c
        ?.setScale(0, RoundingMode.HALF_UP),
      quote.Mat_Tarifa_moneda_extranjera__c,
      'Copy the saved formula result.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa_negociada_moneda_extranjera__c
        ?.setScale(0, RoundingMode.HALF_UP),
      quote.Mat_Tarifa_negociada_moneda_extranjera__c,
      'Copy the negotiated foreign tariff.'
    );
    update as system new Opportunity(
      Id = opportunity.Id,
      Mat_Tasa_de_cambio__c = 5000
    );
    Quote saved = getQuote(opportunity.Id);
    Assert.areEqual(
      quote.Mat_Tarifa_moneda_extranjera__c,
      saved.Mat_Tarifa_moneda_extranjera__c,
      'Keep the historical exchange result.'
    );
    Assert.areEqual(
      quote.Mat_Tarifa_negociada_moneda_extranjera__c,
      saved.Mat_Tarifa_negociada_moneda_extranjera__c,
      'Keep the historical negotiated result.'
    );
  }

  @IsTest
  static void preservesUnavailableForeignAmounts() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    update as system new Opportunity(
      Id = opportunity.Id,
      Mat_Moneda__c = 'EUR'
    );
    // Existing currency automation sets the initial rate; then save the test rate.
    update as system new Opportunity(
      Id = opportunity.Id,
      Mat_Tasa_de_cambio__c = null
    );
    opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    Assert.areEqual(
      opportunity.Mat_Tarifa_moneda_extranjera__c
        ?.setScale(0, RoundingMode.HALF_UP),
      quote.Mat_Tarifa_moneda_extranjera__c,
      'Do not manufacture a converted rate.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa_negociada_moneda_extranjera__c
        ?.setScale(0, RoundingMode.HALF_UP),
      quote.Mat_Tarifa_negociada_moneda_extranjera__c,
      'Preserve the formula result without conversion.'
    );
  }

  @IsTest
  static void preservesEveryLineAndItsSourcePrices() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    MatQuoteData source = MatQuoteData.load(opportunity.Id);
    generate(opportunity.Id);
    List<QuoteLineItem> lines = getLines(getQuote(opportunity.Id).Id);
    Assert.areEqual(
      source.services.size(),
      lines.size(),
      'Keep every row, including duplicate products.'
    );
    for (Integer index = 0; index < lines.size(); index++) {
      QuoteLineItem line = lines[index];
      Mat_Servicios_de_oportunidad__c service = source.services[index];
      Assert.areEqual(
        service.Id,
        line.Mat_Servicio_de_oportunidad__c,
        'Link each source row.'
      );
      Assert.areEqual(
        service.Mat_Servicio_de_talento__r.Servicio__c,
        line.Product2Id,
        'Use the product rather than talent.'
      );
      Assert.areEqual(
        service.Mat_Servicio_de_talento__r.Servicio__r.Name,
        line.Mat_Nombre_servicio__c,
        'Capture only the product name.'
      );
      Assert.areEqual(
        service.Mat_Tarifa__c,
        line.UnitPrice,
        'Use the opportunity-service tariff.'
      );
      Assert.areEqual(
        service.Mat_Tarifa__c,
        line.Mat_Tarifa__c,
        'Capture the original tariff.'
      );
      Assert.areEqual(
        service.Mat_Descuento__c,
        line.Discount,
        'Set the native line discount.'
      );
      Assert.areEqual(
        service.Mat_Descuento__c,
        line.Mat_Descuento__c,
        'Capture the original discount.'
      );
      Assert.areEqual(
        service.Mat_Tarifa_negociada__c,
        line.Mat_Tarifa_negociada__c,
        'Capture the saved negotiated tariff.'
      );
      Assert.areEqual(
        1,
        line.Quantity,
        'Represent one service per source row.'
      );
    }
  }

  @IsTest
  static void keepsPreviousValuesWhenTheSourceChanges() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    List<QuoteLineItem> originalLines = getLines(quote.Id);
    update as system new Mat_Servicios_de_oportunidad__c(
      Id = originalLines[0].Mat_Servicio_de_oportunidad__c,
      Mat_Tarifa__c = 999999,
      Mat_Descuento__c = 50
    );
    List<QuoteLineItem> savedLines = getLines(quote.Id);
    Quote savedQuote = getQuote(opportunity.Id);
    Assert.areEqual(
      originalLines[0].UnitPrice,
      savedLines[0].UnitPrice,
      'Keep historical line pricing.'
    );
    Assert.areEqual(
      quote.Subtotal,
      savedQuote.Subtotal,
      'Keep the historical summary.'
    );
  }

  @IsTest
  static void preservesRowsWithoutAProduct() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    List<Mat_Servicio_de_talento__c> catalogue = [
      SELECT Id, Servicio__c
      FROM Mat_Servicio_de_talento__c
      WITH SYSTEM_MODE
    ];
    for (Mat_Servicio_de_talento__c service : catalogue) {
      service.Servicio__c = null;
    }
    update as system catalogue;
    generate(opportunity.Id);
    List<QuoteLineItem> lines = getLines(getQuote(opportunity.Id).Id);
    Assert.areEqual(3, lines.size(), 'Preserve unnamed source rows.');
    for (QuoteLineItem line : lines) {
      Assert.areEqual(
        Label.Mat_Quote_MissingService,
        line.Mat_Nombre_servicio__c,
        'Use the explicit placeholder name.'
      );
    }
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Product2
        WHERE ProductCode = 'MATCH_QUOTE_UNNAMED_SERVICE'
        WITH SYSTEM_MODE
      ],
      'Reuse one placeholder product.'
    );
  }

  @IsTest
  static void preservesMissingNumbersInSnapshotFields() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Mat_Servicios_de_oportunidad__c service = [
      SELECT Id
      FROM Mat_Servicios_de_oportunidad__c
      WHERE Mat_Oportunidad__c = :opportunity.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    service.Mat_Tarifa__c = null;
    service.Mat_Descuento__c = null;
    update as system service;
    generate(opportunity.Id);
    QuoteLineItem line = [
      SELECT UnitPrice, Discount, Mat_Tarifa__c, Mat_Descuento__c
      FROM QuoteLineItem
      WHERE Mat_Servicio_de_oportunidad__c = :service.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.isNull(line.Mat_Tarifa__c, 'Preserve an unavailable tariff.');
    Assert.isNull(line.Mat_Descuento__c, 'Preserve an unavailable discount.');
    Assert.areEqual(
      0,
      line.UnitPrice,
      'Standard line pricing requires a numeric value.'
    );
    Assert.areEqual(
      0,
      line.Discount,
      'Standard line discount defaults to zero.'
    );
  }

  @IsTest
  static void doesNotReplaceExistingListPrices() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Product2 product = [
      SELECT Id
      FROM Product2
      WHERE Name = 'Activación & contenido'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    PricebookEntry existing = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = product.Id,
      UnitPrice = 777,
      IsActive = true
    );
    insert as system existing;
    generate(opportunity.Id);
    PricebookEntry saved = [
      SELECT UnitPrice
      FROM PricebookEntry
      WHERE Id = :existing.Id
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      777,
      saved.UnitPrice,
      'Do not overwrite established list prices.'
    );
    List<QuoteLineItem> lines = getLines(getQuote(opportunity.Id).Id);
    Assert.areEqual(
      100000,
      lines[0].UnitPrice,
      'The negotiated service pricing stays independent of the list price.'
    );
  }

  @IsTest
  static void usesTheOpportunityCustomPricebook() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Pricebook2 book = new Pricebook2(
      Name = 'Catálogo de prueba',
      IsActive = true
    );
    insert as system book;
    opportunity.Pricebook2Id = book.Id;
    update as system opportunity;
    generate(opportunity.Id);
    Quote quote = getQuote(opportunity.Id);
    Assert.areEqual(
      book.Id,
      quote.Pricebook2Id,
      'Use the opportunity price book.'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM PricebookEntry
        WHERE Pricebook2Id = :book.Id
        WITH SYSTEM_MODE
      ],
      'Register both products in the custom book.'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM PricebookEntry
        WHERE Pricebook2Id = :Test.getStandardPricebookId()
        WITH SYSTEM_MODE
      ],
      'Register required standard prices first.'
    );
  }

  private static void assertRejected(Id opportunityId, String expectedMessage) {
    MatQuoteService.renderer = new Renderer();
    Test.startTest();
    try {
      MatQuoteService.generateQuote(opportunityId);
      Assert.fail('Invalid data must be rejected.');
    } catch (AuraHandledException error) {
      Assert.areEqual(
        expectedMessage,
        error.getMessage(),
        'Show a user-safe instruction.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Quote WITH SYSTEM_MODE],
      'Do not leave a partial Quote.'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM ContentVersion WITH SYSTEM_MODE],
      'Do not leave a partial PDF.'
    );
  }

  @IsTest
  static void rejectsInactiveProducts() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Product2 product = [SELECT Id FROM Product2 WITH SYSTEM_MODE LIMIT 1];
    product.IsActive = false;
    update as system product;
    assertRejected(opportunity.Id, Label.Mat_Quote_InactiveProduct);
  }

  @IsTest
  static void rejectsDiscountsOutsideNativeLimits() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Mat_Servicios_de_oportunidad__c service = [
      SELECT Id
      FROM Mat_Servicios_de_oportunidad__c
      WHERE Mat_Oportunidad__c = :opportunity.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    service.Mat_Descuento__c = 150;
    update as system service;
    assertRejected(opportunity.Id, Label.Mat_Quote_InvalidLine);
  }

  @IsTest
  static void rejectsInactivePricebooks() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    update as system new Pricebook2(
      Id = Test.getStandardPricebookId(),
      IsActive = false
    );
    assertRejected(opportunity.Id, Label.Mat_Quote_InactivePricebook);
  }

  @IsTest
  static void createsMoreThanTwoHundredLines() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Id catalogueId = [
      SELECT Id
      FROM Mat_Servicio_de_talento__c
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .Id;
    List<Mat_Servicios_de_oportunidad__c> services = new List<Mat_Servicios_de_oportunidad__c>();
    for (Integer index = 0; index < 251; index++) {
      services.add(
        MatQuoteTestDataFactory.service(opportunity.Id, catalogueId, 1000, 10)
      );
    }
    insert as system services;
    generate(opportunity.Id);
    Assert.areEqual(
      254,
      getLines(getQuote(opportunity.Id).Id).size(),
      'Keep every source service across the bulk boundary.'
    );
  }
}
