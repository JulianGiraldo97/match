/** Tests PDF display values independently of the rendering boundary. */
@IsTest
private with sharing class MatQuotePdfControllerTest {
  @TestSetup
  static void setupData() {
    MatQuoteTestDataFactory.createScenario();
  }

  @IsTest
  static void formatsTheStoredValuesAndClient() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Test.startTest();
    MatQuotePdfController controller = new MatQuotePdfController(
      new ApexPages.StandardController(opportunity)
    );
    Test.stopTest();
    Assert.areEqual(
      'Cliente de prueba cotización',
      controller.clientName,
      'Use Account.Name.'
    );
    Assert.areEqual(
      '350.000',
      controller.totalRate,
      'Use the opportunity total with Spanish separators.'
    );
    Assert.areEqual(
      '290.000',
      controller.negotiatedRate,
      'Use the negotiated rollup.'
    );
    Assert.areEqual(
      MatQuotePdfController.formatPercent(opportunity.Mat_Descuento__c),
      controller.discount,
      'Preserve the opportunity discount value.'
    );
    Assert.areEqual(
      'Activación & contenido',
      controller.rows[0].name,
      'Display only the product name.'
    );
    Assert.areEqual(
      '10,00 %',
      controller.rows[0].discount,
      'Show the row percentage in percentage points.'
    );
    Assert.areEqual(
      '25,00 %',
      controller.rows[2].discount,
      'Preserve different row discounts.'
    );
    Assert.areEqual(
      true,
      controller.hasConditions,
      'Show existing commercial conditions.'
    );
    Assert.areEqual(
      'COP',
      controller.opportunity.Mat_Moneda__c,
      'Use the selected currency without conversion.'
    );
    Assert.isNotNull(controller.generatedOn, 'Include a generation date.');
  }

  @IsTest
  static void distinguishesBaseAndQuotedCurrency() {
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
    Test.startTest();
    MatQuotePdfController controller = new MatQuotePdfController(
      new ApexPages.StandardController(opportunity)
    );
    Test.stopTest();
    Assert.areEqual('COP', controller.baseCurrency, 'Base tariffs are in COP.');
    Assert.isTrue(
      controller.hasForeignCurrency,
      'Show the quoted foreign currency.'
    );
    Assert.areEqual(
      '88',
      controller.foreignRate,
      'Use the source field precision.'
    );
    Assert.areEqual(
      '73',
      controller.foreignNegotiatedRate,
      'Use the negotiated foreign formula.'
    );
    Assert.areEqual(
      '350.000',
      controller.totalRate,
      'Keep the base tariff unchanged.'
    );
  }

  @IsTest
  static void omitsForeignSectionForBaseCurrency() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Test.startTest();
    MatQuotePdfController controller = new MatQuotePdfController(
      new ApexPages.StandardController(opportunity)
    );
    Test.stopTest();
    Assert.isFalse(
      controller.hasForeignCurrency,
      'Avoid duplicate COP totals.'
    );
  }

  @IsTest
  static void showsUnavailableForeignValuesAsDash() {
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
    Test.startTest();
    MatQuotePdfController controller = new MatQuotePdfController(
      new ApexPages.StandardController(opportunity)
    );
    Test.stopTest();
    Assert.isTrue(
      controller.hasForeignCurrency,
      'Keep the selected currency visible.'
    );
    Assert.areEqual(
      '—',
      controller.foreignRate,
      'Do not replace unavailable conversion with zero.'
    );
    Assert.areEqual(
      '—',
      controller.foreignNegotiatedRate,
      'Handle unavailable negotiated conversion.'
    );
  }

  @IsTest
  static void preservesRowsWithMissingReferencesAndAmounts() {
    Test.startTest();
    MatQuotePdfController.ServiceRow row = new MatQuotePdfController.ServiceRow(
      new Mat_Servicios_de_oportunidad__c()
    );
    Test.stopTest();
    Assert.areEqual(
      Label.Mat_Quote_MissingService,
      row.name,
      'Do not substitute the internal talent name.'
    );
    Assert.areEqual('—', row.rate, 'Missing numeric data is not zero.');
    Assert.areEqual(
      '—',
      row.negotiatedRate,
      'Missing negotiated data is not zero.'
    );
    Assert.areEqual(
      '—',
      row.discount,
      'Do not add a percent symbol to missing data.'
    );
  }

  @IsTest
  static void formatsZeroAndNegativeValues() {
    Test.startTest();
    String zeroRate = MatQuotePdfController.formatAmount(0);
    String negativeRate = MatQuotePdfController.formatAmount(-1234567);
    String percentage = MatQuotePdfController.formatPercent(12.5);
    Test.stopTest();
    Assert.areEqual('0', zeroRate, 'Zero is a valid amount.');
    Assert.areEqual('-1.234.567', negativeRate, 'Preserve the sign.');
    Assert.areEqual(
      '12,50 %',
      percentage,
      'Do not rescale a Salesforce Percent field.'
    );
  }

  @IsTest
  static void hidesBlankConditions() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    opportunity.Condiciones_comerciales__c = null;
    update as system opportunity;
    Test.startTest();
    MatQuotePdfController controller = new MatQuotePdfController(
      new ApexPages.StandardController(opportunity)
    );
    Test.stopTest();
    Assert.areEqual(
      false,
      controller.hasConditions,
      'Omit an empty commercial conditions section.'
    );
  }
}
