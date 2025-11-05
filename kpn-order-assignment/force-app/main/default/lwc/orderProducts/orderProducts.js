import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getOrderProducts from '@salesforce/apex/OrderProductsController.getOrderProducts';
import activateOrder from '@salesforce/apex/OrderProductsController.activateOrder';
import isOrderActivated from '@salesforce/apex/OrderProductsController.isOrderActivated';
import removeOrderItem from '@salesforce/apex/OrderProductsController.removeOrderItem';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import PRODUCT_ADDED_CHANNEL from '@salesforce/messageChannel/ProductAddedMessageChannel__c';
import { NavigationMixin } from 'lightning/navigation';

export default class OrderProducts extends NavigationMixin(LightningElement) {
    @api recordId;

    @track orderItems = [];
    @track isLoading = false;
    @track isActivating = false;
    @track isActivated = false;
    @track error;

    wiredOrderItemsResult;

    @wire(MessageContext)
    messageContext;

    subscription = null;

    columns = [
        {
            label: 'Product Name',
            fieldName: 'productName',
            type: 'text',
            sortable: true
        },
        {
            label: 'Product Code',
            fieldName: 'productCode',
            type: 'text',
            sortable: true
        },
        {
            label: 'Unit Price',
            fieldName: 'unitPrice',
            type: 'currency',
            sortable: true,
            typeAttributes: {
                currencyCode: 'EUR',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }
        },
        {
            label: 'Quantity',
            fieldName: 'quantity',
            type: 'number',
            sortable: true,
            cellAttributes: {
                alignment: 'left'
            }
        },
        {
            label: 'Total Price',
            fieldName: 'totalPrice',
            type: 'currency',
            sortable: true,
            typeAttributes: {
                currencyCode: 'EUR',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }
        },
        {
            type: 'button',
            initialWidth: 120,
            typeAttributes: {
                label: 'Remove',
                name: 'remove',
                variant: 'destructive',
                disabled: { fieldName: 'removeDisabled' }
            }
        }
    ];

    refreshCurrentRecordView() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    connectedCallback() {
        this.checkOrderActivationStatus();
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        if (this.subscription) {
            return;
        }
        this.subscription = subscribe(
            this.messageContext,
            PRODUCT_ADDED_CHANNEL,
            (message) => this.handleProductAddedMessage(message)
        );
    }

    handleProductAddedMessage(message) {
        if (message && message.orderId === this.recordId) {
            window.setTimeout(() => {
                this.refreshOrderProducts();
            }, 0);

            window.setTimeout(() => {
                this.refreshCurrentRecordView();
            }, 400);
        }
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    @wire(getOrderProducts, { orderId: '$recordId' })
    wiredOrderItems(result) {
        this.wiredOrderItemsResult = result;
        const { data, error } = result;

        if (data) {
            // decorate rows so the Remove button can be disabled when order is activated
            this.orderItems = this.decorateRows(data);
            this.error = undefined;
        } else if (error) {
            this.error = this.getErrorMessage(error);
            this.orderItems = [];
            this.showToast('Error loading order products', this.error, 'error');
        }
    }

    // keep your async activation check
    async checkOrderActivationStatus() {
        if (!this.recordId) {
            return;
        }

        try {
            this.isActivated = await isOrderActivated({ orderId: this.recordId });
            // re-decorate rows if we already have them
            if (this.orderItems && this.orderItems.length) {
                this.orderItems = this.decorateRows(this.orderItems);
            }
        } catch (error) {
            // just log
            // eslint-disable-next-line no-console
            console.error('Error checking activation status:', error);
        }
    }

    refreshOrderProducts() {
        if (this.wiredOrderItemsResult) {
            this.isLoading = true;
            refreshApex(this.wiredOrderItemsResult)
                .then(() => {
                    // after refresh, we may need to re-disable remove
                    if (this.orderItems && this.orderItems.length) {
                        this.orderItems = this.decorateRows(this.orderItems);
                    }
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    async handleActivateOrder() {
        if (!this.recordId) {
            this.showToast('Error', 'Order ID is missing', 'error');
            return;
        }

        if (this.isActivated) {
            this.showToast('Warning', 'Order is already activated', 'warning');
            return;
        }

        if (!this.hasOrderItems) {
            this.showToast('Error', 'Cannot activate order without products', 'error');
            return;
        }

        this.isActivating = true;

        try {
            const result = await activateOrder({ orderId: this.recordId });

            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.isActivated = true;
                this.refreshPage();
            } else {
                this.showToast('Activation Failed', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error activating order', this.getErrorMessage(error), 'error');
        } finally {
            this.isActivating = false;
        }
    }

    refreshPage() {
        window.location.reload();
    }
    
    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'remove') {
            // if for some reason it wasn’t disabled in the UI
            if (this.isActivated) {
                this.showToast('Warning', 'Cannot remove products from an activated order', 'warning');
                return;
            }

            this.isLoading = true;
            try {
                const res = await removeOrderItem({ orderItemId: row.orderItemId });
                if (res && res.success) {
                    this.showToast('Success', res.message, 'success');
                    this.refreshOrderProducts();
                    this.refreshCurrentRecordView();
                } else {
                    this.showToast('Error', res ? res.message : 'Unable to remove product', 'error');
                }
            } catch (error) {
                this.showToast('Error removing product', this.getErrorMessage(error), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    // helper to add removeDisabled
    decorateRows(data) {
        return data.map(item => {
            return {
                ...item,
                removeDisabled: this.isActivated
            };
        });
    }

    getErrorMessage(error) {
        if (!error) {
            return 'Unknown error occurred';
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        if (typeof error === 'string') {
            return error;
        }

        return 'An error occurred. Please contact your administrator.';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: variant === 'error' ? 'sticky' : 'dismissable'
        });
        this.dispatchEvent(event);
    }

    get hasOrderItems() {
        return this.orderItems && this.orderItems.length > 0;
    }

    get totalOrderAmount() {
        if (!this.hasOrderItems) {
            return 0;
        }

        return this.orderItems.reduce((sum, item) => {
            return sum + (item.totalPrice || 0);
        }, 0);
    }

    get formattedTotal() {
        return new Intl.NumberFormat('nl-NL', {
            style: 'currency',
            currency: 'EUR'
        }).format(this.totalOrderAmount);
    }

    get isActivateButtonDisabled() {
        return this.isActivating || this.isActivated || !this.hasOrderItems;
    }

    get activateButtonLabel() {
        if (this.isActivated) {
            return 'Order Activated';
        }
        if (this.isActivating) {
            return 'Activating...';
        }
        return 'Activate Order';
    }

    get activateButtonVariant() {
        return this.isActivated ? 'success' : 'brand';
    }

    get orderItemsCount() {
        return this.orderItems ? this.orderItems.length : 0;
    }

    get cardTitle() {
        return 'Order Products (' + this.orderItemsCount + ')';
    }
}
