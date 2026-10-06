// Synthetic test data for matchdev. Requires create access to these objects and fields.
// Run only once per dataset; the guard prevents accidental duplicates.
String marker = '20261005';
String clientName = 'TEST - Cliente ficticio cotizaciones - ' + marker;
System.assertEquals(0, [SELECT count() FROM Account WHERE Name = :clientName WITH USER_MODE],
    'Este conjunto de datos de prueba ya existe.');

Account client = new Account(Name = clientName);
insert as user client;
Mat_Talentos__c talent = new Mat_Talentos__c(Name = 'TEST - Talento ficticio cotizaciones - ' + marker);
insert as user talent;
List<Product2> products = new List<Product2>{
    new Product2(Name = 'TEST - Reel para redes sociales', IsActive = true),
    new Product2(Name = 'TEST - Historias en Instagram', IsActive = true),
    new Product2(Name = 'TEST - Producción audiovisual integral con edición, música y acompañamiento creativo para campaña de lanzamiento', IsActive = true),
    new Product2(Name = 'TEST - Activación de marca en evento', IsActive = true)
};
insert as user products;
List<Mat_Servicio_de_talento__c> catalogue = new List<Mat_Servicio_de_talento__c>();
for (Integer index = 0; index < products.size(); index++) {
    catalogue.add(new Mat_Servicio_de_talento__c(Name = 'TEST - Catálogo cotizaciones ' + index + ' - ' + marker,
        Mat_Talento__c = talent.Id, Servicio__c = products[index].Id, Mat_Tarifa__c = 999999));
}
insert as user catalogue;
List<Opportunity> opportunities = new List<Opportunity>{
    new Opportunity(Name = 'TEST - Cotización básica (COP) - ' + marker,
        Condiciones_comerciales__c = 'DATOS FICTICIOS PARA PRUEBA.\nPago: 50% al inicio y 50% a la entrega.\nIncluye una ronda de ajustes.\nVigencia de la propuesta: 15 días.'),
    new Opportunity(Name = 'TEST - Cotización multipágina (COP) - ' + marker,
        Condiciones_comerciales__c = 'DATOS FICTICIOS PARA PRUEBA.\nPago a 30 días desde la entrega.\nIncluye producción, música y edición.\nLos servicios repetidos corresponden a entregas independientes.'),
    new Opportunity(Name = 'TEST - Cotización sin servicios - ' + marker)
};
for (Opportunity opportunity : opportunities) {
    opportunity.AccountId = client.Id;
    opportunity.StageName = 'Qualification';
    opportunity.CloseDate = Date.today().addDays(30);
    opportunity.Mat_Moneda__c = 'COP';
    opportunity.Mat_Talento__c = talent.Id;
}
insert as user opportunities;
List<Mat_Servicios_de_oportunidad__c> services = new List<Mat_Servicios_de_oportunidad__c>();
List<Decimal> rates = new List<Decimal>{1500000, 500000, 800000, 1200000, 2000000};
List<Decimal> discounts = new List<Decimal>{10, 0, 25, 15, 20};
List<Integer> productIndexes = new List<Integer>{0, 1, 0, 3, 2};
for (Integer index = 0; index < rates.size(); index++) {
    services.add(new Mat_Servicios_de_oportunidad__c(Name = 'TEST - Servicio básico ' + (index + 1) + ' - ' + marker,
        Mat_Oportunidad__c = opportunities[0].Id,
        Mat_Servicio_de_talento__c = catalogue[productIndexes[index]].Id,
        Mat_Tarifa__c = rates[index], Mat_Descuento__c = discounts[index]));
}
for (Integer index = 0; index < 65; index++) {
    services.add(new Mat_Servicios_de_oportunidad__c(Name = 'TEST - Servicio multipágina ' + (index + 1) + ' - ' + marker,
        Mat_Oportunidad__c = opportunities[1].Id,
        Mat_Servicio_de_talento__c = catalogue[Math.mod(index, 4)].Id,
        Mat_Tarifa__c = 100000 + index * 1000, Mat_Descuento__c = Math.mod(index, 4) * 10));
}
insert as user services;
List<Id> productIds = new List<Id>();
List<Id> catalogueIds = new List<Id>();
List<Id> serviceIds = new List<Id>();
for (Product2 record : products) { productIds.add(record.Id); }
for (Mat_Servicio_de_talento__c record : catalogue) { catalogueIds.add(record.Id); }
for (Mat_Servicios_de_oportunidad__c record : services) { serviceIds.add(record.Id); }
System.debug('QUOTE_TEST_DATA_IDS=' + JSON.serialize(new Map<String, Object>{
    'accountId' => client.Id, 'talentId' => talent.Id,
    'basicOpportunityId' => opportunities[0].Id,
    'multipageOpportunityId' => opportunities[1].Id,
    'emptyOpportunityId' => opportunities[2].Id,
    'productIds' => productIds, 'catalogueIds' => catalogueIds, 'serviceIds' => serviceIds
}));
