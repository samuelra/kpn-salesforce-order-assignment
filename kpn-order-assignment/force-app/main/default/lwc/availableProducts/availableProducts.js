import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';

import getCombinedProducts from '@salesforce/apex/AvailableProductsController.getCombinedProducts';
import addProductToOrder from '@salesforce/apex/AvailableProductsController.addProductToOrder';
import addExternalProductToOrder from '@salesforce/apex/AvailableProductsController.addExternalProductToOrder';
import isOrderActivated from '@salesforce/apex/OrderProductsController.isOrderActivated';

import PRODUCT_ADDED_CHANNEL from '@salesforce/messageChannel/ProductAddedMessageChannel__c';

export default class AvailableProducts extends NavigationMixin(LightningElement) {
    @api recordId;

    @track products = [];
    @track filteredProducts = [];
    searchTerm = '';
    isLoading = false;
    @track error;
    includeExternal = true;
    sfCount = 0;
    apiCount = 0;
    totalCount = 0;
    showStats = false;
    @track pageSize = 10;
    @track currentPage = 1;
    isActivated = false;

    columns = [
        {
            label: 'Source',
            fieldName: 'source',
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'sourceBadgeClass' },
                iconName: { fieldName: 'sourceIcon' }
            },
            initialWidth: 120
        },
        {
            label: 'Product Name',
            fieldName: 'productName',
            type: 'text',
            sortable: true,
            cellAttributes: {
                class: { fieldName: 'rowClass' }
            }
        },
        {
            label: 'Category',
            fieldName: 'category',
            type: 'text',
            initialWidth: 130
        },
        {
            label: 'List Price',
            fieldName: 'listPrice',
            type: 'currency',
            sortable: true,
            typeAttributes: {
                currencyCode: 'EUR',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            },
            initialWidth: 130
        },
        {
            label: 'Status',
            fieldName: 'statusLabel',
            type: 'text',
            cellAttributes: {
                class: { fieldName: 'statusClass' }
            },
            initialWidth: 120
        },
        {
            type: 'button',
            typeAttributes: {
                label: 'Add to Order',
                name: 'add_product',
                variant: 'brand',
                disabled: { fieldName: 'disableAdd' }

            },
            initialWidth: 140
        }
    ];

    @wire(MessageContext)
    messageContext;


    connectedCallback() {
        this.loadProducts();
        this.checkActivation();
    }

    async checkActivation() {
        if (!this.recordId) return;

        try {
            const activated = await isOrderActivated({ orderId: this.recordId });
            this.isActivated = activated;

            // Refresh button disable state based purely on order status
            if (this.products && this.products.length) {
                this.products = this.products.map(p => ({
                    ...p,
                    disableAdd: this.isActivated // disable if order is activated
                }));
                this.filteredProducts = this.filteredProducts.map(p => ({
                    ...p,
                    disableAdd: this.isActivated
                }));
            }

        } catch (error) {
            console.error('Error checking activation:', error);
        }
    }



    async loadProducts() {
        this.isLoading = true;
        this.error = undefined;
        this.currentPage = 1;

        try {
            const data = await getCombinedProducts({
                orderId: this.recordId,
                includeExternal: this.includeExternal
            });

            this.products = this.transformProductData(data);
            this.sfCount = this.products.filter(p => !p.isExternal).length;
            this.apiCount = this.products.filter(p => p.isExternal).length;
            this.totalCount = this.products.length;
            this.showStats = false;
            Promise.resolve().then(() => {
                this.showStats = true;
            });
            this.applyFilters();

        } catch (error) {
            this.error = this.getErrorMessage(error);
            this.products = [];
            this.filteredProducts = [];
            this.showToast('Error loading products', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

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


    transformProductData(data) {
        return data.map(product => ({
            ...product,
            sourceIcon: product.isExternal ? 'utility:world' : 'utility:salesforce1',
            sourceBadgeClass: product.isExternal
                ? 'slds-badge slds-theme_warning'
                : 'slds-badge slds-theme_success',
            disableAdd: this.isActivated // 👈 use global order activation
        }));
    }



    handleSearch(event) {
        this.searchTerm = event.target.value.toLowerCase();
        this.applyFilters();
    }

    handleToggleExternal(event) {
        this.includeExternal = event.target.checked;
        this.loadProducts();
    }

    applyFilters() {
        let filtered = [...this.products];

        // Apply search filter
        if (this.searchTerm) {
            filtered = filtered.filter(product => {
                const nameMatch = product.productName &&
                    product.productName.toLowerCase().includes(this.searchTerm);
                const codeMatch = product.productCode &&
                    product.productCode.toLowerCase().includes(this.searchTerm);
                const categoryMatch = product.category &&
                    product.category.toLowerCase().includes(this.searchTerm);
                const brandMatch = product.brand &&
                    product.brand.toLowerCase().includes(this.searchTerm);
                return nameMatch || codeMatch || categoryMatch || brandMatch;
            });
        }

        this.filteredProducts = filtered;
        this.currentPage = 1;

    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'add_product') {
            if (row.isExternal) {
                this.handleAddExternalProduct(row);
            } else {
                this.handleAddProduct(row.productId);
            }
        }
    }

    async handleAddProduct(productId) {
        if (!productId || !this.recordId) {
            this.showToast('Error', 'Missing product or order information', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const result = await addProductToOrder({
                orderId: this.recordId,
                productId: productId
            });

            if (result.success) {
                await this.loadProducts();
                this.markProductAsAdded(productId);
                this.dispatchProductAddedEvent(productId, result.recordId);
                this.showToast('Success', result.message, 'success');

                //a short delay to commit the OrderItem
                setTimeout(() => {
                    this.refreshCurrentRecordView();
                }, 500);
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error adding product', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleAddExternalProduct(product) {
        if (!product || !this.recordId) {
            this.showToast('Error', 'Missing order or product information', 'error');
            return;
        }

        this.isLoading = true;
        try {
            const result = await addExternalProductToOrder({
                orderId: this.recordId,
                externalProductJson: JSON.stringify(product)
            });

            if (result && result.success) {
                this.markProductAsAdded(product.productId || product.productCode);
                await this.loadProducts();
                this.dispatchProductAddedEvent(
                    product.productId || product.productCode,
                    result.recordId
                );
                this.showToast('Success', result.message, 'success');
                //a short delay to commit the OrderItem
                setTimeout(() => {
                    this.refreshCurrentRecordView();
                }, 500);
            } else {
                this.showToast('Error', result ? result.message : 'Failed to add external product', 'error');
            }
        } catch (error) {
            this.showToast('Error adding external product', this.getErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    markProductAsAdded(productId) {
        this.products = this.products.map(p => {
            if (p.productId === productId) {
                return {
                    ...p,
                    isAddedToOrder: true,
                    statusLabel: '✓ Added',
                    statusClass: 'slds-text-color_success',
                    rowClass: 'slds-hint-parent slds-is-selected',
                    disableAdd: true
                };
            }
            return p;
        });

        this.filteredProducts = this.filteredProducts.map(p => {
            if (p.productId === productId) {
                return {
                    ...p,
                    isAddedToOrder: true,
                    statusLabel: '✓ Added',
                    statusClass: 'slds-text-color_success',
                    rowClass: 'slds-hint-parent slds-is-selected',
                    disableAdd: true    // 👈 new
                };
            }
            return p;
        });

        // your stats refresh...
        this.sfCount = this.products.filter(p => !p.isExternal).length;
        this.apiCount = this.products.filter(p => p.isExternal).length;
        this.totalCount = this.products.length;

        this.showStats = false;
        Promise.resolve().then(() => {
            this.showStats = true;
        });
    }



    dispatchProductAddedEvent(productId, orderItemId) {
        const detail = {
            productId,
            orderItemId,
            orderId: this.recordId
        };

        // publish to LMS
        publish(this.messageContext, PRODUCT_ADDED_CHANNEL, detail);

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

    handleNextPage() {
        if (!this.isLastPage) {
            this.currentPage = this.currentPage + 1;
        }
    }

    handlePrevPage() {
        if (!this.isFirstPage) {
            this.currentPage = this.currentPage - 1;
        }
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

    get hasProducts() {
        return this.filteredProducts && this.filteredProducts.length > 0;
    }

    get noProductsMessage() {
        if (this.searchTerm) {
            return `No products found matching "${this.searchTerm}"`;
        }
        return "No products available for this order's pricebook";
    }

    get sfProductCount() {
        return this.products.filter(p => !p.isExternal).length;
    }

    get externalProductCount() {
        return this.products.filter(p => p.isExternal).length;
    }

    get productStats() {
        return `SF: ${this.sfCount} | API: ${this.apiCount} | Total: ${this.totalCount}`;
    }

    get totalPages() {
        return this.filteredProducts.length
            ? Math.ceil(this.filteredProducts.length / this.pageSize)
            : 1;
    }

    get pagedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.filteredProducts.slice(start, end);
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get totalRecords() {
        return this.filteredProducts ? this.filteredProducts.length : 0;
    }

    get startRecord() {
        if (this.totalRecords === 0) {
            return 0;
        }
        return (this.currentPage - 1) * this.pageSize + 1;
    }

    get endRecord() {
        if (this.totalRecords === 0) {
            return 0;
        }
        const end = this.currentPage * this.pageSize;
        return end > this.totalRecords ? this.totalRecords : end;
    }


}