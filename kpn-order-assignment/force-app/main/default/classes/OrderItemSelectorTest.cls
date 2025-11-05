/**
 * @description Test class for OrderItemSelector. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class OrderItemSelectorTest {
    
    @IsTest
    static void testGetOrderItemsByOrderId_whenNull() {
        List<OrderItem> items = OrderItemSelector.getOrderItemsByOrderId(null);
        System.assertNotEquals(null, items, 'Should return a non-null list');
        System.assertEquals(0, items.size(), 'Null orderId should return empty list');
    }
    
    @IsTest
    static void testGetOrderItemsByOrderId_happyPath() {
        // setup: order + product + order item
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        PricebookEntry pbe = getStandardPbe(productId);
        
        OrderItem oi = new OrderItem(
            OrderId = orderId,
        Product2Id = productId,
        PricebookEntryId = pbe.Id,
        Quantity = 2,
        UnitPrice = pbe.UnitPrice
            );
        insert oi;
        
        Test.startTest();
        List<OrderItem> items = OrderItemSelector.getOrderItemsByOrderId(orderId);
        Test.stopTest();
        
        System.assertEquals(1, items.size(), 'Should return the order item we just created');
        System.assertEquals(productId, items[0].Product2Id);
        System.assertEquals(orderId, items[0].OrderId);
    }
    
    @IsTest
    static void testGetOrderItemsByOrderIds_whenEmptySet() {
        Map<Id, List<OrderItem>> result = OrderItemSelector.getOrderItemsByOrderIds(new Set<Id>());
        System.assertNotEquals(null, result, 'Should return non-null map');
        System.assertEquals(0, result.size(), 'Empty set should return empty map');
    }
    
    @IsTest
    static void testGetOrderItemsByOrderIds_happyPath() {
        // order 1
        Id orderId1 = createTestOrder();
        Id productId1 = createTestProduct('OIS Prod 1', 'OIS-001');
        PricebookEntry pbe1 = getStandardPbe(productId1);
        insert new OrderItem(
            OrderId = orderId1,
        Product2Id = productId1,
        PricebookEntryId = pbe1.Id,
        Quantity = 1,
        UnitPrice = pbe1.UnitPrice
            );
        
        // order 2
        Id orderId2 = createTestOrder();
        Id productId2 = createTestProduct('OIS Prod 2', 'OIS-002');
        PricebookEntry pbe2 = getStandardPbe(productId2);
        insert new OrderItem(
            OrderId = orderId2,
        Product2Id = productId2,
        PricebookEntryId = pbe2.Id,
        Quantity = 3,
        UnitPrice = pbe2.UnitPrice
            );
        
        Set<Id> orderIds = new Set<Id>{ orderId1, orderId2 };
        
        Test.startTest();
        Map<Id, List<OrderItem>> result = OrderItemSelector.getOrderItemsByOrderIds(orderIds);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should have entries for both orders');
        System.assertEquals(1, result.get(orderId1).size(), 'Order 1 should have 1 item');
        System.assertEquals(1, result.get(orderId2).size(), 'Order 2 should have 1 item');
    }
    
    @IsTest
    static void testGetOrderItemByOrderAndProduct_found() {
        Id orderId = createTestOrder();
        Id productId = createTestProduct('Findable Prod', 'FND-001');
        PricebookEntry pbe = getStandardPbe(productId);
        
        OrderItem oi = new OrderItem(
            OrderId = orderId,
        Product2Id = productId,
        PricebookEntryId = pbe.Id,
        Quantity = 1,
        UnitPrice = pbe.UnitPrice
            );
        insert oi;
        
        Test.startTest();
        OrderItem found = OrderItemSelector.getOrderItemByOrderAndProduct(orderId, productId);
        Test.stopTest();
        
        System.assertNotEquals(null, found, 'Should find the order item');
        System.assertEquals(oi.Id, found.Id, 'Should return the exact order item');
    }
    
    @IsTest
    static void testGetOrderItemByOrderAndProduct_notFound() {
        Id orderId = createTestOrder();
        Id productId = createTestProduct('Unrelated Prod', 'URP-001');
        // no order item inserted
        
        OrderItem found = OrderItemSelector.getOrderItemByOrderAndProduct(orderId, productId);
        System.assertEquals(null, found, 'Should return null when no item matches');
    }
    
    /*
     * ===== helpers =====
     */
    private static Id createTestOrder() {
        Account acc = new Account(Name = 'OIS Test Account');
        insert acc;
        
        Order o = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        insert o;
        return o.Id;
    }
    
    private static Id createTestProduct() {
        return createTestProduct('OIS Test Product', 'OIS-PRD');
    }
    
    private static Id createTestProduct(String name, String code) {
        Product2 p = new Product2(
            Name = name,
        ProductCode = code,
        IsActive = true
            );
        insert p;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id   = p.Id,
        UnitPrice    = 25,
        IsActive     = true
            );
        insert pbe;
        
        return p.Id;
    }
    
    private static PricebookEntry getStandardPbe(Id productId) {
        return [
            SELECT Id, UnitPrice 
            FROM PricebookEntry 
            WHERE Pricebook2Id = :Test.getStandardPricebookId()
            AND Product2Id = :productId
            AND IsActive = true
            LIMIT 1
        ];
    }
}