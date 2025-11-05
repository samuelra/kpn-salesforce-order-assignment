/**
 * @description Service layer for product availability inside Salesforce.
 *               Given an Order, it finds all products from the order's pricebook,
 *               marks which ones are already on the order, and returns UI-friendly wrappers.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class ProductService {
    
    /**
     * @description Get available products for an order's pricebook
     * @param orderId The order ID
     * @return List of ProductWrapper
     */
    public static List<ProductWrapper> getAvailableProductsForOrder(Id orderId) {
        // Get order with pricebook
        Order order = OrderSelector.getOrderWithDetails(orderId);
        
        if (order == null) {
            throw new OrderManagementException(OrderManagementConstants.ERROR_INVALID_ORDER);
        }
        
        if (order.Pricebook2Id == null) {
            throw new OrderManagementException(OrderManagementConstants.ERROR_NO_PRICEBOOK);
        }
        
        // Get products with pricebook entries (single SOQL with relationship)
        List<Product2> products = ProductSelector.getProductsWithPricebookEntries(order.Pricebook2Id);
        
        // Get existing order items to mark products already added
        List<OrderItem> existingItems = OrderItemSelector.getOrderItemsByOrderId(orderId);
        Set<Id> existingProductIds = new Set<Id>();
        for (OrderItem item : existingItems) {
            existingProductIds.add(item.Product2Id);
        }
        
        // Build wrappers
        List<ProductWrapper> wrappers = new List<ProductWrapper>();
        for (Product2 product : products) {
            if (!product.PricebookEntries.isEmpty()) {
                PricebookEntry pbe = product.PricebookEntries;
                wrappers.add(new ProductWrapper(
                    product.Id,
                product.Name,
                product.ProductCode,
                pbe.UnitPrice,
                existingProductIds.contains(product.Id),
                pbe.Id
                    ));
            }
        }
        
        // Sort: added products first, then by name
        wrappers.sort();
        
        return wrappers;
    }
    
    /**
     * @description Wrapper class for product data
     */
    public class ProductWrapper implements Comparable {
        @AuraEnabled public Id productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Decimal listPrice { get; set; }
        @AuraEnabled public Boolean isAddedToOrder { get; set; }
        @AuraEnabled public Id pricebookEntryId { get; set; }
        
        public ProductWrapper(Id productId, String productName, String productCode, Decimal listPrice, Boolean isAddedToOrder, Id pricebookEntryId) {
            this.productId = productId;
            this.productName = productName;
            this.productCode = productCode;
            this.listPrice = listPrice;
            this.isAddedToOrder = isAddedToOrder;
            this.pricebookEntryId = pricebookEntryId;
        }
        
        // Comparable implementation for sorting
        public Integer compareTo(Object compareTo) {
            ProductWrapper other = (ProductWrapper) compareTo;
            
            // Added products come first
            if (this.isAddedToOrder != other.isAddedToOrder) {
                return this.isAddedToOrder ? -1 : 1;
            }
            
            // Then sort by name
            if (this.productName == null) return 1;
            if (other.productName == null) return -1;
            return this.productName.compareTo(other.productName);
        }
    }
}