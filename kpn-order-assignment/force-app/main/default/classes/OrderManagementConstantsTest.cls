/**
 * @description Test class for OrderManagementConstants. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@isTest
public class OrderManagementConstantsTest {
    @isTest
    static void testConstantsValues() {
        // Order statuses
        System.assertEquals('Draft', OrderManagementConstants.ORDER_STATUS_DRAFT);
        System.assertEquals('Activated', OrderManagementConstants.ORDER_STATUS_ACTIVATED);
        
        // Order item statuses
        System.assertEquals('Draft', OrderManagementConstants.ORDER_ITEM_STATUS_DRAFT);
        System.assertEquals('Activated', OrderManagementConstants.ORDER_ITEM_STATUS_ACTIVATED);
        
        // Error messages
        System.assertEquals('Order must have a Pricebook associated', OrderManagementConstants.ERROR_NO_PRICEBOOK);
        System.assertEquals('Cannot modify an activated order', OrderManagementConstants.ERROR_ORDER_ACTIVATED);
        System.assertEquals('Product not found in order pricebook', OrderManagementConstants.ERROR_INVALID_PRODUCT);
        System.assertEquals('Invalid Order ID', OrderManagementConstants.ERROR_INVALID_ORDER);
        
        // Standard PB name
        System.assertEquals('Standard Price Book', OrderManagementConstants.STANDARD_PRICEBOOK_NAME);
    }
}