// Он не должен делать SOQL и DML - только принять запрос и вызвать сервис
@RestResource(urlMapping='/logistics/v1/shipments/status')
global with sharing class ShipmentStatusRestResource {

    @HttpPost
    global static void handlePost() {

        // Достаем request и response из контекста
        RestRequest myRequest = RestContext.request;
        RestResponse myResponse = RestContext.response;

        myResponse.addHeader('Content-Type', 'application/json'); //отвечаем джейсоном

        // пытаемся распарсить жысн который прислали
        String requestBodyAsString = myRequest.requestBody.toString();

        ShipmentStatusRequest parsedRequest = null;

         Boolean jsonIsBad = false;
        String jsonErrorText = '';

        try 
        {
            parsedRequest = (ShipmentStatusRequest) JSON.deserialize(requestBodyAsString, ShipmentStatusRequest.class);
        }
         catch (Exception ex) {
            jsonIsBad = true;
            jsonErrorText = ex.getMessage();
        }

        if 
        (jsonIsBad == true) {
        
            myResponse.statusCode = 400;
        
            String errorJson = '{"error":"INVALID_JSON","message":"' + jsonErrorText + '"}';
            myResponse.responseBody = Blob.valueOf(errorJson);
            return;
        }

        if (parsedRequest.updates == null) {


            myResponse.statusCode = 400;
            myResponse.responseBody = Blob.valueOf('{"error":"NO_UPDATES","message":"updates is null"}');
            return;
        }

        if (parsedRequest.updates.size() == 0) {

             myResponse.statusCode = 400;
             myResponse.responseBody = Blob.valueOf('{"error":"NO_UPDATES","message":"updates is empty"}');
            return;
        }


        ShipmentStatusService myService = new ShipmentStatusService();

        try {
            ShipmentStatusResponse result = myService.processUpdates(parsedRequest);


            myResponse.statusCode = 200;

            
            
            String resultAsJson = JSON.serialize(result);
            myResponse.responseBody = Blob.valueOf(resultAsJson);

        } catch (Exception ex) {
    
            
            System.debug(LoggingLevel.ERROR, 'Ошибка в ShipmentStatusService: ' + ex.getMessage());
            System.debug(LoggingLevel.ERROR, ex.getStackTraceString());

            myResponse.statusCode = 500;
            myResponse.responseBody = Blob.valueOf('{"error":"INTERNAL_ERROR","message":"Something went wrong"}');
        }
    }
}