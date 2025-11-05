/**
 * @description Test class for AvailableProductsController. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Your Name
 * @since 2025-11
 */
@isTest
public class AvailableProductsControllerTest {
    
    @isTest
    static void testGetCombinedProducts() {
        // Prepare test data
        Id orderId = createTestOrder();
        // Add a product to the order
        Id productId = createTestProduct();
        addProductToOrderAndReturnItemId(orderId, productId); // Ensure there's at least one product added
        
        Boolean includeExternal = true;
        
        // Call the method
        Test.startTest();
        List<ExternalProductService.ProductWrapper> combinedProducts = AvailableProductsController.getCombinedProducts(orderId, includeExternal);
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, combinedProducts, 'The combined products list should not be null');
        System.assert(!combinedProducts.isEmpty(), 'The combined products list should not be empty');
    }
    
    @isTest
    static void testAddProductToOrder() {
        // Prepare test data
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        
        // Call the method
        Test.startTest();
        AvailableProductsController.ResultWrapper result = AvailableProductsController.addProductToOrder(orderId, productId);
        Test.stopTest();
        
        // Assertions
        System.assert(result.success, 'The product should be added successfully');
        System.assertNotEquals(null, result.recordId, 'The recordId should not be null after adding a product');
    }
    
    @isTest
    static void testRemoveProductFromOrder() {
        // Prepare test data
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        Id orderItemId = addProductToOrderAndReturnItemId(orderId, productId);
        
        // Call the method
        Test.startTest();
        AvailableProductsController.ResultWrapper result = AvailableProductsController.removeProductFromOrder(orderItemId);
        Test.stopTest();
        
        // Assertions
        System.assert(result.success, 'The product should be removed successfully');
        System.assertEquals('Product "' + getProductNameById(productId) + '" removed successfully', result.message, 'The message should confirm removal');
    }
    
    @isTest
    static void testUpdateOrderItemQuantity() {
        // Prepare test data
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        Id orderItemId = addProductToOrderAndReturnItemId(orderId, productId);
        
        // Call the method
        Test.startTest();
        AvailableProductsController.ResultWrapper result = AvailableProductsController.updateOrderItemQuantity(orderItemId, 5);
        Test.stopTest();
        
        // Assertions
        System.assert(result.success, 'The quantity should be updated successfully');
        System.assertEquals('Quantity updated successfully', result.message, 'The message should confirm the update');
        
        // Verify the update
        OrderItem updatedItem = [SELECT Quantity FROM OrderItem WHERE Id = :orderItemId];
        System.assertEquals(5, updatedItem.Quantity, 'The quantity should be updated to 5');
    }
    
    // Helper methods to create test data
    static Id createTestOrder() {
        // Create an Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Use the standard pricebook
        Id standardPricebookId = Test.getStandardPricebookId(); // Fetch the standard pricebook ID
        
        // Create a test Order
        Order testOrder = new Order(
            AccountId = testAccount.Id,
        Pricebook2Id = standardPricebookId, // Use standard pricebook ID
        Status = 'Draft',
        EffectiveDate = Date.today()
            );
        insert testOrder;
        
        return testOrder.Id;
    }
    
    static Id createTestProduct() {
        // Create a Product2 and return its Id
        Product2 testProduct = new Product2(
            Name = 'Test Product',
        ProductCode = 'TP-001',
        IsActive = true
            );
        insert testProduct;
        
        // Create a PricebookEntry for the product in the standard pricebook
        PricebookEntry testPBE = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), // Use the standard pricebook ID directly
        Product2Id = testProduct.Id,
        UnitPrice = 100,
        IsActive = true
            );
        insert testPBE;
        
        return testProduct.Id;
    }
    
    static Id addProductToOrderAndReturnItemId(Id orderId, Id productId) {
        // Logic to add the product to an Order and return the OrderItem Id
        PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :productId LIMIT 1];
        OrderItem orderItem = new OrderItem(
            OrderId = orderId,
        PricebookEntryId = pbe.Id,
        Product2Id = productId,
        Quantity = 1,
        UnitPrice = pbe.UnitPrice
            );
        insert orderItem;
        return orderItem.Id;
    }
    
    public static String getProductNameById(Id productId) {
        // Ensure the product ID is not null
        if (productId == null) {
            return null; // or throw an exception if you prefer
        }
        
        // Query the Product2 object to get the product name
        Product2 product = [SELECT Name FROM Product2 WHERE Id = :productId LIMIT 1];
        
        // Return the product name
        return product.Name;
    }
    
    @isTest
    static void testGetCombinedProducts_salesforceOnly() {
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        addProductToOrderAndReturnItemId(orderId, productId);
        
        Test.startTest();
        List<ExternalProductService.ProductWrapper> combinedProducts =
            AvailableProductsController.getCombinedProducts(orderId, false);
        Test.stopTest();
        
        System.assert(!combinedProducts.isEmpty(), 'Should still return SF products even without external');
        System.assertEquals('Salesforce', combinedProducts[0].source, 'First source should be SF');
    }
    
    @isTest
    static void testGetOrderItems_returnsItems() {
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        addProductToOrderAndReturnItemId(orderId, productId);
        
        Test.startTest();
        List<OrderItem> items = AvailableProductsController.getOrderItems(orderId);
        Test.stopTest();
        
        System.assertEquals(1, items.size(), 'Should get back the item we just inserted');
        System.assertEquals(productId, items[0].Product2Id);
    }
    
    @isTest
    static void testAddExternalProductToOrder_createsProductAndOrderItem() {
        Id orderId = createTestOrder();
        
        // this mimics what your LWC sends
        Map<String, Object> ext = new Map<String, Object>{
            'productId'   => null,
            'productName' => 'KPN Unlimited Mobile',
            'productCode' => 'KPN-MOB-UNL-001',
            'category'    => 'Mobile',
            'listPrice'   => 27.50,
            'isExternal'  => true,
            'source'      => 'Product API'
        };
        String payload = JSON.serialize(ext);
        
        Test.startTest();
        AvailableProductsController.ResultWrapper rw =
            AvailableProductsController.addExternalProductToOrder(orderId, payload);
        Test.stopTest();
        
        System.assertEquals(true, rw.success, 'External product should be added');
        System.assertNotEquals(null, rw.recordId, 'OrderItem Id should be returned');
        
        // and the order item should really exist
        OrderItem oi = [SELECT Id, Quantity, UnitPrice FROM OrderItem WHERE Id = :rw.recordId];
        System.assertEquals(1, oi.Quantity, 'External product should start with qty 1');
    }
    
    @isTest
    static void testGetCombinedProducts_missingOrder_throws() {
        try {
            Test.startTest();
            // pass null on purpose
            AvailableProductsController.getCombinedProducts(null, true);
            Test.stopTest();
            
            // if we got here, it didn't throw — fail the test
            System.assert(false, 'Expected AuraHandledException when orderId is null');
        } catch (AuraHandledException e) {
            // this is what the controller actually throws
        }
    }
    
    
    @isTest
    static void testUpdateOrderItemQuantity_invalidQuantity() {
        Id orderId = createTestOrder();
        Id productId = createTestProduct();
        Id orderItemId = addProductToOrderAndReturnItemId(orderId, productId);
        
        Test.startTest();
        AvailableProductsController.ResultWrapper rw =
            AvailableProductsController.updateOrderItemQuantity(orderItemId, 0);
        Test.stopTest();
        
        System.assertEquals(false, rw.success, 'Should fail for quantity 0');
        System.assert(rw.message.contains('greater than 0'));
    }
    
    // optional tiny helper for external tests
    private static String buildExternalProductJson(String code, Decimal price) {
        Map<String, Object> m = new Map<String, Object>{
            'productName' => 'External ' + code,
            'productCode' => code,
            'category'    => 'Mobile',
            'listPrice'   => price,
            'isExternal'  => true
        };
        return JSON.serialize(m);
    }
    
    @isTest
    static void testAddExternalProductToOrder_missingOrderId() {
        String payload = JSON.serialize(new Map<String, Object>{
            'productName' => 'External Product',
            'productCode' => 'EXT-001',
            'listPrice'   => 10
        });
        Test.startTest();
        AvailableProductsController.ResultWrapper result =
            AvailableProductsController.addExternalProductToOrder(null, payload);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail if orderId is null');
        System.assert(result.message.contains('Order ID is required'));
    }
    
    @isTest
    static void testAddExternalProductToOrder_blankPayload() {
        Id orderId = createTestOrder();
        Test.startTest();
        AvailableProductsController.ResultWrapper result =
            AvailableProductsController.addExternalProductToOrder(orderId, '');
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail if payload is blank');
        System.assert(result.message.contains('External product payload is required'));
    }
    
    @isTest
    static void testRemoveProductFromOrder_nullId() {
        Test.startTest();
        AvailableProductsController.ResultWrapper result =
            AvailableProductsController.removeProductFromOrder(null);
        Test.stopTest();
        
        System.assertEquals(false, result.success, 'Should fail if orderItemId is null');
        System.assert(result.message.contains('Order Item ID is required'));
    }
}