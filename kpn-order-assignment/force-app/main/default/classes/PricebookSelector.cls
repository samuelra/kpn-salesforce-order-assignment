/**
 * @description Selector for Pricebook2 records. Handles resolving the standard pricebook
 *               and fetching a specific pricebook. Test-friendly (uses Test.getStandardPricebookId()).
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class PricebookSelector {
    
    /**
     * @description Get standard pricebook ID
     * @return Standard Pricebook2 Id
     */
    public static Id getStandardPricebookId() {
        // Use Test.isRunningTest() to handle test context
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        
        List<Pricebook2> pricebooks = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        
        return pricebooks.isEmpty() ? null : pricebooks[0].Id;
    }
    
    /**
     * @description Get pricebook by ID
     * @param pricebookId The pricebook ID
     * @return Pricebook2 record
     */
    public static Pricebook2 getPricebookById(Id pricebookId) {
        if (pricebookId == null) {
            return null;
        }
        
        List<Pricebook2> pricebooks = [
            SELECT Id, Name, IsActive, IsStandard
            FROM Pricebook2
            WHERE Id = :pricebookId
            LIMIT 1
        ];
        
        return pricebooks.isEmpty() ? null : pricebooks[0];
    }
}