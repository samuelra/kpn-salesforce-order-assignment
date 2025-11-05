/**
 * @description LWC controller for the “Available Products” panel.
 *               Combines Salesforce pricebook products with external API products,
 *               and provides server actions to add/remove/update order items.
 *               Also creates SF Product/PricebookEntry for external items on the fly.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class AvailableProductsController {
    /**
     * @description Get combined products from Salesforce and External API
     */
    @AuraEnabled(cacheable=false)
    public static List<ExternalProductService.ProductWrapper> getCombinedProducts(
        Id orderId,
    Boolean includeExternal
    ) {
        List<ExternalProductService.ProductWrapper> allProducts = new List<ExternalProductService.ProductWrapper>();
        
        try {
            // Get Salesforce products
            List<ExternalProductService.ProductWrapper> sfProducts = getSalesforceProductsAsWrappers(orderId);
            allProducts.addAll(sfProducts);
            
            // Get external products if requested
            if (includeExternal) {
                List<ExternalProductService.ProductWrapper> externalProducts = ExternalProductService.getExternalProducts();
                allProducts.addAll(externalProducts);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error loading products: ' + e.getMessage());
        }
        
        return allProducts;
    }
    
    /**
     * @description Convert Salesforce products to wrapper format
     */
    @TestVisible
    private static List<ExternalProductService.ProductWrapper> getSalesforceProductsAsWrappers(Id orderId) {
        List<ExternalProductService.ProductWrapper> products = new List<ExternalProductService.ProductWrapper>();
        
        // Validate order
        if (orderId == null) {
            throw new AuraHandledException('Order ID is required');
        }
        
        Order order = getOrder(orderId);
        if (order == null) {
            throw new AuraHandledException('Order not found');
        }
        
        if (order.Pricebook2Id == null) {
            throw new AuraHandledException('Order must have a Pricebook associated');
        }
        
        // Get existing order items
        Set<Id> addedProductIds = getAddedProductIds(orderId);
        
        // Get available products from pricebook
        List<PricebookEntry> pricebookEntries = [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode, 
                   Product2.Description, Product2.Family, UnitPrice, IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :order.Pricebook2Id
            AND IsActive = true
            ORDER BY Product2.Name
        ];
        
        // Convert to wrapper format
        for (PricebookEntry entry : pricebookEntries) {
            ExternalProductService.ProductWrapper wrapper = new ExternalProductService.ProductWrapper();
            
            wrapper.productId = entry.Product2Id;
            wrapper.productName = entry.Product2.Name;
            wrapper.productCode = entry.Product2.ProductCode;
            wrapper.listPrice = entry.UnitPrice;
            wrapper.description = entry.Product2.Description;
            wrapper.category = entry.Product2.Family;
            wrapper.brand = null;
            wrapper.stock = null;
            wrapper.isExternal = false;
            wrapper.source = 'Salesforce';
            wrapper.isAddedToOrder = addedProductIds.contains(entry.Product2Id);
            wrapper.statusLabel = wrapper.isAddedToOrder ? '✓ Added' : 'Available';
            wrapper.statusClass = wrapper.isAddedToOrder ? 'slds-text-color_success' : '';
            wrapper.rowClass = wrapper.isAddedToOrder ? 'slds-hint-parent slds-is-selected' : '';
            wrapper.sourceBadge = 'SF';
            wrapper.sourceBadgeClass = 'slds-badge slds-theme_success';
            
            products.add(wrapper);
        }
        
        return products;
    }
    
    /**
     * @description Get order record with necessary fields
     */
    @TestVisible
    private static Order getOrder(Id orderId) {
        try {
            return [
                SELECT Id, OrderNumber, Pricebook2Id, Pricebook2.Name, 
                       AccountId, Status, EffectiveDate
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
        } catch (QueryException e) {
            return null;
        }
    }
    
    /**
     * @description Get order with pricebook or throw a clear error
     */
    @TestVisible
    private static Order getOrderWithPricebook(Id orderId) {
        Order ord = getOrder(orderId);
        if (ord == null) {
            throw new AuraHandledException('Order not found');
        }
        if (ord.Pricebook2Id == null) {
            throw new AuraHandledException('Order must have a Pricebook associated');
        }
        return ord;
    }
    
    /**
     * @description Get set of product IDs already added to order
     */
    @TestVisible
    private static Set<Id> getAddedProductIds(Id orderId) {
        Set<Id> productIds = new Set<Id>();
        
        List<OrderItem> orderItems = [
            SELECT Id, Product2Id
            FROM OrderItem
            WHERE OrderId = :orderId
        ];
        
        for (OrderItem item : orderItems) {
            productIds.add(item.Product2Id);
        }
        
        return productIds;
    }
    
    /**
     * @description Add SF product to order
     */
    @AuraEnabled
    public static ResultWrapper addProductToOrder(Id orderId, Id productId) {
        ResultWrapper result = new ResultWrapper();
        try {
            OrderService.OperationResult serviceResult = OrderService.addProductToOrder(orderId, productId);
            result.success = serviceResult.success;
            result.message = serviceResult.message;
            result.recordId = (serviceResult.recordId != null) ? (String) serviceResult.recordId : null;
        } catch (Exception e) {
            result.success = false;
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        return result;
    }
    
    
    /**
     * @description Add EXTERNAL product (from API) to order
     * LWC will pass the external product as JSON (the same shape you display)
     */
    @AuraEnabled
    public static ResultWrapper addExternalProductToOrder(Id orderId, String externalProductJson) {
        ResultWrapper result = new ResultWrapper();
        
        try {
            if (orderId == null) {
                result.success = false;
                result.message = 'Order ID is required';
                return result;
            }
            if (String.isBlank(externalProductJson)) {
                result.success = false;
                result.message = 'External product payload is required';
                return result;
            }
            
            // 1) deserialize
            Map<String, Object> extMap = (Map<String, Object>) JSON.deserializeUntyped(externalProductJson);
            
            // 2) load order + pricebook
            Order ord = getOrderWithPricebook(orderId);
            
            // 3) find or create Product2 based on productCode
            Product2 prod = findOrCreateProductFromExternal(extMap);
            
            // 4) ensure pricebook entry in order pricebook
            Decimal extPrice = (extMap.containsKey('listPrice') && extMap.get('listPrice') != null)
                ? Decimal.valueOf(String.valueOf(extMap.get('listPrice')))
                : null;
            String prodCurrency = (String) extMap.get('currency');
            
            PricebookEntry pbe = findOrCreatePbe(ord.Pricebook2Id, prod.Id, extPrice, prodCurrency);
            
            // 5) if the product is already on the order, bump quantity
            OrderItem existing = getOrderItemByOrderAndProduct(orderId, prod.Id);
            if (existing != null) {
                existing.Quantity = (existing.Quantity == null ? 0 : existing.Quantity) + 1;
                update existing;
                
                result.success = true;
                result.message = 'External product "' + prod.Name + '" quantity increased to ' + existing.Quantity;
                result.recordId = existing.Id;
                return result;
            }
            
            // otherwise create a new order item
            OrderItem oi = new OrderItem();
            oi.OrderId = ord.Id;
            oi.PricebookEntryId = pbe.Id;
            oi.Product2Id = prod.Id;
            oi.Quantity = 1;
            oi.UnitPrice = (extPrice != null) ? extPrice : pbe.UnitPrice;
            insert oi;
            
            result.success = true;
            result.message = 'External product "' + prod.Name + '" added successfully';
            result.recordId = oi.Id;
            return result;
            
        } catch (Exception e) {
            result.success = false;
            result.message = 'Error adding external product: ' + e.getMessage();
            return result;
        }
    }
    
    /**
     * @description Find existing product by ProductCode, otherwise create a minimal one
     */
    @TestVisible
    private static Product2 findOrCreateProductFromExternal(Map<String, Object> extMap) {
        String productCode = (String) extMap.get('productCode');
        String productName = (String) extMap.get('productName');
        String category = (String) extMap.get('category');
        
        Product2 existing = null;
        if (!String.isBlank(productCode)) {
            List<Product2> found = [
                SELECT Id, Name, ProductCode
                FROM Product2
                WHERE ProductCode = :productCode
                LIMIT 1
            ];
            if (!found.isEmpty()) {
                existing = found[0];
            }
        }
        if (existing != null) {
            return existing;
        }
        
        Product2 p = new Product2();
        p.Name = !String.isBlank(productName) ? productName : 'External Product';
        p.ProductCode = productCode;
        p.IsActive = true;
        if (!String.isBlank(category)) {
            p.Family = category;
        }
        insert p;
        return p;
    }
    
    /**
     * @description make sure there is a PricebookEntry for this product in the given pricebook
     */
    @TestVisible
    private static PricebookEntry findOrCreatePbe(
        Id pricebook2Id,
    Id product2Id,
    Decimal externalPrice,
    String currencyIsoCode
    ) {
        // 0) normalise price
        Decimal finalPrice = (externalPrice != null) ? externalPrice : 0;
        
        // 1) get Standard Price Book
        Id stdPbId = Test.isRunningTest()
            ? Test.getStandardPricebookId()
            : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
        
        Pricebook2 stdPb = new Pricebook2(Id = stdPbId);
        
        
        // 2) ensure Standard PBE exists
        List<PricebookEntry> stdExisting = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :stdPb.Id
            AND Product2Id = :product2Id
            LIMIT 1
        ];
        
        if (stdExisting.isEmpty()) {
            PricebookEntry stdPbe = new PricebookEntry();
            stdPbe.Pricebook2Id = stdPb.Id;
            stdPbe.Product2Id = product2Id;
            stdPbe.UnitPrice = finalPrice;
            stdPbe.IsActive = true;
            insert stdPbe;
        }
        
        // 3) now ensure the PBE in the order's (custom) pricebook
        List<PricebookEntry> existing = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebook2Id
            AND Product2Id = :product2Id
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0];
        }
        
        PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = pricebook2Id;
        pbe.Product2Id = product2Id;
        pbe.UnitPrice = finalPrice;
        pbe.IsActive = true;
        insert pbe;
        return pbe;
    }
    
    /**
     * @description Get order item by order and product
     */
    @TestVisible
    private static OrderItem getOrderItemByOrderAndProduct(Id orderId, Id productId) {
        if (orderId == null || productId == null) {
            return null;
        }
        
        List<OrderItem> items = [
            SELECT Id, Quantity, UnitPrice, TotalPrice
            FROM OrderItem
            WHERE OrderId = :orderId
            AND Product2Id = :productId
            LIMIT 1
        ];
        
        return items.isEmpty() ? null : items.get(0);
    }
    
    /**
     * @description Remove product from order
     */
    @AuraEnabled
    public static ResultWrapper removeProductFromOrder(Id orderItemId) {
        ResultWrapper result = new ResultWrapper();
        
        try {
            if (orderItemId == null) {
                result.success = false;
                result.message = 'Order Item ID is required';
                return result;
            }
            
            OrderItem item = [
                SELECT Id, Product2.Name
                FROM OrderItem
                WHERE Id = :orderItemId
                LIMIT 1
            ];
            
            String productName = item.Product2.Name;
            delete item;
            
            result.success = true;
            result.message = 'Product "' + productName + '" removed successfully';
            
        } catch (DmlException e) {
            result.success = false;
            result.message = 'Error removing product: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            result.success = false;
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * @description Update order item quantity
     */
    @AuraEnabled
    public static ResultWrapper updateOrderItemQuantity(Id orderItemId, Decimal quantity) {
        ResultWrapper result = new ResultWrapper();
        
        try {
            if (orderItemId == null) {
                result.success = false;
                result.message = 'Order Item ID is required';
                return result;
            }
            
            if (quantity == null || quantity <= 0) {
                result.success = false;
                result.message = 'Quantity must be greater than 0';
                return result;
            }
            
            OrderItem item = [
                SELECT Id, Quantity, Product2.Name
                FROM OrderItem
                WHERE Id = :orderItemId
                LIMIT 1
            ];
            
            item.Quantity = quantity;
            update item;
            
            result.success = true;
            result.message = 'Quantity updated successfully';
            
        } catch (DmlException e) {
            result.success = false;
            result.message = 'Error updating quantity: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            result.success = false;
            result.message = 'Unexpected error: ' + e.getMessage();
        }
        
        return result;
    }
    
    /**
     * @description Get all order items for an order
     */
    @AuraEnabled(cacheable=false)
    public static List<OrderItem> getOrderItems(Id orderId) {
        if (orderId == null) {
            return new List<OrderItem>();
        }
        
        return [
            SELECT Id, Product2Id, Product2.Name, Product2.ProductCode,
                   Quantity, UnitPrice, TotalPrice, Description
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY Product2.Name
        ];
    }
    
    /**
     * @description Result wrapper class
     */
    public class ResultWrapper {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String recordId { get; set; }
        
        public ResultWrapper() {
            this.success = false;
            this.message = '';
            this.recordId = null;
        }
    }
}