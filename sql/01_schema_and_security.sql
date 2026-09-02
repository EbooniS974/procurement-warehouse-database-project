IF DB_ID(N'ProcurementWarehouseDB') IS NOT NULL
BEGIN
    ALTER DATABASE ProcurementWarehouseDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ProcurementWarehouseDB;
END;
GO

CREATE DATABASE ProcurementWarehouseDB;
GO

USE ProcurementWarehouseDB;
GO

SET NOCOUNT ON;
GO

SET ANSI_NULLS ON;
GO

SET ANSI_PADDING ON;
GO

SET ANSI_WARNINGS ON;
GO

SET ARITHABORT ON;
GO

SET CONCAT_NULL_YIELDS_NULL ON;
GO

SET NUMERIC_ROUNDABORT OFF;
GO

SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE dbo.UserGroups
(
    GroupID INT IDENTITY(1, 1) PRIMARY KEY,
    GroupName NVARCHAR(100) NOT NULL UNIQUE,
    GroupDescription NVARCHAR(250) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_UserGroups_IsActive DEFAULT (1)
);
GO

CREATE TABLE dbo.BusinessPartners
(
    PartnerID INT IDENTITY(1, 1) PRIMARY KEY,
    PartnerType VARCHAR(20) NOT NULL,
    LegalName NVARCHAR(150) NOT NULL,
    Email NVARCHAR(150) NULL,
    Phone NVARCHAR(40) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_BusinessPartners_IsActive DEFAULT (1),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_BusinessPartners_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_BusinessPartners_PartnerType CHECK (PartnerType IN ('EMPLOYEE', 'SUPPLIER'))
);
GO

CREATE TABLE dbo.Employees
(
    PartnerID INT PRIMARY KEY,
    EmployeeNo NVARCHAR(20) NOT NULL UNIQUE,
    FirstName NVARCHAR(80) NOT NULL,
    LastName NVARCHAR(80) NOT NULL,
    GroupID INT NULL,
    HireDate DATE NOT NULL,
    JobTitle NVARCHAR(100) NOT NULL,
    DepartmentName NVARCHAR(100) NOT NULL,
    CONSTRAINT FK_Employees_Partner FOREIGN KEY (PartnerID) REFERENCES dbo.BusinessPartners(PartnerID),
    CONSTRAINT FK_Employees_Group FOREIGN KEY (GroupID) REFERENCES dbo.UserGroups(GroupID)
);
GO

CREATE TABLE dbo.Suppliers
(
    PartnerID INT PRIMARY KEY,
    SupplierCode NVARCHAR(20) NOT NULL UNIQUE,
    TaxNumber NVARCHAR(30) NOT NULL UNIQUE,
    PaymentTermDays INT NOT NULL,
    PreferredSupplier BIT NOT NULL CONSTRAINT DF_Suppliers_Preferred DEFAULT (0),
    LastOfferDate DATE NULL,
    CONSTRAINT FK_Suppliers_Partner FOREIGN KEY (PartnerID) REFERENCES dbo.BusinessPartners(PartnerID),
    CONSTRAINT CK_Suppliers_PaymentTerm CHECK (PaymentTermDays >= 0)
);
GO

CREATE TABLE dbo.AppUsers
(
    UserID INT IDENTITY(1, 1) PRIMARY KEY,
    EmployeeID INT NOT NULL UNIQUE,
    UserName NVARCHAR(80) NOT NULL UNIQUE,
    UserEmail NVARCHAR(150) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    UserStatus VARCHAR(20) NOT NULL CONSTRAINT DF_AppUsers_UserStatus DEFAULT ('ACTIVE'),
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_AppUsers_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_AppUsers_Employee FOREIGN KEY (EmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_AppUsers_UserStatus CHECK (UserStatus IN ('ACTIVE', 'LOCKED', 'PASSIVE'))
);
GO

CREATE TABLE dbo.UserGroupMembers
(
    UserID INT NOT NULL,
    GroupID INT NOT NULL,
    AssignedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UserGroupMembers_AssignedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_UserGroupMembers PRIMARY KEY (UserID, GroupID),
    CONSTRAINT FK_UserGroupMembers_User FOREIGN KEY (UserID) REFERENCES dbo.AppUsers(UserID),
    CONSTRAINT FK_UserGroupMembers_Group FOREIGN KEY (GroupID) REFERENCES dbo.UserGroups(GroupID)
);
GO

CREATE TABLE dbo.SupplierContacts
(
    ContactID INT IDENTITY(1, 1) PRIMARY KEY,
    SupplierID INT NOT NULL,
    ContactName NVARCHAR(100) NOT NULL,
    ContactTitle NVARCHAR(100) NULL,
    ContactEmail NVARCHAR(150) NULL,
    ContactPhone NVARCHAR(40) NULL,
    IsPrimary BIT NOT NULL CONSTRAINT DF_SupplierContacts_IsPrimary DEFAULT (0),
    IsActive BIT NOT NULL CONSTRAINT DF_SupplierContacts_IsActive DEFAULT (1),
    CONSTRAINT FK_SupplierContacts_Supplier FOREIGN KEY (SupplierID) REFERENCES dbo.Suppliers(PartnerID)
);
GO

CREATE TABLE dbo.MeasurementUnits
(
    UnitID INT IDENTITY(1, 1) PRIMARY KEY,
    UnitCode NVARCHAR(15) NOT NULL UNIQUE,
    UnitName NVARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.MaterialTypes
(
    MaterialTypeID INT IDENTITY(1, 1) PRIMARY KEY,
    TypeCode NVARCHAR(20) NOT NULL UNIQUE,
    TypeName NVARCHAR(80) NOT NULL UNIQUE
);
GO

CREATE TABLE dbo.Materials
(
    MaterialID INT IDENTITY(1, 1) PRIMARY KEY,
    MaterialCode NVARCHAR(30) NOT NULL UNIQUE,
    MaterialName NVARCHAR(150) NOT NULL,
    MaterialTypeID INT NOT NULL,
    BaseUnitID INT NOT NULL,
    ReorderLevel DECIMAL(18, 2) NOT NULL CONSTRAINT DF_Materials_ReorderLevel DEFAULT (0),
    StandardCost DECIMAL(18, 2) NOT NULL CONSTRAINT DF_Materials_StandardCost DEFAULT (0),
    LeadTimeDays INT NOT NULL CONSTRAINT DF_Materials_LeadTimeDays DEFAULT (0),
    IsCritical BIT NOT NULL CONSTRAINT DF_Materials_IsCritical DEFAULT (0),
    IsActive BIT NOT NULL CONSTRAINT DF_Materials_IsActive DEFAULT (1),
    CONSTRAINT FK_Materials_Type FOREIGN KEY (MaterialTypeID) REFERENCES dbo.MaterialTypes(MaterialTypeID),
    CONSTRAINT FK_Materials_Unit FOREIGN KEY (BaseUnitID) REFERENCES dbo.MeasurementUnits(UnitID),
    CONSTRAINT CK_Materials_ReorderLevel CHECK (ReorderLevel >= 0),
    CONSTRAINT CK_Materials_StandardCost CHECK (StandardCost >= 0),
    CONSTRAINT CK_Materials_LeadTimeDays CHECK (LeadTimeDays >= 0)
);
GO

CREATE TABLE dbo.MaterialSpecifications
(
    MaterialID INT PRIMARY KEY,
    DrawingNo NVARCHAR(50) NULL,
    RevisionNo NVARCHAR(20) NULL,
    PhotoReference NVARCHAR(50) NULL,
    QualityNotes NVARCHAR(250) NULL,
    MainSubstituteMaterialID INT NULL,
    CONSTRAINT FK_MaterialSpecifications_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT FK_MaterialSpecifications_Substitute FOREIGN KEY (MainSubstituteMaterialID) REFERENCES dbo.Materials(MaterialID)
);
GO

CREATE TABLE dbo.Warehouses
(
    WarehouseID INT IDENTITY(1, 1) PRIMARY KEY,
    WarehouseCode NVARCHAR(20) NOT NULL UNIQUE,
    WarehouseName NVARCHAR(100) NOT NULL,
    WarehouseAddress NVARCHAR(200) NOT NULL,
    ManagerID INT NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Warehouses_IsActive DEFAULT (1),
    CONSTRAINT FK_Warehouses_Manager FOREIGN KEY (ManagerID) REFERENCES dbo.Employees(PartnerID)
);
GO

CREATE TABLE dbo.InventoryBalances
(
    InventoryID INT IDENTITY(1, 1) PRIMARY KEY,
    WarehouseID INT NOT NULL,
    MaterialID INT NOT NULL,
    OnHandQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_InventoryBalances_OnHand DEFAULT (0),
    ReservedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_InventoryBalances_Reserved DEFAULT (0),
    LastUpdated DATETIME2(0) NOT NULL CONSTRAINT DF_InventoryBalances_LastUpdated DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_InventoryBalances UNIQUE (WarehouseID, MaterialID),
    CONSTRAINT FK_InventoryBalances_Warehouse FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouses(WarehouseID),
    CONSTRAINT FK_InventoryBalances_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_InventoryBalances_OnHand CHECK (OnHandQuantity >= 0),
    CONSTRAINT CK_InventoryBalances_Reserved CHECK (ReservedQuantity >= 0)
);
GO

CREATE TABLE dbo.PurchaseRequests
(
    RequestID INT IDENTITY(1, 1) PRIMARY KEY,
    RequestNo NVARCHAR(30) NULL,
    RequestedByEmployeeID INT NOT NULL,
    WarehouseID INT NOT NULL,
    RequestDate DATE NOT NULL CONSTRAINT DF_PurchaseRequests_RequestDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    NeededByDate DATE NOT NULL,
    RequestStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseRequests_Status DEFAULT ('DRAFT'),
    PriorityCode VARCHAR(10) NOT NULL CONSTRAINT DF_PurchaseRequests_Priority DEFAULT ('MEDIUM'),
    RequestNotes NVARCHAR(250) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_PurchaseRequests_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_PurchaseRequests_Employee FOREIGN KEY (RequestedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT FK_PurchaseRequests_Warehouse FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouses(WarehouseID),
    CONSTRAINT CK_PurchaseRequests_Status CHECK (RequestStatus IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'ORDERED', 'CLOSED', 'CANCELLED')),
    CONSTRAINT CK_PurchaseRequests_Priority CHECK (PriorityCode IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT'))
);
GO

CREATE TABLE dbo.PurchaseRequestItems
(
    RequestItemID INT IDENTITY(1, 1) PRIMARY KEY,
    RequestID INT NOT NULL,
    MaterialID INT NOT NULL,
    RequestedQuantity DECIMAL(18, 2) NOT NULL,
    ApprovedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_PurchaseRequestItems_Approved DEFAULT (0),
    IssuedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_PurchaseRequestItems_Issued DEFAULT (0),
    ItemStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseRequestItems_Status DEFAULT ('OPEN'),
    CONSTRAINT UQ_PurchaseRequestItems UNIQUE (RequestID, MaterialID),
    CONSTRAINT FK_PurchaseRequestItems_Request FOREIGN KEY (RequestID) REFERENCES dbo.PurchaseRequests(RequestID),
    CONSTRAINT FK_PurchaseRequestItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_PurchaseRequestItems_Requested CHECK (RequestedQuantity > 0),
    CONSTRAINT CK_PurchaseRequestItems_Approved CHECK (ApprovedQuantity >= 0),
    CONSTRAINT CK_PurchaseRequestItems_Issued CHECK (IssuedQuantity >= 0),
    CONSTRAINT CK_PurchaseRequestItems_Status CHECK (ItemStatus IN ('OPEN', 'SOURCED', 'PARTIAL', 'COMPLETE', 'CANCELLED'))
);
GO

CREATE TABLE dbo.PurchaseOffers
(
    OfferID INT IDENTITY(1, 1) PRIMARY KEY,
    OfferNo NVARCHAR(30) NULL,
    RequestID INT NOT NULL,
    SupplierID INT NOT NULL,
    CreatedByEmployeeID INT NOT NULL,
    OfferDate DATE NOT NULL,
    ValidUntil DATE NOT NULL,
    OfferStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseOffers_Status DEFAULT ('DRAFT'),
    EvaluationNotes NVARCHAR(250) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_PurchaseOffers_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_PurchaseOffers_Request FOREIGN KEY (RequestID) REFERENCES dbo.PurchaseRequests(RequestID),
    CONSTRAINT FK_PurchaseOffers_Supplier FOREIGN KEY (SupplierID) REFERENCES dbo.Suppliers(PartnerID),
    CONSTRAINT FK_PurchaseOffers_Creator FOREIGN KEY (CreatedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_PurchaseOffers_Status CHECK (OfferStatus IN ('DRAFT', 'SUBMITTED', 'ACCEPTED', 'REJECTED', 'EXPIRED'))
);
GO

CREATE TABLE dbo.PurchaseOfferItems
(
    OfferItemID INT IDENTITY(1, 1) PRIMARY KEY,
    OfferID INT NOT NULL,
    RequestItemID INT NOT NULL,
    MaterialID INT NOT NULL,
    OfferedQuantity DECIMAL(18, 2) NOT NULL,
    UnitPrice DECIMAL(18, 2) NOT NULL,
    PromisedDeliveryDate DATE NULL,
    ItemStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseOfferItems_Status DEFAULT ('QUOTED'),
    CONSTRAINT UQ_PurchaseOfferItems UNIQUE (OfferID, RequestItemID),
    CONSTRAINT FK_PurchaseOfferItems_Offer FOREIGN KEY (OfferID) REFERENCES dbo.PurchaseOffers(OfferID),
    CONSTRAINT FK_PurchaseOfferItems_RequestItem FOREIGN KEY (RequestItemID) REFERENCES dbo.PurchaseRequestItems(RequestItemID),
    CONSTRAINT FK_PurchaseOfferItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_PurchaseOfferItems_OfferedQty CHECK (OfferedQuantity > 0),
    CONSTRAINT CK_PurchaseOfferItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CK_PurchaseOfferItems_Status CHECK (ItemStatus IN ('QUOTED', 'AWARDED', 'REJECTED', 'EXPIRED'))
);
GO

CREATE TABLE dbo.PurchaseOrders
(
    OrderID INT IDENTITY(1, 1) PRIMARY KEY,
    OrderNo NVARCHAR(30) NULL,
    SupplierID INT NOT NULL,
    CreatedByEmployeeID INT NOT NULL,
    ApprovedByEmployeeID INT NULL,
    OrderDate DATE NOT NULL CONSTRAINT DF_PurchaseOrders_OrderDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    RequiredDeliveryDate DATE NOT NULL,
    OrderStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseOrders_Status DEFAULT ('DRAFT'),
    PaymentStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseOrders_PaymentStatus DEFAULT ('OPEN'),
    OrderNotes NVARCHAR(250) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_PurchaseOrders_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_PurchaseOrders_Supplier FOREIGN KEY (SupplierID) REFERENCES dbo.Suppliers(PartnerID),
    CONSTRAINT FK_PurchaseOrders_Creator FOREIGN KEY (CreatedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT FK_PurchaseOrders_Approver FOREIGN KEY (ApprovedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_PurchaseOrders_Status CHECK (OrderStatus IN ('DRAFT', 'APPROVED', 'PARTIAL', 'RECEIVED', 'CANCELLED')),
    CONSTRAINT CK_PurchaseOrders_PaymentStatus CHECK (PaymentStatus IN ('OPEN', 'PARTIAL', 'PAID'))
);
GO

CREATE TABLE dbo.PurchaseOrderItems
(
    OrderItemID INT IDENTITY(1, 1) PRIMARY KEY,
    OrderID INT NOT NULL,
    OfferItemID INT NULL,
    RequestItemID INT NOT NULL,
    MaterialID INT NOT NULL,
    OrderedQuantity DECIMAL(18, 2) NOT NULL,
    ReceivedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_PurchaseOrderItems_Received DEFAULT (0),
    UnitPrice DECIMAL(18, 2) NOT NULL,
    ItemStatus VARCHAR(20) NOT NULL CONSTRAINT DF_PurchaseOrderItems_Status DEFAULT ('OPEN'),
    CONSTRAINT UQ_PurchaseOrderItems UNIQUE (OrderID, RequestItemID),
    CONSTRAINT FK_PurchaseOrderItems_Order FOREIGN KEY (OrderID) REFERENCES dbo.PurchaseOrders(OrderID),
    CONSTRAINT FK_PurchaseOrderItems_OfferItem FOREIGN KEY (OfferItemID) REFERENCES dbo.PurchaseOfferItems(OfferItemID),
    CONSTRAINT FK_PurchaseOrderItems_RequestItem FOREIGN KEY (RequestItemID) REFERENCES dbo.PurchaseRequestItems(RequestItemID),
    CONSTRAINT FK_PurchaseOrderItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_PurchaseOrderItems_Ordered CHECK (OrderedQuantity > 0),
    CONSTRAINT CK_PurchaseOrderItems_Received CHECK (ReceivedQuantity >= 0),
    CONSTRAINT CK_PurchaseOrderItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CK_PurchaseOrderItems_Status CHECK (ItemStatus IN ('OPEN', 'PARTIAL', 'RECEIVED', 'CANCELLED'))
);
GO

CREATE TABLE dbo.DeliveryReceipts
(
    ReceiptID INT IDENTITY(1, 1) PRIMARY KEY,
    ReceiptNo NVARCHAR(30) NULL,
    OrderID INT NOT NULL,
    ReceivedWarehouseID INT NOT NULL,
    ReceivedByEmployeeID INT NOT NULL,
    InvoiceNo NVARCHAR(50) NOT NULL,
    CarrierName NVARCHAR(100) NULL,
    ReceiptDate DATE NOT NULL CONSTRAINT DF_DeliveryReceipts_ReceiptDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    ReceiptStatus VARCHAR(20) NOT NULL CONSTRAINT DF_DeliveryReceipts_Status DEFAULT ('POSTED'),
    ReceiptNotes NVARCHAR(250) NULL,
    CONSTRAINT FK_DeliveryReceipts_Order FOREIGN KEY (OrderID) REFERENCES dbo.PurchaseOrders(OrderID),
    CONSTRAINT FK_DeliveryReceipts_Warehouse FOREIGN KEY (ReceivedWarehouseID) REFERENCES dbo.Warehouses(WarehouseID),
    CONSTRAINT FK_DeliveryReceipts_Receiver FOREIGN KEY (ReceivedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_DeliveryReceipts_Status CHECK (ReceiptStatus IN ('POSTED', 'PARTIAL', 'REJECTED'))
);
GO

CREATE TABLE dbo.DeliveryReceiptItems
(
    ReceiptItemID INT IDENTITY(1, 1) PRIMARY KEY,
    ReceiptID INT NOT NULL,
    OrderItemID INT NOT NULL,
    MaterialID INT NOT NULL,
    ReceivedQuantity DECIMAL(18, 2) NOT NULL,
    AcceptedQuantity DECIMAL(18, 2) NOT NULL,
    RejectedQuantity DECIMAL(18, 2) NOT NULL,
    CONSTRAINT UQ_DeliveryReceiptItems UNIQUE (ReceiptID, OrderItemID),
    CONSTRAINT FK_DeliveryReceiptItems_Receipt FOREIGN KEY (ReceiptID) REFERENCES dbo.DeliveryReceipts(ReceiptID),
    CONSTRAINT FK_DeliveryReceiptItems_OrderItem FOREIGN KEY (OrderItemID) REFERENCES dbo.PurchaseOrderItems(OrderItemID),
    CONSTRAINT FK_DeliveryReceiptItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_DeliveryReceiptItems_Received CHECK (ReceivedQuantity > 0),
    CONSTRAINT CK_DeliveryReceiptItems_Accepted CHECK (AcceptedQuantity >= 0),
    CONSTRAINT CK_DeliveryReceiptItems_Rejected CHECK (RejectedQuantity >= 0)
);
GO

CREATE TABLE dbo.MaterialTransactionTypes
(
    TransactionTypeID INT IDENTITY(1, 1) PRIMARY KEY,
    TypeCode NVARCHAR(30) NOT NULL UNIQUE,
    TypeName NVARCHAR(100) NOT NULL UNIQUE,
    StockEffect SMALLINT NOT NULL,
    RequiresDocument BIT NOT NULL CONSTRAINT DF_MaterialTransactionTypes_RequiresDocument DEFAULT (0),
    CONSTRAINT CK_MaterialTransactionTypes_StockEffect CHECK (StockEffect IN (-1, 1))
);
GO

CREATE TABLE dbo.MaterialTransactions
(
    TransactionID INT IDENTITY(1, 1) PRIMARY KEY,
    TransactionNo NVARCHAR(30) NULL,
    TransactionTypeID INT NOT NULL,
    WarehouseID INT NOT NULL,
    RelatedRequestID INT NULL,
    RelatedOrderID INT NULL,
    ReferenceReceiptID INT NULL,
    CreatedByEmployeeID INT NOT NULL,
    TransactionDate DATETIME2(0) NOT NULL CONSTRAINT DF_MaterialTransactions_TransactionDate DEFAULT (SYSDATETIME()),
    PostingStatus VARCHAR(20) NOT NULL CONSTRAINT DF_MaterialTransactions_PostingStatus DEFAULT ('POSTED'),
    CONSTRAINT FK_MaterialTransactions_Type FOREIGN KEY (TransactionTypeID) REFERENCES dbo.MaterialTransactionTypes(TransactionTypeID),
    CONSTRAINT FK_MaterialTransactions_Warehouse FOREIGN KEY (WarehouseID) REFERENCES dbo.Warehouses(WarehouseID),
    CONSTRAINT FK_MaterialTransactions_Request FOREIGN KEY (RelatedRequestID) REFERENCES dbo.PurchaseRequests(RequestID),
    CONSTRAINT FK_MaterialTransactions_Order FOREIGN KEY (RelatedOrderID) REFERENCES dbo.PurchaseOrders(OrderID),
    CONSTRAINT FK_MaterialTransactions_Receipt FOREIGN KEY (ReferenceReceiptID) REFERENCES dbo.DeliveryReceipts(ReceiptID),
    CONSTRAINT FK_MaterialTransactions_Creator FOREIGN KEY (CreatedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_MaterialTransactions_PostingStatus CHECK (PostingStatus IN ('POSTED', 'VOID'))
);
GO

CREATE TABLE dbo.MaterialTransactionItems
(
    TransactionItemID INT IDENTITY(1, 1) PRIMARY KEY,
    TransactionID INT NOT NULL,
    MaterialID INT NOT NULL,
    Quantity DECIMAL(18, 2) NOT NULL,
    UnitCost DECIMAL(18, 2) NOT NULL CONSTRAINT DF_MaterialTransactionItems_UnitCost DEFAULT (0),
    CONSTRAINT FK_MaterialTransactionItems_Transaction FOREIGN KEY (TransactionID) REFERENCES dbo.MaterialTransactions(TransactionID),
    CONSTRAINT FK_MaterialTransactionItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_MaterialTransactionItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_MaterialTransactionItems_UnitCost CHECK (UnitCost >= 0)
);
GO

CREATE TABLE dbo.AuditLogs
(
    AuditLogID INT IDENTITY(1, 1) PRIMARY KEY,
    TableName NVARCHAR(100) NOT NULL,
    RecordID INT NOT NULL,
    ActionName NVARCHAR(50) NOT NULL,
    OldValue NVARCHAR(250) NULL,
    NewValue NVARCHAR(250) NULL,
    ChangedByEmployeeID INT NULL,
    ChangedAt DATETIME2(0) NOT NULL CONSTRAINT DF_AuditLogs_ChangedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_AuditLogs_Employee FOREIGN KEY (ChangedByEmployeeID) REFERENCES dbo.Employees(PartnerID)
);
GO

CREATE TABLE dbo.ApprovalRules
(
    ApprovalRuleID INT IDENTITY(1, 1) PRIMARY KEY,
    TargetTable VARCHAR(30) NOT NULL,
    StepNo INT NOT NULL,
    GroupID INT NOT NULL,
    RuleName NVARCHAR(100) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_ApprovalRules_IsActive DEFAULT (1),
    CONSTRAINT UQ_ApprovalRules UNIQUE (TargetTable, StepNo, GroupID),
    CONSTRAINT FK_ApprovalRules_Group FOREIGN KEY (GroupID) REFERENCES dbo.UserGroups(GroupID),
    CONSTRAINT CK_ApprovalRules_TargetTable CHECK (TargetTable IN ('PURCHASE_REQUEST', 'PURCHASE_ORDER')),
    CONSTRAINT CK_ApprovalRules_StepNo CHECK (StepNo > 0)
);
GO

CREATE TABLE dbo.ApprovalSteps
(
    ApprovalID INT IDENTITY(1, 1) PRIMARY KEY,
    ApprovalRuleID INT NOT NULL,
    TargetTable VARCHAR(30) NOT NULL,
    TargetRecordID INT NOT NULL,
    StepNo INT NOT NULL,
    AssignedGroupID INT NOT NULL,
    ApprovalStatus VARCHAR(20) NOT NULL CONSTRAINT DF_ApprovalSteps_Status DEFAULT ('PENDING'),
    DecisionByEmployeeID INT NULL,
    DecisionDate DATETIME2(0) NULL,
    DecisionNotes NVARCHAR(250) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ApprovalSteps_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_ApprovalSteps UNIQUE (TargetTable, TargetRecordID, StepNo),
    CONSTRAINT FK_ApprovalSteps_Rule FOREIGN KEY (ApprovalRuleID) REFERENCES dbo.ApprovalRules(ApprovalRuleID),
    CONSTRAINT FK_ApprovalSteps_Group FOREIGN KEY (AssignedGroupID) REFERENCES dbo.UserGroups(GroupID),
    CONSTRAINT FK_ApprovalSteps_Employee FOREIGN KEY (DecisionByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_ApprovalSteps_TargetTable CHECK (TargetTable IN ('PURCHASE_REQUEST', 'PURCHASE_ORDER')),
    CONSTRAINT CK_ApprovalSteps_Status CHECK (ApprovalStatus IN ('PENDING', 'APPROVED', 'REJECTED')),
    CONSTRAINT CK_ApprovalSteps_StepNo CHECK (StepNo > 0)
);
GO

CREATE TABLE dbo.DepartmentBudgets
(
    BudgetID INT IDENTITY(1, 1) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL,
    BudgetYear INT NOT NULL,
    BudgetMonth INT NOT NULL,
    BudgetAmount DECIMAL(18, 2) NOT NULL,
    AlertThresholdPct DECIMAL(5, 2) NOT NULL CONSTRAINT DF_DepartmentBudgets_AlertThreshold DEFAULT (80.00),
    ApprovedByEmployeeID INT NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DepartmentBudgets_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_DepartmentBudgets UNIQUE (DepartmentName, BudgetYear, BudgetMonth),
    CONSTRAINT FK_DepartmentBudgets_Approver FOREIGN KEY (ApprovedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_DepartmentBudgets_Year CHECK (BudgetYear >= 2000),
    CONSTRAINT CK_DepartmentBudgets_Month CHECK (BudgetMonth BETWEEN 1 AND 12),
    CONSTRAINT CK_DepartmentBudgets_Amount CHECK (BudgetAmount > 0),
    CONSTRAINT CK_DepartmentBudgets_Threshold CHECK (AlertThresholdPct BETWEEN 0 AND 100)
);
GO

CREATE TABLE dbo.BudgetTransactions
(
    BudgetTransactionID INT IDENTITY(1, 1) PRIMARY KEY,
    BudgetID INT NOT NULL,
    RelatedOrderID INT NULL,
    TransactionType VARCHAR(20) NOT NULL CONSTRAINT DF_BudgetTransactions_Type DEFAULT ('COMMITMENT'),
    Amount DECIMAL(18, 2) NOT NULL,
    TransactionNotes NVARCHAR(250) NULL,
    CreatedByEmployeeID INT NOT NULL,
    TransactionDate DATETIME2(0) NOT NULL CONSTRAINT DF_BudgetTransactions_TransactionDate DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_BudgetTransactions_Budget FOREIGN KEY (BudgetID) REFERENCES dbo.DepartmentBudgets(BudgetID),
    CONSTRAINT FK_BudgetTransactions_Order FOREIGN KEY (RelatedOrderID) REFERENCES dbo.PurchaseOrders(OrderID),
    CONSTRAINT FK_BudgetTransactions_Employee FOREIGN KEY (CreatedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_BudgetTransactions_Type CHECK (TransactionType IN ('COMMITMENT', 'ADJUSTMENT', 'RELEASE')),
    CONSTRAINT CK_BudgetTransactions_Amount CHECK (Amount <> 0)
);
GO

CREATE TABLE dbo.QualityInspections
(
    InspectionID INT IDENTITY(1, 1) PRIMARY KEY,
    InspectionNo NVARCHAR(30) NULL,
    ReceiptID INT NOT NULL,
    InspectedByEmployeeID INT NOT NULL,
    InspectionDate DATE NOT NULL CONSTRAINT DF_QualityInspections_InspectionDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    InspectionStatus VARCHAR(20) NOT NULL CONSTRAINT DF_QualityInspections_Status DEFAULT ('OPEN'),
    InspectionNotes NVARCHAR(250) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_QualityInspections_CreatedAt DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_QualityInspections_Receipt FOREIGN KEY (ReceiptID) REFERENCES dbo.DeliveryReceipts(ReceiptID),
    CONSTRAINT FK_QualityInspections_Employee FOREIGN KEY (InspectedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_QualityInspections_Status CHECK (InspectionStatus IN ('OPEN', 'ACCEPTED', 'PARTIAL', 'REJECTED'))
);
GO

CREATE TABLE dbo.QualityInspectionItems
(
    InspectionItemID INT IDENTITY(1, 1) PRIMARY KEY,
    InspectionID INT NOT NULL,
    ReceiptItemID INT NOT NULL,
    MaterialID INT NOT NULL,
    AcceptedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_QualityInspectionItems_Accepted DEFAULT (0),
    RejectedQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_QualityInspectionItems_Rejected DEFAULT (0),
    QuarantineQuantity DECIMAL(18, 2) NOT NULL CONSTRAINT DF_QualityInspectionItems_Quarantine DEFAULT (0),
    DefectCode NVARCHAR(50) NULL,
    ResolutionStatus VARCHAR(20) NOT NULL CONSTRAINT DF_QualityInspectionItems_Resolution DEFAULT ('OPEN'),
    CONSTRAINT UQ_QualityInspectionItems UNIQUE (InspectionID, ReceiptItemID),
    CONSTRAINT FK_QualityInspectionItems_Inspection FOREIGN KEY (InspectionID) REFERENCES dbo.QualityInspections(InspectionID),
    CONSTRAINT FK_QualityInspectionItems_ReceiptItem FOREIGN KEY (ReceiptItemID) REFERENCES dbo.DeliveryReceiptItems(ReceiptItemID),
    CONSTRAINT FK_QualityInspectionItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_QualityInspectionItems_Accepted CHECK (AcceptedQuantity >= 0),
    CONSTRAINT CK_QualityInspectionItems_Rejected CHECK (RejectedQuantity >= 0),
    CONSTRAINT CK_QualityInspectionItems_Quarantine CHECK (QuarantineQuantity >= 0),
    CONSTRAINT CK_QualityInspectionItems_Total CHECK (AcceptedQuantity + RejectedQuantity + QuarantineQuantity > 0),
    CONSTRAINT CK_QualityInspectionItems_Resolution CHECK (ResolutionStatus IN ('OPEN', 'CLAIMED', 'CLOSED'))
);
GO

CREATE TABLE dbo.VendorClaims
(
    ClaimID INT IDENTITY(1, 1) PRIMARY KEY,
    ClaimNo NVARCHAR(30) NULL,
    SupplierID INT NOT NULL,
    OrderID INT NULL,
    InspectionID INT NULL,
    ClaimDate DATE NOT NULL CONSTRAINT DF_VendorClaims_ClaimDate DEFAULT (CAST(SYSDATETIME() AS DATE)),
    ClaimStatus VARCHAR(20) NOT NULL CONSTRAINT DF_VendorClaims_Status DEFAULT ('OPEN'),
    ClaimReason NVARCHAR(250) NOT NULL,
    CreatedByEmployeeID INT NOT NULL,
    SettlementAmount DECIMAL(18, 2) NOT NULL CONSTRAINT DF_VendorClaims_Settlement DEFAULT (0),
    CONSTRAINT FK_VendorClaims_Supplier FOREIGN KEY (SupplierID) REFERENCES dbo.Suppliers(PartnerID),
    CONSTRAINT FK_VendorClaims_Order FOREIGN KEY (OrderID) REFERENCES dbo.PurchaseOrders(OrderID),
    CONSTRAINT FK_VendorClaims_Inspection FOREIGN KEY (InspectionID) REFERENCES dbo.QualityInspections(InspectionID),
    CONSTRAINT FK_VendorClaims_Employee FOREIGN KEY (CreatedByEmployeeID) REFERENCES dbo.Employees(PartnerID),
    CONSTRAINT CK_VendorClaims_Status CHECK (ClaimStatus IN ('OPEN', 'SUBMITTED', 'CLOSED', 'CANCELLED')),
    CONSTRAINT CK_VendorClaims_Settlement CHECK (SettlementAmount >= 0)
);
GO

CREATE TABLE dbo.VendorClaimItems
(
    ClaimItemID INT IDENTITY(1, 1) PRIMARY KEY,
    ClaimID INT NOT NULL,
    InspectionItemID INT NOT NULL,
    MaterialID INT NOT NULL,
    ClaimedQuantity DECIMAL(18, 2) NOT NULL,
    UnitPrice DECIMAL(18, 2) NOT NULL,
    ResolutionCode NVARCHAR(30) NULL,
    CONSTRAINT UQ_VendorClaimItems UNIQUE (ClaimID, InspectionItemID),
    CONSTRAINT FK_VendorClaimItems_Claim FOREIGN KEY (ClaimID) REFERENCES dbo.VendorClaims(ClaimID),
    CONSTRAINT FK_VendorClaimItems_InspectionItem FOREIGN KEY (InspectionItemID) REFERENCES dbo.QualityInspectionItems(InspectionItemID),
    CONSTRAINT FK_VendorClaimItems_Material FOREIGN KEY (MaterialID) REFERENCES dbo.Materials(MaterialID),
    CONSTRAINT CK_VendorClaimItems_Claimed CHECK (ClaimedQuantity > 0),
    CONSTRAINT CK_VendorClaimItems_UnitPrice CHECK (UnitPrice >= 0)
);
GO

CREATE INDEX IX_Employees_Group ON dbo.Employees(GroupID);
CREATE INDEX IX_SupplierContacts_Supplier ON dbo.SupplierContacts(SupplierID);
CREATE INDEX IX_Materials_Type ON dbo.Materials(MaterialTypeID);
CREATE INDEX IX_InventoryBalances_WarehouseMaterial ON dbo.InventoryBalances(WarehouseID, MaterialID);
CREATE UNIQUE INDEX UX_PurchaseRequests_RequestNo ON dbo.PurchaseRequests(RequestNo) WHERE RequestNo IS NOT NULL;
CREATE INDEX IX_PurchaseRequests_WarehouseStatus ON dbo.PurchaseRequests(WarehouseID, RequestStatus);
CREATE INDEX IX_PurchaseRequestItems_Request ON dbo.PurchaseRequestItems(RequestID);
CREATE UNIQUE INDEX UX_PurchaseOffers_OfferNo ON dbo.PurchaseOffers(OfferNo) WHERE OfferNo IS NOT NULL;
CREATE INDEX IX_PurchaseOffers_RequestSupplier ON dbo.PurchaseOffers(RequestID, SupplierID);
CREATE INDEX IX_PurchaseOfferItems_RequestItem ON dbo.PurchaseOfferItems(RequestItemID);
CREATE UNIQUE INDEX UX_PurchaseOrders_OrderNo ON dbo.PurchaseOrders(OrderNo) WHERE OrderNo IS NOT NULL;
CREATE INDEX IX_PurchaseOrders_SupplierStatus ON dbo.PurchaseOrders(SupplierID, OrderStatus);
CREATE INDEX IX_PurchaseOrderItems_Order ON dbo.PurchaseOrderItems(OrderID);
CREATE UNIQUE INDEX UX_DeliveryReceipts_ReceiptNo ON dbo.DeliveryReceipts(ReceiptNo) WHERE ReceiptNo IS NOT NULL;
CREATE INDEX IX_DeliveryReceipts_Order ON dbo.DeliveryReceipts(OrderID);
CREATE UNIQUE INDEX UX_MaterialTransactions_TransactionNo ON dbo.MaterialTransactions(TransactionNo) WHERE TransactionNo IS NOT NULL;
CREATE INDEX IX_MaterialTransactions_WarehouseDate ON dbo.MaterialTransactions(WarehouseID, TransactionDate);
CREATE INDEX IX_ApprovalSteps_TargetStatus ON dbo.ApprovalSteps(TargetTable, TargetRecordID, ApprovalStatus);
CREATE INDEX IX_DepartmentBudgets_Period ON dbo.DepartmentBudgets(DepartmentName, BudgetYear, BudgetMonth);
CREATE INDEX IX_BudgetTransactions_Budget ON dbo.BudgetTransactions(BudgetID, TransactionDate);
CREATE INDEX IX_QualityInspections_Receipt ON dbo.QualityInspections(ReceiptID, InspectionDate);
CREATE INDEX IX_QualityInspectionItems_ReceiptItem ON dbo.QualityInspectionItems(ReceiptItemID);
CREATE UNIQUE INDEX UX_QualityInspections_InspectionNo ON dbo.QualityInspections(InspectionNo) WHERE InspectionNo IS NOT NULL;
CREATE INDEX IX_VendorClaims_SupplierStatus ON dbo.VendorClaims(SupplierID, ClaimStatus);
CREATE UNIQUE INDEX UX_VendorClaims_ClaimNo ON dbo.VendorClaims(ClaimNo) WHERE ClaimNo IS NOT NULL;
CREATE INDEX IX_VendorClaimItems_Claim ON dbo.VendorClaimItems(ClaimID);
GO

CREATE ROLE procurement_clerk;
CREATE ROLE warehouse_clerk;
CREATE ROLE reporting_analyst;
GO

CREATE USER procurement_demo WITHOUT LOGIN;
CREATE USER warehouse_demo WITHOUT LOGIN;
CREATE USER reporting_demo WITHOUT LOGIN;
GO

ALTER ROLE procurement_clerk ADD MEMBER procurement_demo;
ALTER ROLE warehouse_clerk ADD MEMBER warehouse_demo;
ALTER ROLE reporting_analyst ADD MEMBER reporting_demo;
GO
