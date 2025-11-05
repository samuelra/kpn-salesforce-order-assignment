/**
 * @description Test class for ProductSelector. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class ProductSelectorTest {
    
    @IsTest
    static void testGetProductsWithPricebookEntries() {
        // arrange
        Id stdPbId = Test.getStandardPricebookId();
        
        // create 2 active products
        Product2 p1 = new Product2(Name = 'KPN Mobile 5G', ProductCode = 'KPN-MOB-5G', IsActive = true);
        Product2 p2 = new Product2(Name = 'KPN Fiber 1Gbps', ProductCode = 'KPN-FIB-1G', IsActive = true);
        insert new List<Product2>{ p1, p2 };
        
        // create PBEs in standard PB
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = p1.Id,
        UnitPrice    = 25,
        IsActive     = true
            );
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = p2.Id,
        UnitPrice    = 55,
        IsActive     = true
            );
        insert new List<PricebookEntry>{ pbe1, pbe2 };
        
        Test.startTest();
        List<Product2> result = ProductSelector.getProductsWithPricebookEntries(stdPbId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 2, 'We should get at least the 2 products we just created');
        
        // make sure subquery is there
        Boolean foundSub = false;
        for (Product2 p : result) {
            if (p.Id == p1.Id || p.Id == p2.Id) {
                System.assert(p.PricebookEntries != null, 'PricebookEntries should be loaded');
                System.assert(p.PricebookEntries.size() > 0, 'Product should have at least one PBE');
                foundSub = true;
            }
        }
        System.assert(foundSub, 'At least one of our products should be in the result');
    }
    
    @IsTest
    static void testGetProductsWithPricebookEntries_nullPricebook() {
        List<Product2> result = ProductSelector.getProductsWithPricebookEntries(null);
        System.assertEquals(0, result.size(), 'Should return empty list when pricebookId is null');
    }
    
    @IsTest
    static void testGetProductsByIdsWithPricebookEntries() {
        Id stdPbId = Test.getStandardPricebookId();
        
        // create a product
        Product2 p1 = new Product2(Name = 'KPN TV Plus', ProductCode = 'KPN-TV-PLUS', IsActive = true);
        insert p1;
        
        // create pbe
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = p1.Id,
        UnitPrice    = 15,
        IsActive     = true
            );
        insert pbe1;
        
        // call
        Set<Id> ids = new Set<Id>{ p1.Id };
        
        Test.startTest();
        Map<Id, Product2> productMap = ProductSelector.getProductsByIdsWithPricebookEntries(ids, stdPbId);
        Test.stopTest();
        
        System.assertEquals(1, productMap.size(), 'We should get exactly 1 product back');
        System.assert(productMap.containsKey(p1.Id), 'Map should contain our product id');
        
        Product2 fetched = productMap.get(p1.Id);
        System.assertNotEquals(null, fetched, 'Fetched product should not be null');
        System.assertNotEquals(null, fetched.PricebookEntries, 'Fetched product should have PBEs loaded');
        System.assertEquals(1, fetched.PricebookEntries.size(), 'We limited the subquery to 1 PBE');
        System.assertEquals(stdPbId, fetched.PricebookEntries[0].Pricebook2Id, 'PBE should be from the given pricebook');
    }
    
    @IsTest
    static void testGetProductsByIdsWithPricebookEntries_emptyArgs() {
        // null ids
        Map<Id, Product2> m1 = ProductSelector.getProductsByIdsWithPricebookEntries(null, Test.getStandardPricebookId());
        System.assertEquals(0, m1.size(), 'Null ids should return empty map');
        
        // empty ids
        Map<Id, Product2> m2 = ProductSelector.getProductsByIdsWithPricebookEntries(new Set<Id>(), Test.getStandardPricebookId());
        System.assertEquals(0, m2.size(), 'Empty ids should return empty map');
        
        // null pricebook
        Product2 p = new Product2(Name='X', IsActive=true);
        insert p;
        Map<Id, Product2> m3 = ProductSelector.getProductsByIdsWithPricebookEntries(new Set<Id>{p.Id}, null);
        System.assertEquals(0, m3.size(), 'Null pricebook should return empty map');
    }
}