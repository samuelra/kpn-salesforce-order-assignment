/**
 * @description Selector for Order records. Provides safe, reusable query methods
 *               to fetch Orders with the fields needed by services/domains.
 * @author Samuel R
 * @since 2025-11
 */

public with sharing class OrderSelector {
    
    /**
     * @description Get order with related data
     * @param orderId The order ID
     * @return Order record with related data
     */
    public static Order getOrderWithDetails(Id orderId) {
        if (orderId == null) {
            return null;
        }
        
        List<Order> orders = [
            SELECT Id, Status, Pricebook2Id, AccountId, EffectiveDate,
                   Account.Name, Pricebook2.Name
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        return orders.isEmpty() ? null : orders[0];
    }
    
    /**
     * @description Get orders by IDs
     * @param orderIds Set of order IDs
     * @return Map of Order by Id
     */
    public static Map<Id, Order> getOrdersByIds(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) {
            return new Map<Id, Order>();
        }
        
        return new Map<Id, Order>([
            SELECT Id, Status, Pricebook2Id
            FROM Order
            WHERE Id IN :orderIds
        ]);
    }
}