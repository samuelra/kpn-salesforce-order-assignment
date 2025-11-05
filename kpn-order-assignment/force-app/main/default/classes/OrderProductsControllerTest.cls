/**
 * @description Test class for OrderProductsController. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class OrderProductsControllerTest {
    
    // mock used when controller -> KpnOrderApiService -> callout
    private class OrderApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"success": true, "orderId": "EXT-TEST-001"}');
            return res;
        }
    }
    
    // create minimal AF data for controller to work
    private static Map<String, Id> createOrderGraph() {
        Map<String, Id> ids = new Map<String, Id>();
        
        Id stdPbId = Test.getStandardPricebookId();
        
        Account acc = new Account(Name = 'Controller Test Account');
        insert acc;
        ids.put('accountId', acc.Id);
        
        Product2 prod = new Product2(
            Name = 'KPN Mobile S',
        ProductCode = 'MOB-S',
        IsActive = true
            );
        insert prod;
        ids.put('productId', prod.Id);
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = prod.Id,
        UnitPrice    = 15,
        IsActive     = true
            );
        insert pbe;
        ids.put('pbeId', pbe.Id);
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = stdPbId,
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
        ids.put('orderId', ord.Id);
        
        OrderItem oi = new OrderItem(
            OrderId         = ord.Id,
        PricebookEntryId= pbe.Id,
        Quantity        = 1,
        UnitPrice       = 15
            );
        insert oi;
        ids.put('orderItemId', oi.Id);
        
        return ids;
    }
    
    @IsTest
    static void test_getOrderProducts() {
        Map<String, Id> data = createOrderGraph();
        Id orderId = data.get('orderId');
        
        Test.startTest();
        List<OrderService.OrderItemWrapper> items =
            OrderProductsController.getOrderProducts(orderId);
        Test.stopTest();
        
        System.assertNotEquals(null, items, 'controller should return a list');
        System.assertEquals(1, items.size(), 'controller should return the one line we created');
        System.assertEquals('KPN Mobile S', items[0].productName);
    }
    
    @IsTest
    static void test_activateOrder_triggersExternalCallout() {
        Map<String, Id> data = createOrderGraph();
        Id orderId = data.get('orderId');
        
        // mock the external order API
        Test.setMock(HttpCalloutMock.class, new OrderApiMock());
        
        Test.startTest();
        OrderService.OperationResult result =
            OrderProductsController.activateOrder(orderId);
        Test.stopTest();
        
        System.assertEquals(true, result.success, 'activation should succeed for our test order');
        System.assert(
            result.message.contains('External order sync started'),
        'controller should append external sync message'
            );
    }
    
    @IsTest
    static void test_isOrderActivated() {
        Map<String, Id> data = createOrderGraph();
        Id orderId = data.get('orderId');
        
        // initially false
        Boolean initial = OrderProductsController.isOrderActivated(orderId);
        System.assertEquals(false, initial, 'new draft order should not be activated');
        
        // activate through service so controller can see it
        Test.setMock(HttpCalloutMock.class, new OrderApiMock());
        Test.startTest();
        OrderProductsController.activateOrder(orderId);
        Test.stopTest();
        
        Boolean after = OrderProductsController.isOrderActivated(orderId);
        System.assertEquals(true, after, 'after activation controller should return true');
    }
    
    @IsTest
    static void test_getOrderProducts_exception_fixed() {
        Test.startTest();
        List<OrderService.OrderItemWrapper> items =
            OrderProductsController.getOrderProducts(null);
        Test.stopTest();
        
        System.assertNotEquals(null, items, 'Should handle null orderId gracefully');
    }
    
    
    @IsTest
    static void test_activateOrder_failedCase() {
        // Create a dummy order without items (activation will fail)
        Account acc = new Account(Name = 'Fail Account');
        insert acc;
        Id pbId = Test.getStandardPricebookId();
        Order ord = new Order(AccountId = acc.Id, Status = 'Draft',
        EffectiveDate = Date.today(), Pricebook2Id = pbId);
        insert ord;
        
        Test.startTest();
        OrderService.OperationResult res = OrderProductsController.activateOrder(ord.Id);
        Test.stopTest();
        
        System.assertEquals(false, res.success, 'Should fail because order has no products');
        System.assert(!res.message.contains('External order sync started'),
        'Should not trigger API callout when activation fails');
    }
    
    @IsTest
    static void test_catchBlocks() {
        // 1) getOrderProducts
        OrderProductsController.forceFailGetOrderProducts = true;
        try {
            OrderProductsController.getOrderProducts(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('getOrderProducts'));
        }
        
        // 2) activateOrder
        OrderProductsController.forceFailActivateOrder = true;
        try {
            OrderProductsController.activateOrder(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('activateOrder'));
        }
        
        // 3) isOrderActivated
        OrderProductsController.forceFailIsOrderActivated = true;
        try {
            OrderProductsController.isOrderActivated(null);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('isOrderActivated'));
        }
    }
    
    @IsTest
    static void test_removeOrderItem_success() {
        // arrange
        Map<String, Id> data = createOrderGraph();
        Id orderItemId = data.get('orderItemId');
        
        // act
        Test.startTest();
        OrderService.OperationResult res =
            OrderProductsController.removeOrderItem(orderItemId);
        Test.stopTest();
        
        // assert
        System.assertEquals(true, res.success, 'Should succeed removing existing order item');
        
        // make sure it’s actually gone
        Integer countAfter = [
            SELECT COUNT()
            FROM OrderItem
            WHERE Id = :orderItemId
        ];
        System.assertEquals(0, countAfter, 'Order item should be deleted from DB');
    }
    
    @IsTest
    static void test_removeOrderItem_missingId() {
        Test.startTest();
        OrderService.OperationResult res =
            OrderProductsController.removeOrderItem(null);
        Test.stopTest();
        
        System.assertEquals(false, res.success, 'Should fail when id is missing');
        System.assert(res.message.contains('required') || res.message.contains('ID'),
        'Message should tell caller ID is required');
    }
    
}