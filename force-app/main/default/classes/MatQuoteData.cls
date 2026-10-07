/** Reads the existing opportunity totals and its complete list of quoted services. */
public with sharing class MatQuoteData {
  public Opportunity opportunity { get; private set; }
  public List<Mat_Servicios_de_oportunidad__c> services { get; private set; }

  /**
   * Loads the quote in user mode without recalculating financial fields.
   * @param opportunityId Opportunity to quote.
   * @return Data visible to the current user.
   * @throws QuoteException If the opportunity is invalid, inaccessible or empty.
   */
  public static MatQuoteData load(Id opportunityId) {
    if (
      opportunityId == null ||
      opportunityId.getSObjectType() != Opportunity.SObjectType
    ) {
      throw new QuoteException(Label.Mat_Quote_InvalidOpportunity);
    }
    MatQuoteData data = new MatQuoteData();
    try {
      List<Opportunity> opportunities = [
        SELECT
          Id,
          Name,
          Pricebook2Id,
          Account.Name,
          Mat_Talento__r.Name,
          Mat_Moneda__c,
          Condiciones_comerciales__c,
          Mat_Tarifa__c,
          Mat_Tarifa_negociada__c,
          Mat_Descuento__c,
          Mat_Tarifa_moneda_extranjera__c,
          Mat_Tarifa_negociada_moneda_extranjera__c
        FROM Opportunity
        WHERE Id = :opportunityId
        WITH USER_MODE
        LIMIT 1
      ];
      if (opportunities.isEmpty()) {
        throw new QuoteException(Label.Mat_Quote_InvalidOpportunity);
      }
      data.opportunity = opportunities[0];
      // A separate query avoids the relationship-query limit for 200+ services.
      data.services = [
        SELECT
          Id,
          Mat_Servicio_de_talento__r.Servicio__c,
          Mat_Servicio_de_talento__r.Servicio__r.Name,
          Mat_Servicio_de_talento__r.Servicio__r.IsActive,
          Mat_Tarifa__c,
          Mat_Tarifa_negociada__c,
          Mat_Descuento__c
        FROM Mat_Servicios_de_oportunidad__c
        WHERE Mat_Oportunidad__c = :opportunityId
        WITH USER_MODE
        ORDER BY
          Mat_Servicio_de_talento__r.Servicio__r.Name ASC NULLS LAST,
          CreatedDate ASC,
          Id ASC
      ];
    } catch (QueryException error) {
      throw new QuoteException(Label.Mat_Quote_PermissionError, error);
    }
    if (data.services.isEmpty()) {
      throw new QuoteException(Label.Mat_Quote_NoServices);
    }
    return data;
  }

  /** User-safe validation and access error. */
  public class QuoteException extends Exception {
  }
}
