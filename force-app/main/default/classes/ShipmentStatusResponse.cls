public class ShipmentStatusResponse {
    public String correlationId;
    public Datetime receivedAt;
    public Integer processedCount = 0;
    public Integer skippedCount = 0;
    public Integer failedCount = 0;
    public List<ResultItem> results = new List<ResultItem>();

    public class ResultItem {
        public String externalShipmentId;

        public String shipmentId;
        public String outcome;   
        public String errorCode;
        public String message;

        public ResultItem(String extId, String shipmentId, String outcome, String errorCode, String message) {
           
            this.externalShipmentId = extId;

            this.shipmentId = shipmentId;

            this.outcome = outcome;

            this.errorCode = errorCode;

            this.message = message;
        }
    }
}