/**
 * @description Selector for OrderItem records. Supports fetch-by-order,
 *               fetch-by-multiple-orders, and fetch-by-order+product.
 *               Keeps SOQL in one place for easier maintenance.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderItemSelector {
    
    /**
     * @description Get order items for an order
     * @param orderId The order ID
     * @return List of OrderItems with product details
     */
    public static List<OrderItem> getOrderItemsByOrderId(Id orderId) {
        if (orderId == null) {
            return new List<OrderItem>();
        }
        
        return [
            SELECT Id, OrderId, Product2Id, Quantity, UnitPrice, TotalPrice,
                   Product2.Name, Product2.ProductCode, ServiceDate, 
                   Description, ListPrice
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY Product2.Name ASC
        ];
    }
    
    /**
     * @description Get order items by order IDs (bulkified)
     * @param orderIds Set of order IDs
     * @return Map of OrderId to List of OrderItems
     */
    public static Map<Id, List<OrderItem>> getOrderItemsByOrderIds(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return new Map<Id, List<OrderItem>>();
        }
        
        Map<Id, List<OrderItem>> orderItemsMap = new Map<Id, List<OrderItem>>();
        
        for (OrderItem item : [
            SELECT Id, OrderId, Product2Id, Quantity, UnitPrice, TotalPrice,
                   Product2.Name, Product2.ProductCode
            FROM OrderItem
            WHERE OrderId IN :orderIds
            ORDER BY Product2.Name ASC
        ]) {
            if (!orderItemsMap.containsKey(item.OrderId)) {
                orderItemsMap.put(item.OrderId, new List<OrderItem>());
            }
            orderItemsMap.get(item.OrderId).add(item);
        }
        
        return orderItemsMap;
    }
    
    /**
     * @description Get order item by order and product
     * @param orderId The order ID
     * @param productId The product ID
     * @return OrderItem if exists, null otherwise
     */
    public static OrderItem getOrderItemByOrderAndProduct(Id orderId, Id productId) {
        if (orderId == null || productId == null) {
            return null;
        }
        
        try {
            return [
                SELECT Id, Quantity, UnitPrice, TotalPrice
                FROM OrderItem
                WHERE OrderId = :orderId
                AND Product2Id = :productId
                LIMIT 1
            ];
        } catch (QueryException e) {
            return null;
        }
    }
}