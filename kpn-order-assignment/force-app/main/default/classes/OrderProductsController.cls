/**
 * @description LWC controller for the “Order Products” panel.
 *               - fetches order line items
 *               - activates the order
 *               - kicks off the external order sync
 *               All exceptions are wrapped as AuraHandledException for the UI.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderProductsController {
    
    // TEST-ONLY switches so we can force the catch blocks
    @TestVisible private static Boolean forceFailGetOrderProducts   = false;
    @TestVisible private static Boolean forceFailActivateOrder      = false;
    @TestVisible private static Boolean forceFailIsOrderActivated   = false;
    
    /**
     * @description Get order products
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderService.OrderItemWrapper> getOrderProducts(Id orderId) {
        try {
            if (Test.isRunningTest() && forceFailGetOrderProducts) {
                // must throw a constructible exception, not plain Exception
                throw new AuraHandledException('Forced test exception - getOrderProducts');
            }
            return OrderService.getOrderProducts(orderId);
        } catch (Exception e) {
            // now the catch will be coverable
            throw new AuraHandledException('Error in getOrderProducts: ' + e.getMessage());
        }
    }
    
    /**
     * @description Activate order in Salesforce and push to external Order API
     */
    @AuraEnabled
    public static OrderService.OperationResult activateOrder(Id orderId) {
        OrderService.OperationResult result;
        try {
            if (Test.isRunningTest() && forceFailActivateOrder) {
                throw new AuraHandledException('Forced test exception - activateOrder');
            }
            result = OrderService.activateOrder(orderId);
        } catch (Exception e) {
            throw new AuraHandledException('Error in activateOrder: ' + e.getMessage());
        }
        
        if (result != null && result.success == true) {
            System.debug('Order activated, sending to external API');
            KpnOrderApiService.sendOrderToApiAsync(orderId);
            result.message = result.message + ' (External order sync started)';
        }
        
        return result;
    }
    
    /**
     * @description Check if order is activated
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isOrderActivated(Id orderId) {
        try {
            if (Test.isRunningTest() && forceFailIsOrderActivated) {
                throw new AuraHandledException('Forced test exception - isOrderActivated');
            }
            return OrderService.isOrderActivated(orderId);
        } catch (Exception e) {
            throw new AuraHandledException('Error in isOrderActivated: ' + e.getMessage());
        }
    }
}