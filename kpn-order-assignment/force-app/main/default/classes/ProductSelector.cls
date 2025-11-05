/**
 * @description Selector for Product2 records. Returns products together with their
 *               PricebookEntries for a given pricebook, and supports bulk map lookups.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class ProductSelector {
    
    /**
     * @description Get products with pricebook entries for a specific pricebook
     * @param pricebookId The pricebook ID
     * @return List of Product2 with PricebookEntries
     */
    public static List<Product2> getProductsWithPricebookEntries(Id pricebookId) {
        if (pricebookId == null) {
            return new List<Product2>();
        }
        
        return [
            SELECT Id, Name, ProductCode, Description, IsActive,
                   (SELECT Id, UnitPrice, IsActive, Pricebook2Id, UseStandardPrice
                    FROM PricebookEntries
                    WHERE Pricebook2Id = :pricebookId
                    AND IsActive = true)
            FROM Product2
            WHERE IsActive = true
            AND Id IN (SELECT Product2Id FROM PricebookEntry WHERE Pricebook2Id = :pricebookId AND IsActive = true)
            ORDER BY Name ASC
        ];
    }
    
    /**
     * @description Get products by IDs with pricebook entries
     * @param productIds Set of product IDs
     * @param pricebookId The pricebook ID
     * @return Map of Product2 by Id
     */
    public static Map<Id, Product2> getProductsByIdsWithPricebookEntries(Set<Id> productIds, Id pricebookId) {
        if (productIds == null || productIds.isEmpty() || pricebookId == null) {
            return new Map<Id, Product2>();
        }
        
        List<Product2> products = [
            SELECT Id, Name, ProductCode,
                   (SELECT Id, UnitPrice, Pricebook2Id
                    FROM PricebookEntries
                    WHERE Pricebook2Id = :pricebookId
                    AND IsActive = true
                    LIMIT 1)
            FROM Product2
            WHERE Id IN :productIds
            AND IsActive = true
        ];
        
        return new Map<Id, Product2>(products);
    }
}