// Manual cleanup of this exact synthetic dataset. This file has NOT been executed.
Set<Id> opportunityIds = new Set<Id>{'006WI00000RbuLRYAZ','006WI00000RbuLSYAZ','006WI00000RbuLTYAZ'};
List<Opportunity> opportunities = [SELECT Id, Name FROM Opportunity WHERE Id IN :opportunityIds WITH USER_MODE];
for (Opportunity record : opportunities) { System.assert(record.Name.startsWith('TEST - Cotización')); }
List<Quote> quotes = [SELECT Id FROM Quote WHERE OpportunityId IN :opportunityIds WITH USER_MODE];
Set<Id> linkedRecordIds = new Set<Id>(opportunityIds);
for (Quote record : quotes) { linkedRecordIds.add(record.Id); }
Set<Id> fileIds = new Set<Id>();
for (ContentDocumentLink link : [SELECT ContentDocumentId, ContentDocument.Title FROM ContentDocumentLink WHERE LinkedEntityId IN :linkedRecordIds WITH USER_MODE]) {
 if (link.ContentDocument.Title.startsWith('Cotizacion_TEST - Cotización')) { fileIds.add(link.ContentDocumentId); }
}
delete as user [SELECT Id FROM ContentDocument WHERE Id IN :fileIds WITH USER_MODE];
delete as user quotes;
delete as user opportunities;
List<Mat_Talentos__c> talentId = [SELECT Id, Name FROM Mat_Talentos__c WHERE Id IN ('a01WI00001b815yYAA') WITH USER_MODE];
for (Mat_Talentos__c record : talentId) { System.assert(record.Name.startsWith('TEST - ')); }
delete as user talentId;
List<Product2> productIds = [SELECT Id, Name FROM Product2 WHERE Id IN ('01tWI00000MEjgXYAT','01tWI00000MEjgYYAT','01tWI00000MEjgZYAT','01tWI00000MEjgaYAD') WITH USER_MODE];
for (Product2 record : productIds) { System.assert(record.Name.startsWith('TEST - ')); }
delete as user productIds;
List<Account> accountId = [SELECT Id, Name FROM Account WHERE Id IN ('001WI00001b815xYAA') WITH USER_MODE];
for (Account record : accountId) { System.assert(record.Name.startsWith('TEST - ')); }
delete as user accountId;
System.debug('QUOTE_TEST_DATA_CLEANUP=PASS');
