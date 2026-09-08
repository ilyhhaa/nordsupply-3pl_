NordSupply 3PL Integration

REST API интеграция Salesforce со складской WMS-системой (inbound) 
и Platform Event для уведомления Customer Notification Service (outbound).

Контракт API

Endpoint: `POST /services/apexrest/logistics/v1/shipments/status`

### Пример запроса

```json
{
  "correlationId": "wms-batch-2026-08-29-0001",
  "updates": [
    {
      "externalShipmentId": "WMS-778812",
      "status": "IN_TRANSIT",
      "statusChangedAt": "2026-08-29T09:14:00Z",
      "carrier": "DHL",
      "trackingNumber": "DHL-4455667788"
    }
  ]
}
```

 Пример ответа

json
{
  "correlationId": "wms-batch-2026-08-29-0001",
  "receivedAt": "2026-08-29T09:21:03Z",
  "processedCount": 1,
  "skippedCount": 0,
  "failedCount": 0,
  "results": [
    {
      "externalShipmentId": "WMS-778812",
      "shipmentId": "a0X5g000004ABCDEAA",
      "outcome": "UPDATED",
      "errorCode": null,
      "message": null
    }
  ]
}

 Архитектура

 `ShipmentStatusRestResource` — REST-слой (парсинг, роутинг, HTTP-коды)
 `ShipmentStatusService` — бизнес-логика (валидация, маппинг, идемпотентность, публикация события)
 `ShipmentSelector` — SOQL-запросы
 `Shipment_Status_Changed__e` (Platform Event, Publish After Commit) — уведомление подписчиков о смене статуса

Как проверить 

1. Создай Account и запись `Shipment__c` со статусом `Packed`, `External_Shipment_Id__c = WMS-TEST-1`
2. Через Salesforce Inspector Reloaded → REST Explore отправь POST-запрос по контракту выше (замени `externalShipmentId` на `WMS-TEST-1`)
3. Проверь HTTP 200 и обновление статуса на `In Transit`
4. Открой объект `Integration_Log__c` — должна появиться запись, подтверждающая, что Platform Event был доставлен подписчику

Тесты

Покрытие: 93%+ (ShipmentStatusService), 85%+ (ShipmentStatusRestResource)

Запуск:

sf apex run test --class-names ShipmentStatusServiceTest --target-org <org> --code-coverage --synchronous
