/**
 * @description Test class for OrderService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class OrderServiceTest {
    
    private static Map<String, Id> createOrderGraph() {
        Map<String, Id> ids = new Map<String, Id>();
        
        Id stdPbId = Test.getStandardPricebookId();
        
        Account acc = new Account(Name = 'Service Test Account');
        insert acc;
        ids.put('accountId', acc.Id);
        
        Product2 prod = new Product2(
            Name = 'KPN Fiber 1 Gbps',
        ProductCode = 'FIBER-1G',
        IsActive = true
            );
        insert prod;
        ids.put('productId', prod.Id);
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = prod.Id,
        UnitPrice    = 55,
        IsActive     = true
            );
        insert pbe;
        ids.put('pbeId', pbe.Id);
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = stdPbId
            );
        insert ord;
        ids.put('orderId', ord.Id);
        
        // one existing line
        OrderItem oi = new OrderItem(
            OrderId         = ord.Id,
        PricebookEntryId= pbe.Id,
        Quantity        = 1,
        UnitPrice       = 55
            );
        insert oi;
        ids.put('orderItemId', oi.Id);
        
        return ids;
    }
    
    private static Map<String, Id> createOrderGraphWithoutItems() {
        Map<String, Id> ids = new Map<String, Id>();
        
        Id stdPbId = Test.getStandardPricebookId();
        
        Account acc = new Account(Name = 'Service Test Account (no items)');
        insert acc;
        ids.put('accountId', acc.Id);
        
        Product2 prod = new Product2(
            Name = 'KPN Mobile Unlimited',
        ProductCode = 'MOB-UNL',
        IsActive = true
            );
        insert prod;
        ids.put('productId', prod.Id);
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
        Product2Id   = prod.Id,
        UnitPrice    = 27.50,
        IsActive     = true
            );
        insert pbe;
        ids.put('pbeId', pbe.Id);
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = stdPbId
            );
        insert ord;
        ids.put('orderId', ord.Id);
        
        return ids;
    }
    
    @IsTest
    static void test_getOrderProducts() {
        Map<String, Id> data = createOrderGraph();
        Id orderId = data.get('orderId');
        
        Test.startTest();
        List<OrderService.OrderItemWrapper> wrappers =
            OrderService.getOrderProducts(orderId);
        Test.stopTest();
        
        System.assertEquals(1, wrappers.size(), 'Should return the single order line');
        System.assertEquals('KPN Fiber 1 Gbps', wrappers[0].productName);
    }
    
    @IsTest
    static void test_addProductToOrder_increaseQuantity_whenAlreadyExists() {
        Map<String, Id> data = createOrderGraph();
        Id orderId   = data.get('orderId');
        Id productId = data.get('productId');
        
        Test.startTest();
        // first call should increment because item already exists
        OrderService.OperationResult res =
            OrderService.addProductToOrder(orderId, productId);
        Test.stopTest();
        
        System.assertEquals(true, res.success, 'Should succeed and increment');
        
        OrderItem oi = [
            SELECT Quantity
            FROM OrderItem
            WHERE OrderId = :orderId
            AND Product2Id = :productId
            LIMIT 1
        ];
        System.assertEquals(2, oi.Quantity, 'Quantity should be 2 after increment');
    }
    
    @IsTest
    static void test_addProductToOrder_createsNewOrderItem_whenNotExists() {
        Map<String, Id> data = createOrderGraphWithoutItems();
        Id orderId   = data.get('orderId');
        Id productId = data.get('productId');
        
        Test.startTest();
        OrderService.OperationResult res =
            OrderService.addProductToOrder(orderId, productId);
        Test.stopTest();
        
        System.assertEquals(true, res.success, 'Should create a brand new order item');
        System.assertNotEquals(null, res.recordId, 'Should return created order item id');
        
        OrderItem created = [
            SELECT OrderId, Product2Id, Quantity, UnitPrice
            FROM OrderItem
            WHERE Id = :res.recordId
            LIMIT 1
        ];
        System.assertEquals(orderId, created.OrderId);
        System.assertEquals(productId, created.Product2Id);
        System.assertEquals(1, created.Quantity, 'New items are created with quantity = 1');
    }
    
    @IsTest
    static void test_activateOrder() {
        Map<String, Id> data = createOrderGraph();
        Id orderId = data.get('orderId');
        
        Test.startTest();
        OrderService.OperationResult res = OrderService.activateOrder(orderId);
        Test.stopTest();
        
        System.assertEquals(true, res.success, 'Activation should succeed');
        
        Boolean activated = OrderService.isOrderActivated(orderId);
        System.assertEquals(true, activated, 'Order should now be in activated status');
    }
}