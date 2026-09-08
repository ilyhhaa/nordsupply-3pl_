public with sharing class ShipmentSelector {

    public Map<String, Shipment__c> selectByExternalIds(Set<String> externalIds) {
        Map<String, Shipment__c> result = new Map<String, Shipment__c>();
        for (Shipment__c s : [
           
        SELECT Id, External_Shipment_Id__c, Status__c, Carrier__c,
                   Tracking_Number__c, Estimated_Delivery_Date__c,
                   Last_Status_Update__c, Last_Comment__c, Customer__c
            FROM Shipment__c
            WHERE External_Shipment_Id__c IN :externalIds
        ]) {
            result.put(s.External_Shipment_Id__c, s);
        }
        return result;
    }
}