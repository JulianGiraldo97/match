/** Read-only Visualforce controller for the Match quote PDF. */
public with sharing class MatQuotePdfController {
  public Opportunity opportunity { get; private set; }
  public List<ServiceRow> rows { get; private set; }
  public String clientName { get; private set; }
  public String generatedOn { get; private set; }
  public String totalRate { get; private set; }
  public String negotiatedRate { get; private set; }
  public String discount { get; private set; }
  public Boolean hasConditions { get; private set; }
  public String baseCurrency { get; private set; }
  public Boolean hasForeignCurrency { get; private set; }
  public String foreignRate { get; private set; }
  public String foreignNegotiatedRate { get; private set; }

  /**
   * Loads the current opportunity and prepares Spanish display values.
   * @param controller Standard Opportunity controller providing the record ID.
   */
  public MatQuotePdfController(ApexPages.StandardController controller) {
    MatQuoteData data = MatQuoteData.load(controller.getId());
    opportunity = data.opportunity;
    clientName = opportunity.Account?.Name ?? Label.Mat_Quote_MissingValue;
    generatedOn = Datetime.now()
      .format('dd/MM/yyyy HH:mm', UserInfo.getTimeZone().getID());
    totalRate = formatAmount(opportunity.Mat_Tarifa__c);
    negotiatedRate = formatAmount(opportunity.Mat_Tarifa_negociada__c);
    discount = formatPercent(opportunity.Mat_Descuento__c);
    hasConditions = String.isNotBlank(opportunity.Condiciones_comerciales__c);
    baseCurrency = UserInfo.getDefaultCurrency();
    hasForeignCurrency =
      String.isNotBlank(opportunity.Mat_Moneda__c) &&
      opportunity.Mat_Moneda__c != baseCurrency;
    foreignRate = formatAmount(opportunity.Mat_Tarifa_moneda_extranjera__c);
    foreignNegotiatedRate = formatAmount(
      opportunity.Mat_Tarifa_negociada_moneda_extranjera__c
    );
    rows = new List<ServiceRow>();
    for (Mat_Servicios_de_oportunidad__c service : data.services) {
      rows.add(new ServiceRow(service));
    }
  }

  /** Formats existing currency amounts, whose metadata has zero decimal places. */
  @TestVisible
  private static String formatAmount(Decimal value) {
    return formatNumber(value, 0);
  }

  /** Salesforce returns Percent values in percentage points; do not multiply by 100. */
  @TestVisible
  private static String formatPercent(Decimal value) {
    return value == null
      ? Label.Mat_Quote_MissingValue
      : formatNumber(value, 2) + ' %';
  }

  private static String formatNumber(Decimal value, Integer scale) {
    if (value == null) {
      return Label.Mat_Quote_MissingValue;
    }
    List<String> parts = String.valueOf(
        value.setScale(scale, RoundingMode.HALF_UP)
      )
      .split('\\.');
    String result = parts[0].replaceAll('(\\d)(?=(\\d{3})+(?!\\d))', '$1.');
    return scale == 0 ? result : result + ',' + parts[1];
  }

  /** A single row; duplicate product names are intentionally preserved. */
  public with sharing class ServiceRow {
    public String name { get; private set; }
    public String rate { get; private set; }
    public String discount { get; private set; }
    public String negotiatedRate { get; private set; }

    /**
     * @param service Existing opportunity service and its product reference.
     */
    public ServiceRow(Mat_Servicios_de_oportunidad__c service) {
      String productName = service.Mat_Servicio_de_talento__r
        ?.Servicio__r
        ?.Name;
      name = String.isBlank(productName)
        ? Label.Mat_Quote_MissingService
        : productName;
      rate = formatAmount(service.Mat_Tarifa__c);
      discount = formatPercent(service.Mat_Descuento__c);
      negotiatedRate = formatAmount(service.Mat_Tarifa_negociada__c);
    }
  }
}
