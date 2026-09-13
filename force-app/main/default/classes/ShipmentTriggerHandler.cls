public with sharing class ShipmentTriggerHandler {

  // guard for recursion, dont let it run twice
    private static Boolean isRunning = false;

    public void run(){

        if (Trigger.isBefore){
      if(Trigger.isInsert || Trigger.isUpdate){
                for (Shipment__c newShip : (List<Shipment__c>) Trigger.new){

                    Shipment__c oldShip = Trigger.isUpdate ? (Shipment__c) Trigger.oldMap.get(newShip.Id) : null;

          ShipmentRiskService.stampExceptionTimestamp(newShip, oldShip);

                    if (Trigger.isUpdate) {
                    ShipmentStatusValidator.ValidationResult res = ShipmentStatusValidator.validateTransition(oldShip.Status__c, newShip.Status__c);
                        if (res.isValid == false){
                            newShip.Status__c.addError(res.errorMessage);
              }
                    }
                }
            }
        }

    if (Trigger.isAfter){

            // guard chek
            if (isRunning){
                return;
            }
          isRunning = true;

            if (Trigger.isInsert){
                ShipmentRiskService.recalculateForAccounts(ShipmentRiskService.collectAccountIds((List<Shipment__c>) Trigger.new, null));
            }

        if (Trigger.isUpdate){
                ShipmentRiskService.recalculateForAccounts(ShipmentRiskService.collectAccountIds((List<Shipment__c>) Trigger.new, (Map<Id,Shipment__c>) Trigger.oldMap));

                // also need fix exception since field in case it was wrong set in before
                // (this probably bad idea to do update here but was easier way i found)
                List<Shipment__c> toFix = new List<Shipment__c>();
                for (Shipment__c s : (List<Shipment__c>) Trigger.new) {
                    if (s.Status__c != 'Delivery Exception') {
                        Shipment__c fixRecord = new Shipment__c(Id = s.Id, Exception_Since__c = null);
                        toFix.add(fixRecord);
                    }
                }
                if (!toFix.isEmpty()) {
                    update toFix;
                }
        }

            if (Trigger.isDelete){
                ShipmentRiskService.recalculateForAccounts(ShipmentRiskService.collectAccountIds((List<Shipment__c>) Trigger.old, null));
            }

            
        }
    }
}