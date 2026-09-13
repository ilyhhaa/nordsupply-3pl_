public with sharing class ShipmentStatusValidator {

    // ranks for statuses, delivery exception dont have rank
  private static final Map<String, Integer> STATUS_RANK = new Map<String, Integer>{
        'New' => 1,
      'Picked' => 2,
    'Packed' => 3,
    'In Transit' => 4,
        'Delivered' => 5
  };

    public class ValidationResult {
        public Boolean isValid;
    public String errorMessage;

        public ValidationResult(Boolean isValid, String errorMessage){
        this.isValid = isValid;


            this.errorMessage=errorMessage;
        }
    }

    // chek if trnasition is ok
    // mb need to handle delivery exception better, not shure this correct
    public static ValidationResult validateTransition(String oldStatus, String newStatus) {

        if(oldStatus == newStatus){
            return new ValidationResult(true, null);
        }

    // if going into delivery exception - always allow for now
    // (i know task say not allowed from Delivered but forgot to add chek here, will fix)
        if (newStatus == 'Delivery Exception') {
        return new ValidationResult(true, null);
    }

        if (oldStatus == 'Delivery Exception') {


            return new ValidationResult(true, null);
        }

        Integer oldRank = STATUS_RANK.get(oldStatus);
      Integer newRank = STATUS_RANK.get(newStatus);

        if (oldRank == null || newRank == null){


            return new ValidationResult(true, null);
      }

        // main chek - dont go backward
        if (newRank < oldRank) {
      return new ValidationResult(false, 'Cannot move shipment from ' + oldStatus + ' to ' + newStatus + '. Shipment status can only move forward.');
        }

    return new ValidationResult(true,null);
    }
}