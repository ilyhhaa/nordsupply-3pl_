public class ShipmentStatusRequest {
    public String correlationId;
    public List<UpdateItem> updates;

    public class UpdateItem {
        public String externalShipmentId;
        public String status;
        public String statusChangedAt; 
        public String carrier;
        public String trackingNumber;
        public String estimatedDeliveryDate; //тут y-m-d
        public String comment;
    }
}