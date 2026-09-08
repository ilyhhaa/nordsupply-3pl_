@IsTest
private class ShipmentStatusServiceTest {

    private static final String REST_URI = '/services/apexrest/logistics/v1/shipments/status';


    @TestSetup

    static void setup()
     {
        Account acc = new Account(Name = 'Test Customer');
       
        insert acc;

        insert new Shipment__c(

            Customer__c = acc.Id,
            External_Shipment_Id__c = 'WMS-1',
            Status__c = 'Packed',
            Last_Status_Update__c = Datetime.now().addHours(-2)
        );


        List<Shipment__c> bulkShipments = new List<Shipment__c>();

        for (Integer i = 0; i < 200; i++) {

            bulkShipments.add(new Shipment__c(
                Customer__c = acc.Id,
                External_Shipment_Id__c = 'BULK-' + i,
                Status__c = 'Packed',
                Last_Status_Update__c = Datetime.now().addHours(-2)
            ));
        }

        insert bulkShipments;
    }

    private static RestRequest buildRequest(String jsonBody) {
        RestRequest req = new RestRequest();
        req.requestURI = REST_URI;
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(jsonBody);
        return req;
    }

    // Позитифф один апдейт запись обновлена, событие опубликовано


    @IsTest
static void testSingleUpdate_Success() {
    String body = '{'
        + '"correlationId":"test-positive",'

        + '"updates":[{'
            + '"externalShipmentId":"WMS-1",'
            + '"status":"IN_TRANSIT",'

            + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '",'
            + '"carrier":"DHL",'

            + '"trackingNumber":"DHL-123456"'
        + '}]'
    + '}';

    RestContext.request = buildRequest(body);
    RestContext.response = new RestResponse();

    Test.startTest();
    
    ShipmentStatusRestResource.handlePost();

    // Забираем результат уже, до deliver()/stopTest()
    Integer capturedStatusCode = RestContext.response.statusCode;
    Blob capturedBody = RestContext.response.responseBody;

    Test.getEventBus().deliver();
    
    Test.stopTest();
     

    System.assertEquals(200, capturedStatusCode, 'Должен вернуться 200');

    Shipment__c updated = [
        SELECT Status__c, Carrier__c, Tracking_Number__c
        FROM Shipment__c
        WHERE External_Shipment_Id__c = 'WMS-1'
    ];
    System.assertEquals('In Transit', updated.Status__c, 'Статус должен обновиться');


    System.assertEquals('DHL', updated.Carrier__c, 'Carrier должен обновиться');

    System.assertEquals('DHL-123456', updated.Tracking_Number__c, 'Tracking number должен обновиться');

    ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(

        capturedBody.toString(), ShipmentStatusResponse.class
    );
    System.assertEquals(1, resp.processedCount, 'processedCount должен быть 1');


    System.assertEquals('UPDATED', resp.results[0].outcome, 'outcome должен быть UPDATED');

    List<Integration_Log__c> logs = [SELECT Id, Payload__c FROM Integration_Log__c];

    System.assertEquals(1, logs.size(), 'Событие должно быть доставлено подписчику ровно один раз');
}


    // 200 элементов в одном запросе

    @IsTest

static void testBulk200Items() {

    List<String> updatesJson = new List<String>();


    for (Integer i = 0; i < 200; i++) {

        updatesJson.add('{'
            + '"externalShipmentId":"BULK-' + i + '",'
            + '"status":"IN_TRANSIT",'
            + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
        + '}');
    }

    String body = '{"correlationId":"test-bulk","updates":[' + String.join(updatesJson, ',') + ']}';


    RestContext.request = buildRequest(body);



    RestContext.response = new RestResponse();

    Integer queriesBefore = Limits.getQueries();

    Integer dmlBefore = Limits.getDmlStatements();

    Test.startTest();

    ShipmentStatusRestResource.handlePost();


    Integer capturedStatusCode = RestContext.response.statusCode;
    Blob capturedBody = RestContext.response.responseBody;

    Test.getEventBus().deliver();

    Test.stopTest();
    

    System.assertEquals(200, capturedStatusCode);



    ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(


        capturedBody.toString(), ShipmentStatusResponse.class
    );
    
    System.assertEquals(200, resp.processedCount, 'Все 200 элеме нтов должны обновиться');

    List<Shipment__c> updated = [

        SELECT Id FROM Shipment__c WHERE Status__c = 'In Transit'

    ];
    System.assertEquals(200, updated.size(), 'Все 200 записей  должныы обновиться в базе');

    Integer queriesUsed = Limits.getQueries() - queriesBefore;


    Integer dmlUsed = Limits.getDmlStatements() - dmlBefore;


    System.assert(queriesUsed <= 2, 'Должен быть максимум 1-2  SOQL на весь bulk запрос, использованоо: ' + queriesUsed);

    System.assert(dmlUsed <= 2, 'Должен быть максимум 1-2  DML на весь bulk запрос, использовано: ' + dmlUsed);
}

    // частичный саксес смесь валидных и невалидных элементов


    @IsTest
static void testPartialSuccess() {

    String body = '{'
        + '"correlationId":"test-partial",'
        + '"updates":['
            + '{"externalShipmentId":"WMS-1","status":"IN_TRANSIT","statusChangedAt":"'
                + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"},'
            + '{"externalShipmentId":"WMS-DOES-NOT-EXIST","status":"IN_TRANSIT","statusChangedAt":"'
                + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"},'
            + '{"externalShipmentId":"BULK-1","status":"TELEPORTED","statusChangedAt":"'
                + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"}'
        + ']'
    + '}';

    RestContext.request = buildRequest(body);

    RestContext.response = new RestResponse();


    Test.startTest();


    ShipmentStatusRestResource.handlePost();


    Integer capturedStatusCode = RestContext.response.statusCode;
    Blob capturedBody = RestContext.response.responseBody;

    Test.getEventBus().deliver();


    Test.stopTest();
    


    System.assertEquals(200, capturedStatusCode, 'Даже с  частичными ошибками возвращается 200');

    ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(
        capturedBody.toString(), ShipmentStatusResponse.class
    );
    System.assertEquals(1, resp.processedCount, 'Один элемент  должен обновиться');

    System.assertEquals(2, resp.failedCount, 'Два элемента должны упасть с ошибкой');

    System.assertEquals(3, resp.results.size(), 'В ответе должноо быть  3 результата');

}


    // 4. SHIPMENT_NOT_FOUND


    @IsTest
    static void testShipmentNotFound()  {
        String body = '{'
            + '"correlationId":"test-notfound",'
            + '"updates":[{'
                + '"externalShipmentId":"WMS-DOES-NOT-EXIST",'
                + '"status":"IN_TRANSIT",'
                + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
            + '}]'
        + '}';

        RestContext.request  = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        ShipmentStatusRestResource.handlePost();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);

       
        ShipmentStatusResponse resp  = (ShipmentStatusResponse) JSON.deserialize(
            RestContext.response.responseBody.toString(), ShipmentStatusResponse.class
        );
        System.assertEquals(1,  resp.failedCount);
        System.assertEquals('SHIPMENT_NOT_FOUND', resp.results[0].errorCode);
    }


    // 5. UNKNOWN_STATUS


    @IsTest
    static void testUnknownStatus() {
        String body = '{'
            + '"correlationId":"test-unknownstatus",'

            + '"updates":[{'
                + '"externalShipmentId":"WMS-1",'
                + '"status":"FLYING_TO_MARS",'
                + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
            + '}]'
        + '}';

        RestContext.request = buildRequest(body);


        RestContext.response = new RestResponse();

        Test.startTest();

        ShipmentStatusRestResource.handlePost();
        Test.stopTest();


        System.assertEquals(200, RestContext.response.statusCode);


        ShipmentStatusResponse   resp = (ShipmentStatusResponse) JSON.deserialize(
            RestContext.response.responseBody.toString(), ShipmentStatusResponse.class
        );
        System.assertEquals(1,  resp.failedCount);
        System.assertEquals('UNKNOWN_STATUS', resp.results[0].errorCode);


        Shipment__c s = [SELECT Status__c FROM Shipment__c WHERE External_Shipment_Id__c = 'WMS-1'];


        System.assertEquals('Packed', s.Status__c, 'Статус не должен был изменитьсяя');
    }


    //повторная отправка того же апдейта 


    @IsTest


static void testIdempotency_SkippedOutdated() {



    Datetime oldTime = Datetime.now().addHours(-5);

    String body = '{'
        + '"correlationId":"test-idempotency",'
        + '"updates":[{'
            + '"externalShipmentId":"WMS-1",'
            + '"status":"IN_TRANSIT",'
            + '"statusChangedAt":"' + oldTime.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + 
            '"'
        + '}]'
    + '}';

    RestContext.request = buildRequest(body);


    RestContext.response = new RestResponse();



    Test.startTest();
    ShipmentStatusRestResource.handlePost();

    Integer capturedStatusCode = RestContext.response.statusCode;
    Blob capturedBody = RestContext.response.responseBody;

    Test.getEventBus().deliver();

    Test.stopTest();

    System.assertEquals(200, capturedStatusCode);

    ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(


        capturedBody.toString(), ShipmentStatusResponse.class
    );
    System.assertEquals(1, resp.skippedCount, 'Должен быть 1 skipped');


    System.assertEquals('SKIPPED_OUTDATED', resp.results[0].outcome);

    Shipment__c s = [SELECT Status__c FROM Shipment__c WHERE External_Shipment_Id__c = 'WMS-1'];


    System.assertEquals('Packed', s.Status__c, 'Статус не должен был  изменитьсяя, апдейт устарел');



    List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];


    System.assertEquals(0, logs.size(), 'Событие не должно публиковаться дляя устаревшего апдейта');




}

    // (статус совпадает с текущим)
    

    @IsTest



    static void testSkippedNoChange() {


        String body = '{'
            + '"correlationId":"test-nochange",'
            + '"updates":[{'
                + '"externalShipmentId":"WMS-1",'
                + '"status":"PACKED",'
                + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
            + '}]'
        + '}';



        RestContext.request = buildRequest(body);


        RestContext.response = new RestResponse();



        Test.startTest();
        ShipmentStatusRestResource.handlePost();
        


        Test.stopTest();
        Test.getEventBus().deliver();



        ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(
            RestContext.response.responseBody.toString(), ShipmentStatusResponse.class
        );


        System.assertEquals('SKIPPED_NO_CHANGE', resp.results[0].outcome);



        List<Integration_Log__c> logs = [SELECT Id FROM Integration_Log__c];


        System.assertEquals(0, logs.size(), 'Событие не должно публиковаться, если статус не менялся');


    }

    // НЕВАЛИДНЫЙ JSON
 

    @IsTest
    static void testInvalidJson_Returns400() {
        RestContext.request = buildRequest('{this is not valid json!!!');
        RestContext.response = new RestResponse();

        Test.startTest();
        ShipmentStatusRestResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    //пустой updates

    @IsTest
    static void testEmptyUpdates_Returns400() {
        RestContext.request = buildRequest('{"correlationId":"test-empty","updates":[]}');
        RestContext.response = new RestResponse();

        Test.startTest();
        ShipmentStatusRestResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

   
    //больше 200 элементов 
   

    @IsTest
    static void testTooManyItems_Returns400() {
        List<String> updatesJson = new List<String>();
        for (Integer i = 0; i < 201; i++) {
            updatesJson.add('{'
                + '"externalShipmentId":"X-' + i + '",'
                + '"status":"NEW",'
                + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
            + '}');
        }
        String body = '{"correlationId":"test-toomany","updates":[' + String.join(updatesJson, ',') + ']}';

        RestContext.request = buildRequest(body);
        RestContext.response = new RestResponse();

        Test.startTest();
        ShipmentStatusRestResource.handlePost();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    //MISSING_REQUIRED_FIELD
  

    @IsTest
    static void testMissingRequiredField() {

        // status отсутствует



        String body = '{'
            + '"correlationId":"test-missing",'
            + '"updates":[{'
                + '"externalShipmentId":"WMS-1",'
                + '"statusChangedAt":"' + Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '"'
            + '}]'
        + '}';


        RestContext.request = buildRequest(body);


        RestContext.response = new RestResponse();


        Test.startTest();

        ShipmentStatusRestResource.handlePost();

        Test.stopTest();


        ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(


            RestContext.response.responseBody.toString(), ShipmentStatusResponse.class
        );
        System.assertEquals('MISSING_REQUIRED_FIELD', resp.results[0].errorCode);

    }

    //INVALID_DATE_FORMAT


    @IsTest
    static void testInvalidDateFormat() {


        String body = '{'
            + '"correlationId":"test-baddate",'
            + '"updates":[{'
                + '"externalShipmentId":"WMS-1",'
                + '"status":"IN_TRANSIT",'
                + '"statusChangedAt":"not-a-real-date"'
            + '}]'
        + '}';


        RestContext.request = buildRequest(body);


        RestContext.response = new RestResponse();

        Test.startTest();

        ShipmentStatusRestResource.handlePost();



        Test.stopTest();

        ShipmentStatusResponse resp = (ShipmentStatusResponse) JSON.deserialize(


            RestContext.response.responseBody.toString(), ShipmentStatusResponse.class


        );
        System.assertEquals('INVALID_DATE_FORMAT', resp.results[0].errorCode);
    }
}
