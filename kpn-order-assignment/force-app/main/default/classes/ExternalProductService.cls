/**
 * @description Service to call the external KPN Product API (via Named Credential) and
 *               normalize the response into a common ProductWrapper shape used by LWC.
 *               Handles field-name variations and callout errors gracefully.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class ExternalProductService {
    
    private static final String API_ENDPOINT = 'callout:KPN_Product_API/v1/products';
    
    
    public static List<ProductWrapper> getExternalProducts() {
        List<ProductWrapper> products = new List<ProductWrapper>();
        
        try {
            HttpRequest req = new HttpRequest();
            // keep your named credential, but with /v1/products as we said earlier
            req.setEndpoint(API_ENDPOINT);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Accept', 'application/json');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('HTTP Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                // top-level object
                Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                // success flag (optional)
                Boolean ok = root.containsKey('success') ? (Boolean) root.get('success') : true;
                if (ok) {
                    // this is the important part: data is a LIST in your response
                    Object dataObj = root.get('data');
                    if (dataObj instanceof List<Object>) {
                        List<Object> dataList = (List<Object>) dataObj;
                        for (Object o : dataList) {
                            Map<String, Object> productData = (Map<String, Object>) o;
                            products.add(mapExternalProduct(productData));
                        }
                    } else if (dataObj instanceof Map<String, Object>) {
                        // just in case the API ever returns an object
                        Map<String, Object> productData = (Map<String, Object>) dataObj;
                        products.add(mapExternalProduct(productData));
                    }
                } else {
                    System.debug('API returned success = false');
                }
                
                // optional: read pagination if you need it
                if (root.containsKey('pagination')) {
                    Map<String, Object> pagination = (Map<String, Object>) root.get('pagination');
                    System.debug('Pagination: ' + pagination);
                }
                
                System.debug('Products fetched successfully: ' + products.size());
                
            } else if (res.getStatusCode() == 401) {
                System.debug('Authentication failed - check Named Credential');
            } else if (res.getStatusCode() == 404) {
                System.debug('API endpoint not found - verify URL');
            } else {
                System.debug('API Error: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
        } catch (System.CalloutException e) {
            System.debug('Callout Exception: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        } catch (Exception e) {
            System.debug('Exception fetching external products: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }
        
        return products;
    }
    
    /**
     * @description Map external API product to common wrapper format
     * Handles various field name variations from different APIs
     */
    private static ProductWrapper mapExternalProduct(Map<String, Object> productData) {
        ProductWrapper wrapper = new ProductWrapper();
        
        try {
            // Map ID fields (try common variations)
            wrapper.productId = getStringValue(productData, new List<String>{'id', 'productId', 'product_id', 'ID'});
            
            // Map Name fields
            wrapper.productName = getStringValue(productData, new List<String>{'name', 'productName', 'product_name', 'title'});
            
            // Map Code fields
            wrapper.productCode = getStringValue(productData, new List<String>{'code', 'productCode', 'product_code', 'sku', 'SKU'});
            
            // Map Description fields
            wrapper.description = getStringValue(productData, new List<String>{'description', 'desc', 'details'});
            
            // Map Category fields
            wrapper.category = getStringValue(productData, new List<String>{'category', 'family', 'type', 'productType'});
            
            // Map Brand fields
            wrapper.brand = getStringValue(productData, new List<String>{'brand', 'manufacturer', 'vendor'});
            
            // Map Price fields
            Object priceObj = getFieldValue(productData, new List<String>{'price', 'listPrice', 'unitPrice', 'cost'});
            if (priceObj != null) {
                wrapper.listPrice = Decimal.valueOf(String.valueOf(priceObj));
            }
            
            // Map Stock fields
            Object stockObj = getFieldValue(productData, new List<String>{'stock', 'quantity', 'inventory', 'availableQuantity'});
            if (stockObj != null) {
                wrapper.stock = Integer.valueOf(String.valueOf(stockObj));
            }
            
            // Handle nested specifications
            if (productData.containsKey('specifications')) {
                Map<String, Object> specs = (Map<String, Object>) productData.get('specifications');
                if (specs != null && wrapper.brand == null) {
                    wrapper.brand = (String) specs.get('brand');
                }
            }
            
            // Set wrapper metadata
            wrapper.isExternal = true;
            wrapper.source = 'KPN Product API';
            wrapper.isAddedToOrder = false;
            wrapper.statusLabel = 'Available';
            wrapper.statusClass = 'slds-text-color_success';
            wrapper.rowClass = '';
            wrapper.sourceBadge = 'External';
            wrapper.sourceBadgeClass = 'slds-badge slds-theme_info';
            
        } catch (Exception e) {
            System.debug('Error mapping product: ' + e.getMessage());
            System.debug('Product Data: ' + JSON.serialize(productData));
        }
        
        return wrapper;
    }
    
    /**
     * @description Get string value from multiple possible field names
     */
    private static String getStringValue(Map<String, Object> data, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            if (data.containsKey(fieldName)) {
                Object value = data.get(fieldName);
                if (value != null) {
                    return String.valueOf(value);
                }
            }
        }
        return null;
    }
    
    /**
     * @description Get field value from multiple possible field names
     */
    private static Object getFieldValue(Map<String, Object> data, List<String> fieldNames) {
        for (String fieldName : fieldNames) {
            if (data.containsKey(fieldName)) {
                return data.get(fieldName);
            }
        }
        return null;
    }
    
    /**
     * @description Common product wrapper for both SF and external products
     */
    public class ProductWrapper {
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public Decimal listPrice { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String category { get; set; }
        @AuraEnabled public String brand { get; set; }
        @AuraEnabled public Integer stock { get; set; }
        @AuraEnabled public Boolean isExternal { get; set; }
        @AuraEnabled public String source { get; set; }
        @AuraEnabled public Boolean isAddedToOrder { get; set; }
        @AuraEnabled public String statusLabel { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public String rowClass { get; set; }
        @AuraEnabled public String sourceBadge { get; set; }
        @AuraEnabled public String sourceBadgeClass { get; set; }
    }
}