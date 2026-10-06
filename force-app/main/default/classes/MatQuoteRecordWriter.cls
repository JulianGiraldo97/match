/** Persists the standard Quote and one historical QuoteLineItem per source service. */
public with sharing class MatQuoteRecordWriter {
  /**
   * Checks constraints imposed by standard quote lines before rendering the PDF.
   * @param services The selected opportunity's services.
   * @throws MatQuoteData.QuoteException For inactive products or invalid line pricing.
   */
  public static void validateLines(
    List<Mat_Servicios_de_oportunidad__c> services
  ) {
    for (Mat_Servicios_de_oportunidad__c service : services) {
      if (service.Mat_Servicio_de_talento__r?.Servicio__r?.IsActive == false) {
        throw new MatQuoteData.QuoteException(Label.Mat_Quote_InactiveProduct);
      }
      if (
        service.Mat_Tarifa__c < 0 ||
        service.Mat_Descuento__c < 0 ||
        service.Mat_Descuento__c > 100
      ) {
        throw new MatQuoteData.QuoteException(Label.Mat_Quote_InvalidLine);
      }
    }
  }

  /**
   * Saves the header and its complete detail from the values already loaded.
   * Caller owns the savepoint and must roll back every write on failure.
   * @param data The original opportunity data, without recalculating totals.
   * @param title The generation-specific document title.
   * @return ID of the new standard Quote.
   */
  public static Id save(MatQuoteData data, String title) {
    MatQuoteCatalog catalog = MatQuoteCatalog.prepare(data);
    Quote quote = new Quote(
      Name = title,
      OpportunityId = data.opportunity.Id,
      Pricebook2Id = catalog.pricebookId,
      Description = data.opportunity.Condiciones_comerciales__c,
      Mat_Moneda__c = data.opportunity.Mat_Moneda__c,
      Mat_Cliente__c = data.opportunity.Account?.Name,
      Mat_Nombre_oportunidad__c = data.opportunity.Name,
      Mat_Fecha_generacion__c = Datetime.now(),
      Mat_Tarifa__c = data.opportunity.Mat_Tarifa__c,
      Mat_Tarifa_negociada__c = data.opportunity.Mat_Tarifa_negociada__c,
      Mat_Descuento__c = data.opportunity.Mat_Descuento__c
    );
    insert as user quote;
    List<QuoteLineItem> lines = new List<QuoteLineItem>();
    Integer position = 0;
    for (Mat_Servicios_de_oportunidad__c service : data.services) {
      String name = service.Mat_Servicio_de_talento__r?.Servicio__r?.Name;
      lines.add(
        new QuoteLineItem(
          QuoteId = quote.Id,
          PricebookEntryId = catalog.entryIdByServiceId.get(service.Id),
          Quantity = 1,
          UnitPrice = service.Mat_Tarifa__c ?? 0,
          Discount = service.Mat_Descuento__c ?? 0,
          SortOrder = ++position,
          Mat_Nombre_servicio__c = String.isBlank(name)
            ? Label.Mat_Quote_MissingService
            : name,
          Mat_Servicio_de_oportunidad__c = service.Id,
          Mat_Tarifa__c = service.Mat_Tarifa__c,
          Mat_Tarifa_negociada__c = service.Mat_Tarifa_negociada__c,
          Mat_Descuento__c = service.Mat_Descuento__c
        )
      );
    }
    insert as user lines;
    return quote.Id;
  }
}
