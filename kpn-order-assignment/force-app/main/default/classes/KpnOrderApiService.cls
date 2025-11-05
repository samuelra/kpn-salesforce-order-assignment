/**
 * @description Service that pushes activated Salesforce Orders to the external
 *               KPN Order API using a Named Credential. The public entry point is
 *               async (@future(callout=true)) so it can be called safely after DML.
 * @author Samuel R
 * @since 2025-11
 */
public with sharing class KpnOrderApiService {
    private static final String NC_NAME = 'KPN_Order_API';
    
    // this is the async entry point
    @future(callout=true)
    public static void sendOrderToApiAsync(Id orderId) {
        doSend(orderId);
    }
    
    // actual logic stays here
    private static void doSend(Id orderId) {
        // load order + items + account
        Order o = [
            SELECT Id, OrderNumber, EffectiveDate, AccountId,
                   BillToContact.Email, BillToContact.Phone,
                   ShippingStreet, ShippingCity, ShippingPostalCode, ShippingCountry,
                   BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        List<OrderItem> items = [
            SELECT Id, PricebookEntry.Product2Id, PricebookEntry.Product2.ProductCode,
                   PricebookEntry.Product2.Name,
                   UnitPrice, Quantity
            FROM OrderItem
            WHERE OrderId = :orderId
        ];
        
        Account acc = o.AccountId != null ? [
            SELECT Id, Name, BillingStreet, BillingCity, BillingPostalCode, BillingCountry
            FROM Account WHERE Id = :o.AccountId
        ] : null;
        
        // payload
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('customerId', acc != null ? acc.Id : null);
        payload.put('customerEmail', o.BillToContact != null ? o.BillToContact.Email : null);
        payload.put('customerPhone', o.BillToContact != null ? o.BillToContact.Phone : null);
        
        Map<String, Object> delivery = new Map<String, Object>{
            'street' => o.ShippingStreet,
            'postalCode' => o.ShippingPostalCode,
            'city' => o.ShippingCity,
            'country' => o.ShippingCountry,
            'houseNumber' => '1'
        };
        Map<String, Object> billing = new Map<String, Object>{
            'street' => o.BillingStreet,
            'postalCode' => o.BillingPostalCode,
            'city' => o.BillingCity,
            'country' => o.BillingCountry,
            'houseNumber' => '1'
        };
        payload.put('deliveryAddress', delivery);
        payload.put('billingAddress', billing);
        payload.put('billingAddressSameAsDelivery', false);
        payload.put('paymentMethod', 'Invoice');
        payload.put('autoActivate', true);
        
        List<Object> orderItems = new List<Object>();
        for (OrderItem oi : items) {
            Map<String, Object> itemJson = new Map<String, Object>();
            itemJson.put('productId', oi.PricebookEntry.Product2.ProductCode);
            itemJson.put('quantity', oi.Quantity);
            itemJson.put('selectedOptions', new Map<String, Object>());
            orderItems.add(itemJson);
        }
        payload.put('orderItems', orderItems);
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + NC_NAME + '/v1/orders');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload));
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Order API response: ' + res.getStatusCode() + ' ' + res.getBody());
    }
}