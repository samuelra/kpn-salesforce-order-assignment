/**
 * @description Core business service for Orders. Orchestrates selectors, domains,
 *               and DML to 1) get order products, 2) add products, and 3) activate orders.
 *               Returns simple wrapper objects for LWC consumption.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderService {
    
    /**
     * @description Get order products
     * @param orderId The order ID
     * @return List of OrderItemWrapper
     */
    public static List<OrderItemWrapper> getOrderProducts(Id orderId) {
        List<OrderItem> items = OrderItemSelector.getOrderItemsByOrderId(orderId);
        
        List<OrderItemWrapper> wrappers = new List<OrderItemWrapper>();
        for (OrderItem item : items) {
            wrappers.add(new OrderItemWrapper(item));
        }
        
        return wrappers;
    }
    
    /**
     * @description Add product to order
     * @param orderId The order ID
     * @param productId The product ID
     * @return Result wrapper
     */
    public static OperationResult addProductToOrder(Id orderId, Id productId) {
        try {
            // Validate order
            Order order = OrderSelector.getOrderWithDetails(orderId);
            OrderDomain.validateOrderCanBeModified(order);
            
            // Check if product already exists in order
            OrderItem existingItem = OrderItemSelector.getOrderItemByOrderAndProduct(orderId, productId);
            
            if (existingItem != null) {
                // Increment quantity
                OrderItemDomain.incrementQuantity(existingItem, 1);
                update existingItem;
                
                return new OperationResult(true, 'Product quantity increased', existingItem.Id);
            } else {
                // Get product with pricebook entry
                Map<Id, Product2> productsMap = ProductSelector.getProductsByIdsWithPricebookEntries(
                new Set<Id>{ productId },
                order.Pricebook2Id
                    );
                
                if (productsMap.isEmpty() || !productsMap.containsKey(productId)) {
                    return new OperationResult(false, OrderManagementConstants.ERROR_INVALID_PRODUCT, null);
                }
                
                Product2 product = productsMap.get(productId);
                if (product.PricebookEntries.isEmpty()) {
                    return new OperationResult(false, OrderManagementConstants.ERROR_INVALID_PRODUCT, null);
                }
                
                PricebookEntry pbe = product.PricebookEntries;
                
                // Create new order item
                OrderItem newItem = OrderItemDomain.createOrderItem(
                    orderId,
                productId,
                1,
                pbe.UnitPrice,
                pbe.Id
                    );
                
                insert newItem;
                
                return new OperationResult(true, 'Product added to order', newItem.Id);
            }
        } catch (Exception e) {
            return new OperationResult(false, e.getMessage(), null);
        }
    }
    
    /**
     * @description Activate order and order items
     * @param orderId The order ID
     * @return Result wrapper
     */
    public static OperationResult activateOrder(Id orderId) {
        try {
            // Get order
            Order order = OrderSelector.getOrderWithDetails(orderId);
            
            if (order == null) {
                return new OperationResult(false, OrderManagementConstants.ERROR_INVALID_ORDER, null);
            }
            
            // Validate order can be modified
            if (order.Status == OrderManagementConstants.ORDER_STATUS_ACTIVATED) {
                return new OperationResult(false, OrderManagementConstants.ERROR_ORDER_ACTIVATED, null);
            }
            
            // Get order items
            List<OrderItem> orderItems = OrderItemSelector.getOrderItemsByOrderId(orderId);
            
            if (orderItems.isEmpty()) {
                return new OperationResult(false, 'Cannot activate order without products', null);
            }
            
            // Activate order
            OrderDomain.activateOrder(order);
            update order;
            
            // Activate order items
            OrderItemDomain.activateOrderItems(orderItems);
            update orderItems;
            
            return new OperationResult(true, 'Order activated successfully', orderId);
        } catch (Exception e) {
            return new OperationResult(false, e.getMessage(), null);
        }
    }
    
    /**
     * @description Check if order is activated
     * @param orderId The order ID
     * @return Boolean indicating if order is activated
     */
    public static Boolean isOrderActivated(Id orderId) {
        Order order = OrderSelector.getOrderWithDetails(orderId);
        return order != null && order.Status == OrderManagementConstants.ORDER_STATUS_ACTIVATED;
    }
    
    /**
     * @description Wrapper class for order item data
     */
    public class OrderItemWrapper {
        @AuraEnabled public Id orderItemId { get; set; }
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Decimal quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        
        public OrderItemWrapper(OrderItem item) {
            this.orderItemId = item.Id;
            this.productId = item.Product2Id;
            this.productName = item.Product2.Name;
            this.productCode = item.Product2.ProductCode;
            this.quantity = item.Quantity;
            this.unitPrice = item.UnitPrice;
            this.totalPrice = item.TotalPrice;
        }
    }
    
    /**
     * @description Wrapper class for operation results
     */
    public class OperationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id recordId { get; set; }
        
        public OperationResult(Boolean success, String message, Id recordId) {
            this.success = success;
            this.message = message;
            this.recordId = recordId;
        }
    }
}