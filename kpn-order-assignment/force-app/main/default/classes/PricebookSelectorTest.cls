/**
 * @description Test class for PricebookSelector. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Your Name
 * @since 2025-11
 */
@IsTest
private class PricebookSelectorTest {
    
    @IsTest
    static void testGetStandardPricebookId_inTestContext() {
        // in tests your selector should return Test.getStandardPricebookId()
        Id stdId = PricebookSelector.getStandardPricebookId();
        System.assertNotEquals(null, stdId, 'Standard pricebook id should be returned in test');
        System.assertEquals(Test.getStandardPricebookId(), stdId, 'Should match test standard pricebook id');
    }
    
    @IsTest
    static void testGetPricebookById_null() {
        Pricebook2 pb = PricebookSelector.getPricebookById(null);
        System.assertEquals(null, pb, 'Should return null when id is null');
    }
    
    @IsTest
    static void testGetPricebookById_customPricebook() {
        // create a regular pricebook that we KNOW we can query
        Pricebook2 pbInsert = new Pricebook2(
            Name = 'KPN Test Pricebook',
        IsActive = true
            );
        insert pbInsert;
        
        Test.startTest();
        Pricebook2 fetched = PricebookSelector.getPricebookById(pbInsert.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, fetched, 'Pricebook should be returned');
        System.assertEquals(pbInsert.Id, fetched.Id, 'Returned pricebook should match inserted one');
        System.assertEquals('KPN Test Pricebook', fetched.Name);
    }
}