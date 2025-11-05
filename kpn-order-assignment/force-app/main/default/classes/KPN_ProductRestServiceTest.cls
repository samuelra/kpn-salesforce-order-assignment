/**
 * @description Test class for KPN_ProductRestService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class KPN_ProductRestServiceTest {
    
    private static void createProducts() {
        List<Product2> prods = new List<Product2>{
            new Product2(Name = 'KPN Unlimited Mobile', ProductCode = 'MOB-UNL-001', Family = 'Mobile', IsActive = true),
            new Product2(Name = 'KPN Fiber 1 Gbps',     ProductCode = 'BB-FIBER-1G',  Family = 'Broadband', IsActive = true)
        };
        insert prods;
        
        Id stdPbId = Test.getStandardPricebookId();
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 p : prods) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = stdPbId,
            Product2Id   = p.Id,
            UnitPrice    = 30,
            IsActive     = true
                ));
        }
        insert pbes;
    }
    
    @IsTest
    static void test_getAllProducts_success() {
        createProducts();
        
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/products/v1/products';
        req.httpMethod = 'GET';
        req.addParameter('limit', '10');
        
        RestResponse res = new RestResponse();
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        KPN_ProductRestService.getAllProducts();
        Test.stopTest();
        
        System.assertEquals(200, res.statusCode, 'Should return 200');
        
        String body = res.responseBody.toString();
        System.assert(body.contains('"success":true'), 'Body should say success:true');
        System.assert(body.contains('"products"'), 'Body should contain products list');
        System.assert(body.contains('"totalCount"'), 'Body should contain totalCount');
    }
    
    @IsTest
    static void test_getAllProducts_parseError_returns500() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/products/v1/products';
        req.httpMethod = 'GET';
        // this will make the service’s Decimal.valueOf(...) in controller part blow up
        req.addParameter('minPrice', 'not-a-number');
        
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        KPN_ProductRestService.getAllProducts();
        Test.stopTest();
        
        System.assertEquals(500, res.statusCode, 'Should return 500 for unexpected error');
        String body = res.responseBody.toString();
        System.assert(body.contains('"success":false'), 'Error response should have success=false');
        System.assert(body.contains('"INTERNAL_ERROR"'), 'Should contain INTERNAL_ERROR code');
    }
}