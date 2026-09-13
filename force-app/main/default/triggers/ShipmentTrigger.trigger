trigger ShipmentTrigger on Shipment__c (
    before insert, before update,
    after insert, after update, after delete
) {
    new ShipmentTriggerHandler().run();
}