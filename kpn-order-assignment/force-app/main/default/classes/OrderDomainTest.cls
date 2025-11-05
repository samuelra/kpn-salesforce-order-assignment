/**
 * @description Test class for OrderDomain. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class OrderDomainTest {
    
    @IsTest
    static void test_validateOrderCanBeModified_ok() {
        Order o = new Order(
            AccountId     = createAccount(),
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        insert o;
        
        // should NOT throw
        OrderDomain.validateOrderCanBeModified(o);
    }
    
    @IsTest
    static void test_validateOrderCanBeModified_null_throws() {
        try {
            OrderDomain.validateOrderCanBeModified(null);
            System.assert(false, 'Expected exception for null order');
        } catch (OrderManagementException ex) {
            System.assertEquals(
                OrderManagementConstants.ERROR_INVALID_ORDER,
            ex.getMessage()
                );
        }
    }
    
    @IsTest
    static void test_validateOrderCanBeModified_activated_throws() {
        // create a real order in DB
        Order o = new Order(
            AccountId     = createAccount(),
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        insert o;
        
        Order activatedMock = o.clone(false, false, false, false);
        activatedMock.Status = OrderManagementConstants.ORDER_STATUS_ACTIVATED;
        
        try {
            OrderDomain.validateOrderCanBeModified(activatedMock);
            System.assert(false, 'Expected exception for activated order');
        } catch (OrderManagementException ex) {
            System.assertEquals(
                OrderManagementConstants.ERROR_ORDER_ACTIVATED,
            ex.getMessage()
                );
        }
    }
    
    @IsTest
    static void test_activateOrder_single() {
        Order o = new Order(
            AccountId     = createAccount(),
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        insert o;
        
        OrderDomain.activateOrder(o);
        
        System.assertEquals(
            OrderManagementConstants.ORDER_STATUS_ACTIVATED,
        o.Status
            );
    }
    
    @IsTest
    static void test_activateOrders_bulk() {
        Order o1 = new Order(
            AccountId     = createAccount(),
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        Order o2 = new Order(
            AccountId     = createAccount(),
        Status        = 'Draft',
        EffectiveDate = Date.today(),
        Pricebook2Id  = Test.getStandardPricebookId()
            );
        insert new List<Order>{ o1, o2 };
        
        OrderDomain.activateOrders(new List<Order>{ o1, o2 });
        
        System.assertEquals(OrderManagementConstants.ORDER_STATUS_ACTIVATED, o1.Status);
        System.assertEquals(OrderManagementConstants.ORDER_STATUS_ACTIVATED, o2.Status);
    }
    
    // helper
    private static Id createAccount() {
        Account a = new Account(Name = 'OrderDomainTest Acc');
        insert a;
        return a.Id;
    }
}