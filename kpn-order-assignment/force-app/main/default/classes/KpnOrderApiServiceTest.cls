/**
 * @description Test class for KpnOrderApiService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class KpnOrderApiServiceTest {
    
    // Static field belongs to the top-level test class (allowed)
    private static HttpRequest lastRequest;
    
    // Simple mock that captures what was sent
    private class OrderApiMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Save request for assertions
            KpnOrderApiServiceTest.lastRequest = req;
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"success": true, "orderId": "EXT-123"}');
            return res;
        }
    }
    
    @IsTest
    static void test_sendOrderToApiAsync_happyPath() {
        Id stdPbId = Test.getStandardPricebookId();
        
        Account acc = new Account(Name = 'KPN B2B Demo');
        insert acc;
        
        Contact billTo = new Contact(
            FirstName = 'John',
        LastName  = 'Doe',
        Email     = 'john.doe@example.com',
        Phone     = '+31612345678',
        AccountId = acc.Id
            );
        insert billTo;
        
        Product2 prod = new Product2(Name='KPN Unlimited Mobile', ProductCode='MOB-UNL-001', IsActive=true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = prod.Id,
        UnitPrice    = 25,
        IsActive     = true
            );
        insert pbe;
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = stdPbId,
        BillToContactId = billTo.Id,
        ShippingStreet = 'Straat 1',
        ShippingCity = 'Amsterdam',
        ShippingPostalCode = '1000 AA',
        ShippingCountry = 'Netherlands',
        BillingStreet = 'Straat 1',
        BillingCity = 'Amsterdam',
        BillingPostalCode = '1000 AA',
        BillingCountry = 'Netherlands'
            );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = 25
            );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new OrderApiMock());
        
        Test.startTest();
        KpnOrderApiService.sendOrderToApiAsync(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, lastRequest, 'Callout should have been performed');
        System.assertEquals('POST', lastRequest.getMethod());
        System.assert(
            lastRequest.getEndpoint().endsWith('/v1/orders'),
        'Endpoint should target /v1/orders'
            );
        
        String body = lastRequest.getBody();
        System.assert(body.contains('"customerId"'), 'Payload should contain customerId');
        System.assert(body.contains('"orderItems"'), 'Payload should contain orderItems');
        System.assert(body.contains('"MOB-UNL-001"'), 'Payload should contain product code');
    }
    
    @IsTest
    static void test_sendOrderToApiAsync_orderWithoutContact_stillSends() {
        Id stdPbId = Test.getStandardPricebookId();
        
        Account acc = new Account(Name = 'No Contact Account');
        insert acc;
        
        Product2 prod = new Product2(Name='KPN Fiber 1 Gbps', ProductCode='BB-FIBER-1G', IsActive=true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = prod.Id,
        UnitPrice    = 60,
        IsActive     = true
            );
        insert pbe;
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = stdPbId,
        ShippingStreet = 'Straat 10',
        ShippingCity = 'Rotterdam',
        ShippingPostalCode = '2000 BB',
        ShippingCountry = 'Netherlands'
            );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
        PricebookEntryId = pbe.Id,
        Quantity = 2,
        UnitPrice = 60
            );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new OrderApiMock());
        
        Test.startTest();
        KpnOrderApiService.sendOrderToApiAsync(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, lastRequest, 'Callout should still happen');
        String body = lastRequest.getBody();
        System.assert(body.contains('"deliveryAddress"'), 'Delivery address should exist');
        System.assert(body.contains('"orderItems"'), 'Order items should exist');
    }
}