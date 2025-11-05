/**
 * @description Internal service that powers the REST /products/v1 endpoint.
 *               Builds dynamic SOQL with filtering, sorting, and pagination and
 *               returns a structured response object.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class KPN_ProductService {
    
    /**
     * @description Get products with filters and pagination
     */
    public static ProductListResponse getProducts(
        String category,
    String searchTerm,
    Decimal minPrice,
    Decimal maxPrice,
    Integer limitValue,
    Integer offsetValue,
    String sortBy,
    String sortOrder
    ) {
        ProductListResponse response = new ProductListResponse();
        
        try {
            // Build dynamic SOQL query
            String query = 'SELECT Id, Name, ProductCode, Description, Family, IsActive FROM Product2 WHERE IsActive = true';
            
            // Add filters
            if (String.isNotBlank(category)) {
                query += ' AND Family = :category';
            }
            
            if (String.isNotBlank(searchTerm)) {
                query += ' AND (Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\' OR ProductCode LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\')';
            }
            
            // Add sorting
            if (String.isNotBlank(sortBy)) {
                String sortDirection = String.isNotBlank(sortOrder) ? sortOrder : 'ASC';
                query += ' ORDER BY ' + String.escapeSingleQuotes(sortBy) + ' ' + sortDirection;
            } else {
                query += ' ORDER BY Name ASC';
            }
            
            // Add pagination
            if (limitValue != null && limitValue > 0) {
                query += ' LIMIT ' + limitValue;
            }
            
            if (offsetValue != null && offsetValue > 0) {
                query += ' OFFSET ' + offsetValue;
            }
            
            // Execute query
            List<Product2> products = Database.query(query);
            
            // Get total count
            String countQuery = 'SELECT COUNT() FROM Product2 WHERE IsActive = true';
            if (String.isNotBlank(category)) {
                countQuery += ' AND Family = \'' + String.escapeSingleQuotes(category) + '\'';
            }
            Integer totalCount = Database.countQuery(countQuery);
            
            // Map to response
            List<ProductData> productDataList = new List<ProductData>();
            for (Product2 product : products) {
                ProductData pd = new ProductData();
                pd.productId = product.Id;
                pd.name = product.Name;
                pd.productCode = product.ProductCode;
                pd.description = product.Description;
                pd.category = product.Family;
                pd.price = getPriceForProduct(product.Id);
                pd.isActive = product.IsActive;
                productDataList.add(pd);
            }
            
            // Build response
            response.success = true;
            response.data = new ResponseData();
            response.data.products = productDataList;
            response.data.totalCount = totalCount;
            response.data.pageSize = limitValue != null ? limitValue : productDataList.size();
            response.data.currentPage = offsetValue != null ? (offsetValue / limitValue) + 1 : 1;
            
        } catch (Exception e) {
            response.success = false;
            response.error = new ErrorData();
            response.error.code = 'INTERNAL_ERROR';
            response.error.message = e.getMessage();
        }
        
        return response;
    }
    
    /**
     * @description Get price for a product from standard pricebook
     */
    private static Decimal getPriceForProduct(Id productId) {
        List<PricebookEntry> entries = [
            SELECT UnitPrice 
            FROM PricebookEntry 
            WHERE Product2Id = :productId 
            AND IsActive = true 
            AND Pricebook2.IsStandard = true 
            LIMIT 1
        ];
        
        return entries.isEmpty() ? 0 : entries[0].UnitPrice;
    }
    
    /**
     * @description Response wrapper classes
     */
    public class ProductListResponse {
        public Boolean success { get; set; }
        public ResponseData data { get; set; }
        public ErrorData error { get; set; }
        
        public ProductListResponse() {
            this.success = false;
        }
    }
    
    public class ResponseData {
        public List<ProductData> products { get; set; }
        public Integer totalCount { get; set; }
        public Integer pageSize { get; set; }
        public Integer currentPage { get; set; }
    }
    
    public class ProductData {
        public String productId { get; set; }
        public String name { get; set; }
        public String productCode { get; set; }
        public String description { get; set; }
        public String category { get; set; }
        public Decimal price { get; set; }
        public Boolean isActive { get; set; }
        public Map<String, Object> specifications { get; set; }
    }
    
    public class ErrorData {
        public String code { get; set; }
        public String message { get; set; }
    }
}