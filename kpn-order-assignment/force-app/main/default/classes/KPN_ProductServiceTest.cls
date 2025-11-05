/**
 * @description Test class for KPN_ProductService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class KPN_ProductServiceTest {
    
    // helper: create some products + PBEs
    private static List<Product2> createProductsWithPrices() {
        List<Product2> prods = new List<Product2>{
            new Product2(Name = 'KPN Unlimited Mobile', ProductCode = 'MOB-UNL-001', Family = 'Mobile', IsActive = true),
            new Product2(Name = 'KPN Fiber 1 Gbps',     ProductCode = 'BB-FIBER-1G',  Family = 'Broadband', IsActive = true),
            new Product2(Name = 'KPN TV Plus',          ProductCode = 'ADD-TV-PLUS',  Family = 'Add-on', IsActive = true)
        };
        insert prods;
        
        Id stdPbId = Test.getStandardPricebookId();
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : prods) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = stdPbId,
            Product2Id   = p.Id,
            UnitPrice    = 25,
            IsActive     = true
                ));
        }
        insert pbes;
        return prods;
    }
    
    @IsTest
    static void test_getProducts_basic() {
        createProductsWithPrices();
        
        Test.startTest();
        // don’t pass category -> avoids the dynamic ':category' in the string
        KPN_ProductService.ProductListResponse resp = KPN_ProductService.getProducts(
            null,         // category
        null,         // searchTerm
        null,         // minPrice
        null,         // maxPrice
        10,           // limit
        0,            // offset
        null,         // sortBy
        null          // sortOrder
            );
        Test.stopTest();
        
        System.assertEquals(true, resp.success, 'Response should be success = true');
        System.assertNotEquals(null, resp.data, 'Data should not be null');
        System.assertNotEquals(null, resp.data.products, 'Products list should not be null');
        System.assert(resp.data.products.size() > 0, 'Should return products');
        System.assert(resp.data.totalCount > 0, 'totalCount should be set');
    }
    
    @IsTest
    static void test_getProducts_search_and_pagination() {
        createProductsWithPrices();
        
        Test.startTest();
        KPN_ProductService.ProductListResponse resp = KPN_ProductService.getProducts(
            null,
        'KPN',   // searchTerm – all three should match
        null,
        null,
        2,       // limit 2 to test paging fields
        0,
        'Name',
        'ASC'
            );
        Test.stopTest();
        
        System.assertEquals(true, resp.success, 'Should be success');
        System.assertEquals(2, resp.data.pageSize, 'pageSize should match limit');
        System.assertEquals(1, resp.data.currentPage, 'First page should be 1');
        System.assert(resp.data.totalCount >= 2, 'totalCount should be >= returned rows');
    }
    
    @IsTest
    static void test_getProducts_error_is_captured() {
        // force an error by giving a silly sortBy that will cause invalid field
        // your code does: ORDER BY <escaped> <dir>, so an actually invalid field should blow up
        Test.startTest();
        KPN_ProductService.ProductListResponse resp = KPN_ProductService.getProducts(
            null,
        null,
        null,
        null,
        5,
        0,
        'DefinitelyNotAField__c',  // should cause an exception
        'ASC'
            );
        Test.stopTest();
        
        System.assertEquals(false, resp.success, 'On exception success should be false');
        System.assertNotEquals(null, resp.error, 'Error block should be populated');
        System.assertEquals('INTERNAL_ERROR', resp.error.code);
    }
}