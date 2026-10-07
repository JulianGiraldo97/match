/** Synthetic, isolated records shared by the quote tests. */
@IsTest
public with sharing class MatQuoteTestDataFactory {
  /** Creates two opportunities, one empty, with different product names and discounts. */
  public static void createScenario() {
    Id permissionId = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Mat_Generar_Cotizacion'
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .Id;
    Id userId = UserInfo.getUserId();
    if (
      [
        SELECT COUNT()
        FROM PermissionSetAssignment
        WHERE AssigneeId = :userId AND PermissionSetId = :permissionId
        WITH SYSTEM_MODE
      ] == 0
    ) {
      insert as system new PermissionSetAssignment(
        AssigneeId = userId,
        PermissionSetId = permissionId
      );
    }
    System.runAs(new User(Id = userId)) {
      Account client = new Account(Name = 'Cliente de prueba cotización');
      Account otherClient = new Account(
        Name = 'Otro cliente de prueba cotización'
      );
      Account emptyClient = new Account(
        Name = 'Cliente sin servicios de prueba cotización'
      );
      insert as system new List<Account>{ client, otherClient, emptyClient };
      Mat_Talentos__c talent = new Mat_Talentos__c(Name = 'Talento de prueba');
      insert as system talent;
      update as system new Pricebook2(
        Id = Test.getStandardPricebookId(),
        IsActive = true
      );
      List<Opportunity> opportunities = new List<Opportunity>{
        opportunity('Cotización principal', client.Id, talent.Id),
        opportunity('Otra oportunidad', otherClient.Id, talent.Id),
        opportunity('Sin servicios', emptyClient.Id, talent.Id)
      };
      insert as system opportunities;
      List<Product2> products = new List<Product2>{
        new Product2(Name = 'Activación & contenido', IsActive = true),
        new Product2(Name = 'Video promoción', IsActive = true)
      };
      insert as system products;
      List<Mat_Servicio_de_talento__c> catalogue = new List<Mat_Servicio_de_talento__c>{
        new Mat_Servicio_de_talento__c(
          Name = 'Talento - Activación',
          Mat_Talento__c = talent.Id,
          Servicio__c = products[0].Id,
          Mat_Tarifa__c = 99999
        ),
        new Mat_Servicio_de_talento__c(
          Name = 'Talento - Video',
          Mat_Talento__c = talent.Id,
          Servicio__c = products[1].Id,
          Mat_Tarifa__c = 88888
        )
      };
      insert as system catalogue;
      insert as system new List<Mat_Servicios_de_oportunidad__c>{
        service(opportunities[0].Id, catalogue[1].Id, 200000, 25),
        service(opportunities[0].Id, catalogue[0].Id, 100000, 10),
        service(opportunities[0].Id, catalogue[0].Id, 50000, 0),
        service(opportunities[1].Id, catalogue[0].Id, 999000, 50)
      };
    }
  }

  /** @return The primary quoted opportunity, including stored rollup and formula fields. */
  public static Opportunity getPrimaryOpportunity() {
    MatQuoteCatalog.standardPricebookId = Test.getStandardPricebookId();
    return [
      SELECT
        Id,
        Name,
        Mat_Talento__c,
        AccountId,
        Mat_Moneda__c,
        Mat_Tarifa__c,
        Mat_Tarifa_negociada__c,
        Mat_Descuento__c,
        Mat_Tarifa_moneda_extranjera__c,
        Mat_Tarifa_negociada_moneda_extranjera__c,
        Condiciones_comerciales__c
      FROM Opportunity
      // Opportunity naming automation can replace Name; the fixture account is stable.
      WHERE Account.Name = 'Cliente de prueba cotización'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  /** @return An opportunity with no related services. */
  public static Opportunity getEmptyOpportunity() {
    return [
      SELECT Id
      FROM Opportunity
      WHERE Account.Name = 'Cliente sin servicios de prueba cotización'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  /** @param name Opportunity name. @param clientId Client. @param talentId Selected talent. @return An unsaved opportunity. */
  public static Opportunity opportunity(String name, Id clientId, Id talentId) {
    return new Opportunity(
      Name = name,
      AccountId = clientId,
      Mat_Talento__c = talentId,
      StageName = 'Qualification',
      CloseDate = Date.today().addDays(30),
      Mat_Moneda__c = 'COP',
      Condiciones_comerciales__c = 'Pago a 30 días.\nIncluye producción y edición.'
    );
  }

  /** @param opportunityId Parent. @param catalogueId Catalogue reference. @param rate Opportunity-specific price. @param discount Percentage points. @return Unsaved service. */
  public static Mat_Servicios_de_oportunidad__c service(
    Id opportunityId,
    Id catalogueId,
    Decimal rate,
    Decimal discount
  ) {
    return new Mat_Servicios_de_oportunidad__c(
      Name = 'Registro interno del talento',
      Mat_Oportunidad__c = opportunityId,
      Mat_Servicio_de_talento__c = catalogueId,
      Mat_Tarifa__c = rate,
      Mat_Descuento__c = discount
    );
  }
}
