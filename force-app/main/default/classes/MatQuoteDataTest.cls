/** Tests scope, ordering, access and complete service retrieval. */
@IsTest
private with sharing class MatQuoteDataTest {
  @TestSetup
  static void setupData() {
    MatQuoteTestDataFactory.createScenario();
  }

  @IsTest
  static void readsAllAndOnlyTheSelectedOpportunityServices() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Test.startTest();
    MatQuoteData data = MatQuoteData.load(opportunity.Id);
    Test.stopTest();
    Assert.areEqual(
      3,
      data.services.size(),
      'Keep duplicate services and exclude other opportunities.'
    );
    Assert.areEqual(
      'Activación & contenido',
      data.services[0].Mat_Servicio_de_talento__r.Servicio__r.Name,
      'Sort by the product name.'
    );
    Assert.areEqual(
      'Video promoción',
      data.services[2].Mat_Servicio_de_talento__r.Servicio__r.Name,
      'Product name must omit the talent.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa__c,
      data.opportunity.Mat_Tarifa__c,
      'Read the stored opportunity total.'
    );
    Assert.areEqual(
      opportunity.Mat_Tarifa_negociada__c,
      data.opportunity.Mat_Tarifa_negociada__c,
      'Read the stored negotiated total.'
    );
    Assert.areEqual(
      opportunity.Mat_Descuento__c,
      data.opportunity.Mat_Descuento__c,
      'Read the stored opportunity discount.'
    );
    Assert.areEqual(
      100000,
      data.services[0].Mat_Tarifa__c,
      'Use opportunity-specific pricing, not the catalogue rate.'
    );
    Assert.areEqual(
      90000,
      data.services[0].Mat_Tarifa_negociada__c,
      'Read the service formula result.'
    );
  }

  @IsTest
  static void retrievesMoreThanTwoHundredServices() {
    Opportunity opportunity = MatQuoteTestDataFactory.getPrimaryOpportunity();
    Id catalogueId = [
      SELECT Mat_Servicio_de_talento__c
      FROM Mat_Servicios_de_oportunidad__c
      WHERE Mat_Oportunidad__c = :opportunity.Id
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .Mat_Servicio_de_talento__c;
    List<Mat_Servicios_de_oportunidad__c> services = new List<Mat_Servicios_de_oportunidad__c>();
    for (Integer index = 0; index < 251; index++) {
      services.add(
        MatQuoteTestDataFactory.service(opportunity.Id, catalogueId, 1000, 0)
      );
    }
    insert as system services;
    Test.startTest();
    MatQuoteData data = MatQuoteData.load(opportunity.Id);
    Test.stopTest();
    Assert.areEqual(
      254,
      data.services.size(),
      'Do not truncate the quote at a related-list or query batch limit.'
    );
  }

  @IsTest
  static void rejectsNullOpportunity() {
    Test.startTest();
    try {
      MatQuoteData.load(null);
      Assert.fail('A record ID is required.');
    } catch (MatQuoteData.QuoteException error) {
      Assert.areEqual(
        Label.Mat_Quote_InvalidOpportunity,
        error.getMessage(),
        'Return a user-safe invalid record error.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsWrongObject() {
    Id accountId = [SELECT Id FROM Account WITH SYSTEM_MODE LIMIT 1].Id;
    Test.startTest();
    try {
      MatQuoteData.load(accountId);
      Assert.fail('An account ID is not an opportunity.');
    } catch (MatQuoteData.QuoteException error) {
      Assert.areEqual(
        Label.Mat_Quote_InvalidOpportunity,
        error.getMessage(),
        'Reject the wrong record type.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsEmptyOpportunity() {
    Id opportunityId = MatQuoteTestDataFactory.getEmptyOpportunity().Id;
    Test.startTest();
    try {
      MatQuoteData.load(opportunityId);
      Assert.fail('Empty quotes are not allowed.');
    } catch (MatQuoteData.QuoteException error) {
      Assert.areEqual(
        Label.Mat_Quote_NoServices,
        error.getMessage(),
        'Ask the user to add services.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void rejectsDeletedOpportunity() {
    Opportunity opportunity = MatQuoteTestDataFactory.getEmptyOpportunity();
    delete as system opportunity;
    Test.startTest();
    try {
      MatQuoteData.load(opportunity.Id);
      Assert.fail('Deleted opportunities must not be quoted.');
    } catch (MatQuoteData.QuoteException error) {
      Assert.areEqual(
        Label.Mat_Quote_InvalidOpportunity,
        error.getMessage(),
        'Avoid exposing internal lookup errors.'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void enforcesReadPermissions() {
    Id opportunityId = MatQuoteTestDataFactory.getPrimaryOpportunity().Id;
    Id profileId = [
      SELECT Id
      FROM Profile
      WHERE UserLicense.Name = 'Salesforce' AND PermissionsModifyAllData = FALSE
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 1
    ]
    .Id;
    User reader = new User(
      Username = 'quote.read.' +
        UserInfo.getOrganizationId() +
        '.' +
        Datetime.now().getTime() +
        '@example.invalid',
      Email = 'quote.read@example.invalid',
      Alias = 'qreader',
      LastName = 'Quote Reader',
      ProfileId = profileId,
      TimeZoneSidKey = 'America/Bogota',
      LocaleSidKey = 'es_CO',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'es'
    );
    insert as system reader;
    Test.startTest();
    System.runAs(reader) {
      try {
        MatQuoteData.load(opportunityId);
        Assert.fail(
          'Missing field or record access must prevent PDF generation.'
        );
      } catch (MatQuoteData.QuoteException error) {
        Assert.isTrue(
          new Set<String>{
              Label.Mat_Quote_PermissionError,
              Label.Mat_Quote_InvalidOpportunity
            }
            .contains(error.getMessage()),
          'Only return a user-safe access error.'
        );
      }
    }
    Test.stopTest();
  }
}
