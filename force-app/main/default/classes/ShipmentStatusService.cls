public with sharing class ShipmentStatusService {

    private static final Map<String, String> STATUS_MAP = new Map<String, String>{

        'NEW' => 'New',
         'PICKED' => 'Picked',
          'PACKED' => 'Packed',
        'IN_TRANSIT' => 'In Transit',
         'DELIVERED' => 'Delivered', 

        'DELIVERY_EXCEPTION' => 'Delivery Exception'
    };

    private ShipmentSelector selector = new ShipmentSelector();

    public ShipmentStatusResponse processUpdates(ShipmentStatusRequest input) {

        ShipmentStatusResponse output = new ShipmentStatusResponse();
        
        output.correlationId = input.correlationId;
        
        output.receivedAt = Datetime.now();

        
        
        Set<String> extIds = new Set<String>();
        
        for (ShipmentStatusRequest.UpdateItem item : input.updates) {
            if (String.isNotBlank(item.externalShipmentId)) extIds.add(item.externalShipmentId);
        
        }
        
        Map<String, Shipment__c> existingByExtId = selector.selectByExternalIds(extIds);

        
        List<Shipment__c> toUpdate = new List<Shipment__c>();
        
        
        List<Shipment_Status_Changed__e> eventsToPublish = new List<Shipment_Status_Changed__e>();

        List<Map<String, String>> updateMeta = new List<Map<String, String>>();
        
        
        Map<String, ShipmentStatusResponse.ResultItem> resultByExtId = new Map<String, ShipmentStatusResponse.ResultItem>();
        
        List<String> orderedExtIds = new List<String>();

        for (ShipmentStatusRequest.UpdateItem item : input.updates) {


            orderedExtIds.add(item.externalShipmentId);

            if (String.isBlank(item.externalShipmentId) || String.isBlank(item.status) || String.isBlank(item.statusChangedAt)) 
            {
                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(

                    
                item.externalShipmentId, null, 'FAILED', 'MISSING_REQUIRED_FIELD', 'Required field is missing'));
                
                continue;
            }

            Shipment__c existing = existingByExtId.get(item.externalShipmentId);

            if (existing == null) {

                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(

                    item.externalShipmentId, null, 'FAILED', 'SHIPMENT_NOT_FOUND',

                    'No shipment found with External Shipment Id ' + item.externalShipmentId));

                continue;
            }


            String mappedStatus = STATUS_MAP.get(item.status);
            if (mappedStatus == null) {

                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(

                    item.externalShipmentId, existing.Id, 'FAILED', 'UNKNOWN_STATUS',
                    'Unknown status: ' + item.status));


                continue;
            }


            Datetime changedAt;
            try {

                changedAt = (Datetime) JSON.deserialize('"' + item.statusChangedAt + '"', Datetime.class);
            } 
            catch (Exception e) {
                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(
                    item.externalShipmentId, existing.Id, 'FAILED', 'INVALID_DATE_FORMAT',
                    'Cannot parse statusChangedAt: ' + item.statusChangedAt));
                continue;
            }

            if (existing.Last_Status_Update__c != null && changedAt <= existing.Last_Status_Update__c) 
            {
                
                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(
                
                item.externalShipmentId, existing.Id, 'SKIPPED_OUTDATED', null, null));
                
                continue;
            }

            if (existing.Status__c == mappedStatus) {
                
                
                resultByExtId.put(item.externalShipmentId, new ShipmentStatusResponse.ResultItem(
                
                item.externalShipmentId, existing.Id, 'SKIPPED_NO_CHANGE', null, null));
                
                continue;
            }


            String previousStatus = existing.Status__c;

             Shipment__c toUpd = new Shipment__c(Id = existing.Id);
            
             toUpd.Status__c = mappedStatus;
             toUpd.Last_Status_Update__c = changedAt;
   


            if (String.isNotBlank(item.carrier)) toUpd.Carrier__c = item.carrier;

            
            if (String.isNotBlank(item.trackingNumber)) toUpd.Tracking_Number__c = item.trackingNumber;
            
            if (String.isNotBlank(item.estimatedDeliveryDate)) {
                toUpd.Estimated_Delivery_Date__c = Date.valueOf(item.estimatedDeliveryDate);
            }
            
            if (String.isNotBlank(item.comment)) toUpd.Last_Comment__c = item.comment;

            toUpdate.add(toUpd);
            Map<String, String> meta = new Map<String, String>{

                'extId' => item.externalShipmentId,

                'previousStatus' => previousStatus,
                'newStatus' => mappedStatus,

                'customerId' => existing.Customer__c,

                'trackingNumber' => item.trackingNumber
            };
            
            updateMeta.add(meta);
        }
        if (!toUpdate.isEmpty()) { 
            Database.SaveResult[] srs = Database.update(toUpdate, false); 

            for (Integer i = 0; i < srs.size(); i++) {

                Map<String, String> meta = updateMeta[i];

                String extId = meta.get('extId');

                if (srs[i].isSuccess()) {

                    resultByExtId.put(extId, new ShipmentStatusResponse.ResultItem(
                        extId, toUpdate[i].Id, 'UPDATED', null, null));


                        //это событие только для фактически изщмен
                    Shipment_Status_Changed__e evt = new Shipment_Status_Changed__e();
                    evt.Shipment_Id__c = toUpdate[i].Id;

                    evt.External_Shipment_Id__c = extId;

                    evt.Customer_Id__c = meta.get('customerId');

                    evt.Previous_Status__c = meta.get('previousStatus');

                    evt.New_Status__c = meta.get('newStatus');

                    evt.Status_Changed_At__c = Datetime.now();

                    evt.Tracking_Number__c = meta.get('trackingNumber');


                    evt.Correlation_Id__c = input.correlationId;

                    eventsToPublish.add(evt);
                } else {
                    String errMsg = srs[i].getErrors().isEmpty() ? 'Update failed' : srs[i].getErrors()[0].getMessage();

                    resultByExtId.put(extId, new ShipmentStatusResponse.ResultItem(

                        extId, toUpdate[i].Id, 'FAILED', 'UPDATE_FAILED', errMsg));

                }
            }
        }


        if (!eventsToPublish.isEmpty()) {


            List<Database.SaveResult> pubResults = EventBus.publish(eventsToPublish);
            for (Database.SaveResult sr : pubResults) {

                if (!sr.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'Event publish failed: ' + sr.getErrors());
                }
            }
        }

        for (String extId : orderedExtIds) {


            ShipmentStatusResponse.ResultItem ri = resultByExtId.get(extId);
            output.results.add(ri);
             if (ri.outcome == 'UPDATED') output.processedCount++;
              else if (ri.outcome == 'FAILED') output.failedCount++;
               else output.skippedCount++;
        }

        return output;
    }
}