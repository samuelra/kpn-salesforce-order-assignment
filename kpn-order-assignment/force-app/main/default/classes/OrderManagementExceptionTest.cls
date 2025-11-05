/**
 * @description Test class for OrderManagementException. Verifies happy paths, error handling,
 *               and test-visible helpers to keep coverage high and logic safe.
 * @author Samuel R
 * @since 2025-11
 */
@isTest
public class OrderManagementExceptionTest {
    @isTest
    static void testExceptionCanBeThrownAndCaught() {
        String expectedMessage = 'Test business error';
        Boolean caught = false;
        
        try {
            throw new OrderManagementException(expectedMessage);
        } catch (OrderManagementException ex) {
            caught = true;
            System.assertEquals(expectedMessage, ex.getMessage(), 'Message should be preserved');
        }
        
        System.assert(caught, 'OrderManagementException should have been caught');
    }
}