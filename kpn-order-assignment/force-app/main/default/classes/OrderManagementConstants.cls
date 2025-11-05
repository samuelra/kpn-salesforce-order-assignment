/**
 * @description Constants used across the Order / Product integration module.
 *               Centralizes status values and error messages to avoid duplication.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class OrderManagementConstants {
    // Order Status
    public static final String ORDER_STATUS_DRAFT = 'Draft';
    public static final String ORDER_STATUS_ACTIVATED = 'Activated';
    
    // Order Item Status
    public static final String ORDER_ITEM_STATUS_DRAFT = 'Draft';
    public static final String ORDER_ITEM_STATUS_ACTIVATED = 'Activated';
    
    // Error Messages
    public static final String ERROR_NO_PRICEBOOK = 'Order must have a Pricebook associated';
    public static final String ERROR_ORDER_ACTIVATED = 'Cannot modify an activated order';
    public static final String ERROR_INVALID_PRODUCT = 'Product not found in order pricebook';
    public static final String ERROR_INVALID_ORDER = 'Invalid Order ID';
    
    // Standard Pricebook
    public static final String STANDARD_PRICEBOOK_NAME = 'Standard Price Book';
}