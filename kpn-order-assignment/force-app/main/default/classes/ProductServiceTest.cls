/**
 * @description Test class for ProductService. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@IsTest
private class ProductServiceTest {
    
    @IsTest
    static void testGetAvailableProductsForOrder_happyPath() {
        // 1) setup account
        Account acc = new Account(Name = 'Test Customer');
        insert acc;
        
        // 2) standard pricebook
        Id stdPbId = Test.getStandardPricebookId();
        
        // 3) create 2 products
        Product2 p1 = new Product2(Name = 'KPN Mobile Unlimited', ProductCode = 'KPN-MOB-UNL', IsActive = true);
        Product2 p2 = new Product2(Name = 'KPN Fiber 1Gbps', ProductCode = 'KPN-FIB-1G', IsActive = true);
        insert new List<Product2>{ p1, p2 };
        
        // 4) PBEs
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
        
        // 5) create order using that pricebook
        Order ord = new Order(
            AccountId    = acc.Id,
        Pricebook2Id = stdPbId,
        Status       = 'Draft',
        EffectiveDate= Date.today()
            );
        insert ord;
        
        // 6) add ONE order item so we can test "isAddedToOrder"
        OrderItem oi = new OrderItem(
            OrderId         = ord.Id,
        PricebookEntryId= pbe1.Id,
        Product2Id      = p1.Id,
        Quantity        = 1,
        UnitPrice       = 25
            );
        insert oi;
        
        // act
        Test.startTest();
        List<ProductService.ProductWrapper> wrappers =
            ProductService.getAvailableProductsForOrder(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, wrappers, 'Should return a list');
        System.assertEquals(2, wrappers.size(), 'We created 2 products, so we should get 2');
        
        // because of the Comparable, the one already on the order should come first
        ProductService.ProductWrapper first = wrappers[0];
        System.assertEquals(p1.Id, first.productId, 'Product already on the order should come first');
        System.assertEquals(true, first.isAddedToOrder, 'First product should be marked as added');
        
        // second should be the other product
        ProductService.ProductWrapper second = wrappers[1];
        System.assertEquals(p2.Id, second.productId);
        System.assertEquals(false, second.isAddedToOrder);
    }
    
    @IsTest
    static void testGetAvailableProductsForOrder_orderWithoutPricebook_throws() {
        // order with no pricebook
        Account acc = new Account(Name = 'Test Customer 2');
        insert acc;
        
        Order ord = new Order(
            AccountId     = acc.Id,
        Status        = 'Draft',
        EffectiveDate = Date.today()
            );
        insert ord;
        
        Boolean thrown = false;
        try {
            ProductService.getAvailableProductsForOrder(ord.Id);
        } catch (OrderManagementException e) {
            thrown = true;
            System.assertEquals(
                OrderManagementConstants.ERROR_NO_PRICEBOOK,
            e.getMessage(),
            'Should complain about missing pricebook'
                );
        }
        System.assert(thrown, 'We should have thrown an exception');
    }
    
    @IsTest
    static void testGetAvailableProductsForOrder_invalidOrder_throws() {
        Boolean thrown = false;
        try {
            ProductService.getAvailableProductsForOrder(null);
        } catch (OrderManagementException e) {
            thrown = true;
            System.assertEquals(
                OrderManagementConstants.ERROR_INVALID_ORDER,
            e.getMessage(),
            'Should complain about invalid order'
                );
        }
        System.assert(thrown, 'We should have thrown for null order id');
    }
}