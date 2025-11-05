/**
 * @description Domain logic for OrderItem records (create item, increment quantity, activate items).
 *               Keeps OrderItem-specific behavior in one place so services stay thin.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderItemDomain {
    
    /**
     * @description Create new order item
     * @param orderId The order ID
     * @param productId The product ID
     * @param quantity The quantity
     * @param unitPrice The unit price
     * @param pricebookEntryId The pricebook entry ID
     * @return New OrderItem
     */
    public static OrderItem createOrderItem(Id orderId, Id productId, Decimal quantity, Decimal unitPrice, Id pricebookEntryId) {
        OrderItem item = new OrderItem(
            OrderId = orderId,
        Product2Id = productId,
        Quantity = quantity,
        UnitPrice = unitPrice,
        PricebookEntryId = pricebookEntryId
            );
        return item;
    }
    
    /**
     * @description Increment order item quantity
     * @param item The order item
     * @param incrementBy Amount to increment by
     */
    public static void incrementQuantity(OrderItem item, Decimal incrementBy) {
        if (item != null) {
            item.Quantity = (item.Quantity != null ? item.Quantity : 0) + incrementBy;
        }
    }
    
    /**
     * @description Activate order item
     * @param item The order item
     */
    public static void activateOrderItem(OrderItem item) {
        // Set any activation-specific fields if needed
        // For now, status is controlled by parent Order
    }
    
    /**
     * @description Activate order items (bulkified)
     * @param items List of order items to activate
     */
    public static void activateOrderItems(List<OrderItem> items) {
        for (OrderItem item : items) {
            activateOrderItem(item);
        }
    }
}