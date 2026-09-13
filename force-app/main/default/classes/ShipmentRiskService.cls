public with sharing class ShipmentRiskService {

    private static final String STATUS_DELIVERY_EXCEPTION = 'Delivery Exception';

    public static void stampExceptionTimestamp(Shipment__c newShip, Shipment__c oldShip) {

        Boolean changed = (oldShip == null) || (oldShip.Status__c != newShip.Status__c);

        if (changed == false){
            return;
    }

        if (newShip.Status__c == STATUS_DELIVERY_EXCEPTION) {
        newShip.Exception_Since__c = Datetime.now();
        }
    }


    public static Set<Id> collectAccountIds(List<Shipment__c> newRecords, Map<Id, Shipment__c> oldMap){
        Set<Id> ids = new Set<Id>();

        for (Shipment__c s : newRecords){
            if (s.Customer__c != null){
              ids.add(s.Customer__c);
        }
            if (oldMap != null){
                Shipment__c old = oldMap.get(s.Id);
                if (old != null && old.Customer__c != null){
                ids.add(old.Customer__c);
                }
            }
        }

        return ids;
    }


    public static void recalculateForAccounts(Set<Id> accountIds){

        if (accountIds == null || accountIds.size() == 0){
            return;
        }

        // this is SOQL in loop, i know its bad, tryed to fix!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1 but
        
    // dont understand how to do GROUP BY properly for this case,
    // like how do i get count PER account if i put all ids in one query?
        
        // tryed something like this:
        //   SELECT Customer__c, COUNT(Id) FROM Shipment__c WHERE Customer__c IN :accountIds GROUP BY Customer__c
        
        // but then dont know how to read result back into normal Integer per account,

        // AggregateResult confuses me, get() method looks weird and i wasnt shure
        
        // what string to put inside get() to grab the value.
        // will ask on next standup, for now leaving as one-by-one loop so at least it work
        // on small amount of records (like it did in my testing with 2-3 accounts manually in UI)

        List<Account> accsToUpdate = new List<Account>();

        for (Id accId : accountIds) {

            Integer cnt = [SELECT COUNT() FROM Shipment__c WHERE Customer__c = :accId AND Status__c = 'Delivery Exception'];

            Account acc = [SELECT Id, OwnerId, Name, Delivery_Risk_Status__c FROM Account WHERE Id = :accId];

            String oldStatus = acc.Delivery_Risk_Status__c;

            acc.Open_Delivery_Exceptions__c = cnt;

            if (cnt >= 3) {
                acc.Delivery_Risk_Status__c = 'At Risk';
            } else {
                acc.Delivery_Risk_Status__c = 'Normal';
            }

            accsToUpdate.add(acc);

            // same problem here basicly, insert inside loop

            // i think i need to make a List<Case> outside the loop and add() into it

            // then insert once after loop ends, but i didnt refactor yet,
            // ran out of time before had to move to something else
            if (cnt >= 3) {
                Case c = new Case();
                c.Subject = 'Delivery risk: ' + acc.Name;
                c.AccountId = acc.Id;
                c.OwnerId = acc.OwnerId;
                c.Priority = 'High';
                c.Status = 'New';
                c.Description = 'Open delivery exceptions count: ' + cnt;
                insert c;
            }
        }

        update accsToUpdate;

        //  this whole method probably fails on 200 records bulk test
        
        //  with "Too many SOQL queries: 101" or similar, need to fix before final submit
        // but not sure yet best way, need to look up examples of aggregate queries
    }
}