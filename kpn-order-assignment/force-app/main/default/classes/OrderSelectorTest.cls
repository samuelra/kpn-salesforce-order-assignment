/**
 * @description Test class for OrderSelector. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class OrderSelectorTest {
    
    @IsTest
    static void testGetOrderWithDetails_null() {
        Order o = OrderSelector.getOrderWithDetails(null);
        System.assertEquals(null, o, 'Should return null when orderId is null');
    }
    
    @IsTest
    static void testGetOrderWithDetails_happyPath() {
        Id orderId = createTestOrder();
        
        Test.startTest();
        Order o = OrderSelector.getOrderWithDetails(orderId);
        Test.stopTest();
        
        System.assertNotEquals(null, o, 'Order should be returned');
        System.assertEquals(orderId, o.Id, 'Returned order should match id');
        System.assertNotEquals(null, o.Pricebook2Id, 'We selected Pricebook2Id in SOQL, it should be populated');
        System.assertNotEquals(null, o.AccountId, 'We selected AccountId in SOQL, it should be populated');
    }
    
    @IsTest
    static void testGetOrdersByIds_nullOrEmpty() {
        Map<Id, Order> fromNull = OrderSelector.getOrdersByIds(null);
        System.assertNotEquals(null, fromNull, 'Should return empty map, not null');
        System.assertEquals(0, fromNull.size(), 'Null should return empty map');
        
        Map<Id, Order> fromEmpty = OrderSelector.getOrdersByIds(new Set<Id>());
        System.assertNotEquals(null, fromEmpty, 'Should return empty map, not null');
        System.assertEquals(0, fromEmpty.size(), 'Empty set should return empty map');
    }
    
    @IsTest
    static void testGetOrdersByIds_happyPath() {
        Id order1 = createTestOrder();
        Id order2 = createTestOrder();
        
        Set<Id> ids = new Set<Id>{ order1, order2 };
        
        Test.startTest();
        Map<Id, Order> result = OrderSelector.getOrdersByIds(ids);
        Test.stopTest();
        
        System.assertEquals(2, result.size(), 'Should return both orders');
        System.assert(result.containsKey(order1), 'Map should contain first order');
        System.assert(result.containsKey(order2), 'Map should contain second order');
    }
    
    // ===== helper =====
    private static Id createTestOrder() {
        Account acc = new Account(Name = 'OrderSelectorTest Acc');
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
}