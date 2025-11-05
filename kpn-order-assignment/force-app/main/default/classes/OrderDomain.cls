/**
 * @description Domain logic for OrderItem records (create item, increment quantity, activate items).
 *               Keeps OrderItem-specific behavior in one place so services stay thin.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderDomain {
    
    /**
     * @description Validate order can be modified
     * @param order The order record
     * @throws OrderManagementException if order cannot be modified
     */
    public static void validateOrderCanBeModified(Order order) {
        if (order == null) {
            throw new OrderManagementException(OrderManagementConstants.ERROR_INVALID_ORDER);
        }
        
        if (order.Status == OrderManagementConstants.ORDER_STATUS_ACTIVATED) {
            throw new OrderManagementException(OrderManagementConstants.ERROR_ORDER_ACTIVATED);
        }
    }
    
    /**
     * @description Activate order
     * @param order The order to activate
     */
    public static void activateOrder(Order order) {
        order.Status = OrderManagementConstants.ORDER_STATUS_ACTIVATED;
    }
    
    /**
     * @description Activate orders (bulkified)
     * @param orders List of orders to activate
     */
    public static void activateOrders(List<Order> orders) {
        for (Order order : orders) {
            activateOrder(order);
        }
    }
}