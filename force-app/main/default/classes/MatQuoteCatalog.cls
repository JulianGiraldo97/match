/** Registers missing products in the selected price book without replacing existing list prices. */
public with sharing class MatQuoteCatalog {
  private static final String UNNAMED_PRODUCT_CODE = 'MATCH_QUOTE_UNNAMED_SERVICE';
  @TestVisible
  private static Id standardPricebookId;
  public Id pricebookId { get; private set; }
  public Map<Id, Id> entryIdByServiceId { get; private set; }

  /**
   * Supplies a price book entry for each service. All DML must occur after PDF rendering.
   * @param data The selected opportunity and its ordered services.
   * @return The chosen price book and line-entry mappings.
   * @throws MatQuoteData.QuoteException When a required price book or entry is inactive.
   */
  public static MatQuoteCatalog prepare(MatQuoteData data) {
    Id standardId = getStandardPricebookId();
    MatQuoteCatalog catalog = new MatQuoteCatalog();
    catalog.pricebookId = data.opportunity.Pricebook2Id ?? standardId;
    List<Pricebook2> books = [
      SELECT Id, IsActive
      FROM Pricebook2
      WHERE Id = :catalog.pricebookId
      WITH USER_MODE
    ];
    if (books.isEmpty() || !books[0].IsActive) {
      throw new MatQuoteData.QuoteException(Label.Mat_Quote_InactivePricebook);
    }
    Map<Id, Id> productIdByServiceId = productsForServices(data.services);
    Map<Id, Decimal> ratesByProductId = new Map<Id, Decimal>();
    for (Mat_Servicios_de_oportunidad__c service : data.services) {
      Id productId = productIdByServiceId.get(service.Id);
      if (!ratesByProductId.containsKey(productId)) {
        ratesByProductId.put(productId, service.Mat_Tarifa__c ?? 0);
      }
    }
    Map<Id, PricebookEntry> targetEntries = ensureEntries(
      catalog.pricebookId,
      standardId,
      ratesByProductId
    );
    catalog.entryIdByServiceId = new Map<Id, Id>();
    for (Id serviceId : productIdByServiceId.keySet()) {
      catalog.entryIdByServiceId.put(
        serviceId,
        targetEntries.get(productIdByServiceId.get(serviceId)).Id
      );
    }
    return catalog;
  }

  private static Id getStandardPricebookId() {
    if (standardPricebookId == null) {
      List<Pricebook2> books = [
        SELECT Id
        FROM Pricebook2
        WHERE IsStandard = TRUE
        WITH USER_MODE
        LIMIT 1
      ];
      if (books.isEmpty()) {
        throw new MatQuoteData.QuoteException(
          Label.Mat_Quote_InactivePricebook
        );
      }
      standardPricebookId = books[0].Id;
    }
    return standardPricebookId;
  }

  private static Map<Id, Id> productsForServices(
    List<Mat_Servicios_de_oportunidad__c> services
  ) {
    Map<Id, Id> productIdByServiceId = new Map<Id, Id>();
    Boolean needsPlaceholder = false;
    for (Mat_Servicios_de_oportunidad__c service : services) {
      Id productId = service.Mat_Servicio_de_talento__r?.Servicio__c;
      productIdByServiceId.put(service.Id, productId);
      needsPlaceholder = needsPlaceholder || productId == null;
    }
    if (needsPlaceholder) {
      List<Product2> products = [
        SELECT Id, IsActive
        FROM Product2
        WHERE ProductCode = :UNNAMED_PRODUCT_CODE
        WITH USER_MODE
        LIMIT 1
      ];
      if (products.isEmpty()) {
        Product2 placeholder = new Product2(
          Name = Label.Mat_Quote_MissingService,
          ProductCode = UNNAMED_PRODUCT_CODE,
          IsActive = true
        );
        insert as user placeholder;
        products.add(placeholder);
      } else if (!products[0].IsActive) {
        throw new MatQuoteData.QuoteException(Label.Mat_Quote_InactiveProduct);
      }
      for (Id serviceId : productIdByServiceId.keySet()) {
        if (productIdByServiceId.get(serviceId) == null) {
          productIdByServiceId.put(serviceId, products[0].Id);
        }
      }
    }
    return productIdByServiceId;
  }

  private static Map<Id, PricebookEntry> ensureEntries(
    Id targetId,
    Id standardId,
    Map<Id, Decimal> rates
  ) {
    Set<Id> bookIds = new Set<Id>{ targetId, standardId };
    Map<Id, PricebookEntry> standardEntries = new Map<Id, PricebookEntry>();
    Map<Id, PricebookEntry> targetEntries = new Map<Id, PricebookEntry>();
    for (PricebookEntry entry : [
      SELECT Id, Pricebook2Id, Product2Id, IsActive
      FROM PricebookEntry
      WHERE Pricebook2Id IN :bookIds AND Product2Id IN :rates.keySet()
      WITH USER_MODE
    ]) {
      if (entry.Pricebook2Id == standardId) {
        standardEntries.put(entry.Product2Id, entry);
      }
      if (entry.Pricebook2Id == targetId) {
        targetEntries.put(entry.Product2Id, entry);
      }
    }
    List<PricebookEntry> newStandard = new List<PricebookEntry>();
    for (Id productId : rates.keySet()) {
      if (!standardEntries.containsKey(productId)) {
        newStandard.add(
          new PricebookEntry(
            Pricebook2Id = standardId,
            Product2Id = productId,
            UnitPrice = rates.get(productId),
            IsActive = true
          )
        );
      }
    }
    insert as user newStandard;
    for (PricebookEntry entry : newStandard) {
      standardEntries.put(entry.Product2Id, entry);
      if (targetId == standardId) {
        targetEntries.put(entry.Product2Id, entry);
      }
    }
    List<PricebookEntry> newTarget = new List<PricebookEntry>();
    for (Id productId : rates.keySet()) {
      if (!targetEntries.containsKey(productId)) {
        newTarget.add(
          new PricebookEntry(
            Pricebook2Id = targetId,
            Product2Id = productId,
            UnitPrice = rates.get(productId),
            IsActive = true
          )
        );
      } else if (!targetEntries.get(productId).IsActive) {
        throw new MatQuoteData.QuoteException(
          Label.Mat_Quote_InactivePricebook
        );
      }
    }
    insert as user newTarget;
    for (PricebookEntry entry : newTarget) {
      targetEntries.put(entry.Product2Id, entry);
    }
    return targetEntries;
  }
}
