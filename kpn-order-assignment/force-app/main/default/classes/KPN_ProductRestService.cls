/**
 * @description REST resource exposing Salesforce products as a KPN-style Product API.
 *               Accepts query parameters (category, searchTerm, paging) and returns
 *               a JSON response compatible with the LWC + external consumer.
 * @endpoint /services/apexrest/products/v1/*
 * @author Samuel R
 * @since 2025-11
 */
@RestResource(urlMapping='/products/v1/*')
global with sharing class KPN_ProductRestService {
    
    /**
     * @description GET /products/v1/products - Get all products
     */
    @HttpGet
    global static void getAllProducts() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Extract query parameters
            String category = req.params.get('category');
            String searchTerm = req.params.get('searchTerm');
            String minPriceStr = req.params.get('minPrice');
            String maxPriceStr = req.params.get('maxPrice');
            String limitStr = req.params.get('limit');
            String offsetStr = req.params.get('offset');
            String sortBy = req.params.get('sortBy');
            String sortOrder = req.params.get('sortOrder');
            
            // Parse parameters with defaults
            Decimal minPrice = String.isNotBlank(minPriceStr) ? Decimal.valueOf(minPriceStr) : null;
            Decimal maxPrice = String.isNotBlank(maxPriceStr) ? Decimal.valueOf(maxPriceStr) : null;
            Integer limitValue = String.isNotBlank(limitStr) ? Integer.valueOf(limitStr) : 20;
            Integer offsetValue = String.isNotBlank(offsetStr) ? Integer.valueOf(offsetStr) : 0;
            
            // Get products from service
            KPN_ProductService.ProductListResponse response = KPN_ProductService.getProducts(
                category, searchTerm, minPrice, maxPrice, limitValue, offsetValue, sortBy, sortOrder
                );
            
            // Send successful response
            res.statusCode = 200;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            
        } catch (Exception e) {
            sendErrorResponse(res, 500, 'INTERNAL_ERROR', 'An unexpected error occurred: ' + e.getMessage());
        }
    }
    
    /**
     * @description Send error response
     */
    private static void sendErrorResponse(RestResponse res, Integer statusCode, String errorCode, String message) {
        res.statusCode = statusCode;
        res.addHeader('Content-Type', 'application/json');
        
        Map<String, Object> errorResponse = new Map<String, Object>{
            'success' => false,
            'error' => new Map<String, Object>{
                'code' => errorCode,
                'message' => message
            }
        };
        
        res.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
    }
}