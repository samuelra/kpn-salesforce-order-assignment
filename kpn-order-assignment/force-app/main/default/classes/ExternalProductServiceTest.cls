/**
 * @description Test class for ExternalProductService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class ExternalProductServiceTest {
    
    // ------------------ happy path: list ------------------
    @IsTest
    static void test_getExternalProducts_list() {
        // arrange
        Test.setMock(HttpCalloutMock.class, new ProductListMock());
        
        Test.startTest();
        List<ExternalProductService.ProductWrapper> products =
            ExternalProductService.getExternalProducts();
        Test.stopTest();
        
        System.assertNotEquals(null, products, 'products should not be null');
        System.assertEquals(2, products.size(), 'should map 2 products');
        
        ExternalProductService.ProductWrapper p1 = products[0];
        System.assertEquals('MOB-001', p1.productCode);
        System.assertEquals('KPN Unlimited Mobile', p1.productName);
        System.assertEquals(27.50, p1.listPrice);
        System.assertEquals(true, p1.isExternal);
        System.assertEquals('KPN Product API', p1.source);
        
        ExternalProductService.ProductWrapper p2 = products[1];
        System.assertEquals('BB-100', p2.productCode);
        System.assertEquals('KPN Fiber 1 Gbps', p2.productName);
        System.assertEquals(55, p2.listPrice);
    }
    
    // ------------------ happy path: single object ------------------
    @IsTest
    static void test_getExternalProducts_singleObject() {
        Test.setMock(HttpCalloutMock.class, new SingleProductMock());
        
        Test.startTest();
        List<ExternalProductService.ProductWrapper> products =
            ExternalProductService.getExternalProducts();
        Test.stopTest();
        
        System.assertEquals(1, products.size(), 'should map single product object');
        
        ExternalProductService.ProductWrapper p = products[0];
        System.assertEquals('ADD-001', p.productCode);
        System.assertEquals('Extra TV Package', p.productName);
    }
    
    // ------------------ non-200 branch ------------------
    @IsTest
    static void test_getExternalProducts_404() {
        Test.setMock(HttpCalloutMock.class, new NotFoundMock());
        
        Test.startTest();
        List<ExternalProductService.ProductWrapper> products =
            ExternalProductService.getExternalProducts();
        Test.stopTest();
        
        // on 404 your code just logs and returns empty list
        System.assertEquals(0, products.size(), '404 should return empty list');
    }
    
    // ==========================================================
    // Mocks
    // ==========================================================
    
    // returns { success: true, data: [ {...}, {...} ] }
    private class ProductListMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('GET', req.getMethod());
            System.assert(
                req.getEndpoint().endsWith('/v1/products'),
            'endpoint should be /v1/products'
                );
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            // matches what ExternalProductService expects
            res.setBody(
                '{"success":true,"data":[' +
                '{' +
                '"id":"prod-001",' +
                '"name":"KPN Unlimited Mobile",' +
                '"productCode":"MOB-001",' +
                '"category":"Mobile",' +
                '"price":27.50,' +
                '"stock":50' +
                '},' +
                '{' +
                '"id":"prod-002",' +
                '"name":"KPN Fiber 1 Gbps",' +
                '"productCode":"BB-100",' +
                '"category":"Broadband",' +
                '"listPrice":55,' +
                '"stock":10' +
                '}' +
                ']}'
                );
            return res;
        }
    }
    
    // returns { success: true, data: { ... } }
    private class SingleProductMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"success":true,"data":{' +
                '"id":"prod-003",' +
                '"name":"Extra TV Package",' +
                '"productCode":"ADD-001",' +
                '"category":"Add-on","price":9.95' +
                '}}'
                );
            return res;
        }
    }
    
    // returns 404
    private class NotFoundMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('{"message":"Not found"}');
            return res;
        }
    }
}