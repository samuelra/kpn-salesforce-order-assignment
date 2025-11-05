# ⚡ KPN Salesforce Order Management Demo

### 🚀 Overview  
This repository demonstrates a **Salesforce Order Management implementation** integrating **internal Salesforce data** with **external APIs** (KPN Product & Order APIs) using **Apex**, **Lightning Web Components (LWC)**, and **Named Credentials**.

It provides a modular and scalable design pattern combining:
- **Apex Controllers** – handle UI interactions and orchestration.  
- **Service Classes** – business logic encapsulation.  
- **Domain/Selector Layers** – handle DML and SOQL abstraction.  
- **Integration Layer** – outbound REST callouts using Named Credentials.  
- **LWC Components** – dynamic UI for product selection and order activation.

---

### 🧱 Key Functionalities

| Layer | Components | Description |
|-------|-------------|--------------|
| **Apex Controller** | `AvailableProductsController`, `OrderProductsController` | Expose data and actions to LWC, including product listing, order activation, and external sync. |
| **Apex Services** | `OrderService`, `ProductService` | Core business logic for order and product management. |
| **Integration Services** | `ExternalProductService`, `KpnOrderApiService` | REST callouts to KPN Product & Order APIs via Named Credentials. |
| **Domain / Selector Classes** | `OrderDomain`, `OrderItemDomain`, `OrderSelector`, `ProductSelector`, `PricebookSelector` | Handle record operations and SOQL abstraction. |
| **LWC Components** | `availableProducts`, `orderProducts` | Interactive UI for product selection, order review, and activation. |
| **Named Credentials** | `KPN_Product_API`, `KPN_Order_API` | Secure external API connections (SwaggerHub endpoints). |
| **FlexiPage** | `Order_Record_Page.flexipage-meta.xml` | Lightning App Builder configuration to host LWCs on the Order record page. |
| **Remote Site Settings** | `KPN_Product_API.remoteSite-meta.xml`, `KPN_Order_API.remoteSite-meta.xml` | Legacy compatibility for external callouts. |

---

### ⚙️ Setup & Deployment

**Prerequisites**
- Salesforce DX CLI installed (`sf` or `sfdx`)
- Connected Salesforce DevHub or Scratch Org
- Authorized org (`sf org login web`)

**Deployment Steps**
```bash
git clone https://github.com/samuelra/kpn-salesforce-order-assignment.git
cd kpn-salesforce-order-assignment
sf project deploy start -p force-app
