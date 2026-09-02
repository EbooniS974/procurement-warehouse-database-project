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

INSERT INTO dbo.UserGroups (GroupName, GroupDescription)
VALUES
    (N'Procurement', N'Procurement planning and sourcing users'),
    (N'Warehouse', N'Warehouse receiving and inventory users'),
    (N'Reporting', N'Read-only reporting users');

INSERT INTO dbo.ApprovalRules (TargetTable, StepNo, GroupID, RuleName)
SELECT
    src.TargetTable,
    src.StepNo,
    ug.GroupID,
    src.RuleName
FROM (
    VALUES
        ('PURCHASE_REQUEST', 1, N'Warehouse', N'Warehouse need confirmation'),
        ('PURCHASE_REQUEST', 2, N'Procurement', N'Procurement manager final approval'),
        ('PURCHASE_ORDER', 1, N'Procurement', N'Procurement commercial approval')
) AS src(TargetTable, StepNo, GroupName, RuleName)
INNER JOIN dbo.UserGroups AS ug
    ON ug.GroupName = src.GroupName;

INSERT INTO dbo.BusinessPartners (PartnerType, LegalName, Email, Phone)
VALUES
    ('EMPLOYEE', N'Aylin Karaca', N'aylin.karaca@orionfabrik.com', N'+90-312-500-1001'),
    ('EMPLOYEE', N'Bora Yildiz', N'bora.yildiz@orionfabrik.com', N'+90-312-500-1002'),
    ('EMPLOYEE', N'Cem Aydin', N'cem.aydin@orionfabrik.com', N'+90-312-500-1003'),
    ('EMPLOYEE', N'Derya Sen', N'derya.sen@orionfabrik.com', N'+90-312-500-1004'),
    ('EMPLOYEE', N'Ege Kurt', N'ege.kurt@orionfabrik.com', N'+90-312-500-1005');

INSERT INTO dbo.Employees
(
    PartnerID,
    EmployeeNo,
    FirstName,
    LastName,
    GroupID,
    HireDate,
    JobTitle,
    DepartmentName
)
SELECT
    bp.PartnerID,
    src.EmployeeNo,
    src.FirstName,
    src.LastName,
    ug.GroupID,
    src.HireDate,
    src.JobTitle,
    src.DepartmentName
FROM (
    VALUES
        (N'Aylin Karaca', N'EMP-001', N'Aylin', N'Karaca', N'Procurement', CAST('2021-02-15' AS DATE), N'Procurement Manager', N'Procurement'),
        (N'Bora Yildiz', N'EMP-002', N'Bora', N'Yildiz', N'Procurement', CAST('2022-01-10' AS DATE), N'Buyer', N'Procurement'),
        (N'Cem Aydin', N'EMP-003', N'Cem', N'Aydin', N'Warehouse', CAST('2020-09-01' AS DATE), N'Warehouse Chief', N'Operations'),
        (N'Derya Sen', N'EMP-004', N'Derya', N'Sen', N'Warehouse', CAST('2023-03-12' AS DATE), N'Warehouse Clerk', N'Operations'),
        (N'Ege Kurt', N'EMP-005', N'Ege', N'Kurt', N'Reporting', CAST('2024-06-01' AS DATE), N'Report Analyst', N'Business Intelligence')
) AS src(LegalName, EmployeeNo, FirstName, LastName, GroupName, HireDate, JobTitle, DepartmentName)
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.LegalName = src.LegalName
   AND bp.PartnerType = 'EMPLOYEE'
INNER JOIN dbo.UserGroups AS ug
    ON ug.GroupName = src.GroupName;

INSERT INTO dbo.AppUsers (EmployeeID, UserName, UserEmail, PasswordHash, UserStatus)
SELECT
    e.PartnerID,
    src.UserName,
    src.UserEmail,
    N'demo-hash',
    'ACTIVE'
FROM (
    VALUES
        (N'EMP-001', N'akaraca', N'akaraca@orionfabrik.local'),
        (N'EMP-002', N'byildiz', N'byildiz@orionfabrik.local'),
        (N'EMP-003', N'caydin', N'caydin@orionfabrik.local'),
        (N'EMP-004', N'dsen', N'dsen@orionfabrik.local'),
        (N'EMP-005', N'ekurt', N'ekurt@orionfabrik.local')
) AS src(EmployeeNo, UserName, UserEmail)
INNER JOIN dbo.Employees AS e
    ON e.EmployeeNo = src.EmployeeNo;

INSERT INTO dbo.UserGroupMembers (UserID, GroupID)
SELECT
    au.UserID,
    e.GroupID
FROM dbo.AppUsers AS au
INNER JOIN dbo.Employees AS e
    ON e.PartnerID = au.EmployeeID;

INSERT INTO dbo.BusinessPartners (PartnerType, LegalName, Email, Phone)
VALUES
    ('SUPPLIER', N'Marmara Metal A.S.', N'sales@marmarametal.com', N'+90-216-800-1100'),
    ('SUPPLIER', N'Anadolu Packaging Ltd.', N'quotes@anadolupack.com', N'+90-224-800-2200'),
    ('SUPPLIER', N'Kapadokya MRO Co.', N'info@kapadokyamro.com', N'+90-384-800-3300'),
    ('SUPPLIER', N'Trigger Logistics Demo Supplier', N'demo@triggerlogistics.com', N'+90-212-800-4400');

INSERT INTO dbo.Suppliers
(
    PartnerID,
    SupplierCode,
    TaxNumber,
    PaymentTermDays,
    PreferredSupplier,
    LastOfferDate
)
SELECT
    bp.PartnerID,
    src.SupplierCode,
    src.TaxNumber,
    src.PaymentTermDays,
    src.PreferredSupplier,
    src.LastOfferDate
FROM (
    VALUES
        (N'Marmara Metal A.S.', N'SUP-001', N'TAX-001', 30, 1, CAST('2026-05-01' AS DATE)),
        (N'Anadolu Packaging Ltd.', N'SUP-002', N'TAX-002', 45, 0, CAST('2026-05-01' AS DATE)),
        (N'Kapadokya MRO Co.', N'SUP-003', N'TAX-003', 20, 1, NULL),
        (N'Trigger Logistics Demo Supplier', N'SUP-004', N'TAX-004', 60, 0, NULL)
) AS src(LegalName, SupplierCode, TaxNumber, PaymentTermDays, PreferredSupplier, LastOfferDate)
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.LegalName = src.LegalName
   AND bp.PartnerType = 'SUPPLIER';

INSERT INTO dbo.SupplierContacts
(
    SupplierID,
    ContactName,
    ContactTitle,
    ContactEmail,
    ContactPhone,
    IsPrimary,
    IsActive
)
SELECT
    s.PartnerID,
    src.ContactName,
    src.ContactTitle,
    src.ContactEmail,
    src.ContactPhone,
    src.IsPrimary,
    1
FROM (
    VALUES
        (N'SUP-001', N'Selin Aras', N'Sales Manager', N'selin.aras@marmarametal.com', N'+90-216-800-1101', 1),
        (N'SUP-001', N'Onur Demir', N'Account Executive', N'onur.demir@marmarametal.com', N'+90-216-800-1102', 0),
        (N'SUP-002', N'Nil Koc', N'Quotation Specialist', N'nil.koc@anadolupack.com', N'+90-224-800-2201', 1),
        (N'SUP-003', N'Mert Polat', N'Service Desk', N'mert.polat@kapadokyamro.com', N'+90-384-800-3301', 1)
) AS src(SupplierCode, ContactName, ContactTitle, ContactEmail, ContactPhone, IsPrimary)
INNER JOIN dbo.Suppliers AS s
    ON s.SupplierCode = src.SupplierCode;

INSERT INTO dbo.MeasurementUnits (UnitCode, UnitName)
VALUES
    (N'KG', N'Kilogram'),
    (N'PCS', N'Piece'),
    (N'LTR', N'Liter');

INSERT INTO dbo.MaterialTypes (TypeCode, TypeName)
VALUES
    (N'RAW', N'Raw Material'),
    (N'PACK', N'Packaging'),
    (N'MRO', N'Maintenance and Repair');

DECLARE
    @WarehouseChiefID INT = (SELECT PartnerID FROM dbo.Employees WHERE EmployeeNo = N'EMP-003'),
    @WarehouseClerkID INT = (SELECT PartnerID FROM dbo.Employees WHERE EmployeeNo = N'EMP-004');

INSERT INTO dbo.Warehouses (WarehouseCode, WarehouseName, WarehouseAddress, ManagerID, IsActive)
VALUES
    (N'WH-CTR', N'Central Depot', N'Ankara Organized Industrial Zone, Block A', @WarehouseChiefID, 1),
    (N'WH-PLT', N'Plant Warehouse', N'Ankara Organized Industrial Zone, Block B', @WarehouseClerkID, 1);

INSERT INTO dbo.Materials
(
    MaterialCode,
    MaterialName,
    MaterialTypeID,
    BaseUnitID,
    ReorderLevel,
    StandardCost,
    LeadTimeDays,
    IsCritical,
    IsActive
)
SELECT
    src.MaterialCode,
    src.MaterialName,
    mt.MaterialTypeID,
    mu.UnitID,
    src.ReorderLevel,
    src.StandardCost,
    src.LeadTimeDays,
    src.IsCritical,
    1
FROM (
    VALUES
        (N'RM-STEEL-01', N'Steel Sheet 2mm', N'RAW', N'KG', 800.00, 48.00, 14, 1),
        (N'RM-ALUM-01', N'Aluminum Bar 10mm', N'RAW', N'KG', 500.00, 62.00, 10, 1),
        (N'PK-BOX-01', N'Cardboard Box Large', N'PACK', N'PCS', 200.00, 3.20, 7, 0),
        (N'MRO-BOLT-01', N'Hex Bolt M8', N'MRO', N'PCS', 600.00, 0.80, 5, 0),
        (N'MRO-LUBE-01', N'Machine Lubricant 5L', N'MRO', N'LTR', 60.00, 15.50, 4, 1),
        (N'PK-LABEL-01', N'Barcode Label Roll', N'PACK', N'PCS', 400.00, 1.10, 3, 0)
) AS src(MaterialCode, MaterialName, TypeCode, UnitCode, ReorderLevel, StandardCost, LeadTimeDays, IsCritical)
INNER JOIN dbo.MaterialTypes AS mt
    ON mt.TypeCode = src.TypeCode
INNER JOIN dbo.MeasurementUnits AS mu
    ON mu.UnitCode = src.UnitCode;

INSERT INTO dbo.MaterialSpecifications
(
    MaterialID,
    DrawingNo,
    RevisionNo,
    PhotoReference,
    QualityNotes,
    MainSubstituteMaterialID
)
SELECT
    m.MaterialID,
    src.DrawingNo,
    src.RevisionNo,
    src.PhotoReference,
    src.QualityNotes,
    sub.MaterialID
FROM (
    VALUES
        (N'RM-STEEL-01', N'DRW-STEEL-200', N'R1', N'PH-1001', N'Use cold-rolled certified batch only.', NULL),
        (N'RM-ALUM-01', N'DRW-ALUM-110', N'R2', N'PH-1002', N'Corrosion-resistant finish required.', N'RM-STEEL-01'),
        (N'PK-BOX-01', N'DRW-BOX-300', N'R1', N'PH-1003', N'Printed logo version only.', NULL),
        (N'MRO-BOLT-01', N'DRW-BOLT-008', N'R5', N'PH-1004', N'Zinc-coated metric bolt.', NULL),
        (N'MRO-LUBE-01', N'DRW-LUBE-005', N'R1', N'PH-1005', N'Food-safe lubricant is not required.', NULL),
        (N'PK-LABEL-01', N'DRW-LABEL-021', N'R3', N'PH-1006', N'Compatible with Zebra printers.', NULL)
) AS src(MaterialCode, DrawingNo, RevisionNo, PhotoReference, QualityNotes, SubstituteCode)
INNER JOIN dbo.Materials AS m
    ON m.MaterialCode = src.MaterialCode
LEFT JOIN dbo.Materials AS sub
    ON sub.MaterialCode = src.SubstituteCode;

DECLARE
    @CentralWarehouseID INT = (SELECT WarehouseID FROM dbo.Warehouses WHERE WarehouseCode = N'WH-CTR'),
    @PlantWarehouseID INT = (SELECT WarehouseID FROM dbo.Warehouses WHERE WarehouseCode = N'WH-PLT');

INSERT INTO dbo.InventoryBalances
(
    WarehouseID,
    MaterialID,
    OnHandQuantity,
    ReservedQuantity,
    LastUpdated
)
SELECT
    wh.WarehouseID,
    m.MaterialID,
    src.OnHandQuantity,
    src.ReservedQuantity,
    SYSDATETIME()
FROM (
    VALUES
        (N'WH-CTR', N'RM-STEEL-01', 1200.00, 100.00),
        (N'WH-CTR', N'MRO-BOLT-01', 500.00, 50.00),
        (N'WH-CTR', N'MRO-LUBE-01', 40.00, 5.00),
        (N'WH-PLT', N'PK-BOX-01', 150.00, 20.00),
        (N'WH-PLT', N'PK-LABEL-01', 300.00, 0.00)
) AS src(WarehouseCode, MaterialCode, OnHandQuantity, ReservedQuantity)
INNER JOIN dbo.Warehouses AS wh
    ON wh.WarehouseCode = src.WarehouseCode
INNER JOIN dbo.Materials AS m
    ON m.MaterialCode = src.MaterialCode;

INSERT INTO dbo.MaterialTransactionTypes (TypeCode, TypeName, StockEffect, RequiresDocument)
VALUES
    (N'PURCHASE_RECEIPT', N'Goods receipt from purchase order', 1, 1),
    (N'MANUAL_RECEIPT', N'Manual inventory receipt', 1, 0),
    (N'MANUAL_ISSUE', N'Manual inventory issue', -1, 0),
    (N'TRANSFER_IN', N'Warehouse transfer in', 1, 1),
    (N'TRANSFER_OUT', N'Warehouse transfer out', -1, 1);

DECLARE
    @ProcurementManagerID INT = (SELECT PartnerID FROM dbo.Employees WHERE EmployeeNo = N'EMP-001'),
    @BuyerID INT = (SELECT PartnerID FROM dbo.Employees WHERE EmployeeNo = N'EMP-002'),
    @WarehouseChiefID2 INT = (SELECT PartnerID FROM dbo.Employees WHERE EmployeeNo = N'EMP-003'),
    @SteelID INT = (SELECT MaterialID FROM dbo.Materials WHERE MaterialCode = N'RM-STEEL-01'),
    @BoltID INT = (SELECT MaterialID FROM dbo.Materials WHERE MaterialCode = N'MRO-BOLT-01'),
    @LubricantID INT = (SELECT MaterialID FROM dbo.Materials WHERE MaterialCode = N'MRO-LUBE-01'),
    @LabelID INT = (SELECT MaterialID FROM dbo.Materials WHERE MaterialCode = N'PK-LABEL-01'),
    @SupplierMetalID INT = (SELECT PartnerID FROM dbo.Suppliers WHERE SupplierCode = N'SUP-001'),
    @SupplierPackID INT = (SELECT PartnerID FROM dbo.Suppliers WHERE SupplierCode = N'SUP-002'),
    @SupplierMroID INT = (SELECT PartnerID FROM dbo.Suppliers WHERE SupplierCode = N'SUP-003');

INSERT INTO dbo.DepartmentBudgets
(
    DepartmentName,
    BudgetYear,
    BudgetMonth,
    BudgetAmount,
    AlertThresholdPct,
    ApprovedByEmployeeID
)
VALUES
    (N'Procurement', YEAR(CAST(SYSDATETIME() AS DATE)), MONTH(CAST(SYSDATETIME() AS DATE)), 25000.00, 75.00, @ProcurementManagerID),
    (N'Operations', YEAR(CAST(SYSDATETIME() AS DATE)), MONTH(CAST(SYSDATETIME() AS DATE)), 18000.00, 80.00, @ProcurementManagerID);

DECLARE @RequestResult1 TABLE
(
    RequestID INT,
    RequestNo NVARCHAR(30),
    RequestStatus VARCHAR(20)
);

INSERT INTO @RequestResult1
EXEC dbo.usp_CreatePurchaseRequestWithItem
    @RequestedByEmployeeID = @BuyerID,
    @WarehouseID = @CentralWarehouseID,
    @NeededByDate = '2026-05-20',
    @PriorityCode = 'HIGH',
    @MaterialID = @SteelID,
    @RequestedQuantity = 300.00,
    @RequestNotes = N'Production line steel replenishment';

DECLARE @RequestID1 INT = (SELECT TOP (1) RequestID FROM @RequestResult1);

INSERT INTO dbo.PurchaseRequestItems
(
    RequestID,
    MaterialID,
    RequestedQuantity,
    ApprovedQuantity,
    IssuedQuantity,
    ItemStatus
)
VALUES
    (@RequestID1, @BoltID, 600.00, 0.00, 0.00, 'OPEN');

DECLARE
    @Request1WarehouseApprovalID INT = (
        SELECT ApprovalID
        FROM dbo.ApprovalSteps
        WHERE TargetTable = 'PURCHASE_REQUEST'
          AND TargetRecordID = @RequestID1
          AND StepNo = 1
    ),
    @Request1ProcurementApprovalID INT = (
        SELECT ApprovalID
        FROM dbo.ApprovalSteps
        WHERE TargetTable = 'PURCHASE_REQUEST'
          AND TargetRecordID = @RequestID1
          AND StepNo = 2
    );

EXEC dbo.usp_SubmitApprovalDecision
    @ApprovalID = @Request1WarehouseApprovalID,
    @DecisionByEmployeeID = @WarehouseChiefID2,
    @DecisionStatus = 'APPROVED',
    @DecisionNotes = N'Warehouse confirms operational need';

EXEC dbo.usp_SubmitApprovalDecision
    @ApprovalID = @Request1ProcurementApprovalID,
    @DecisionByEmployeeID = @ProcurementManagerID,
    @DecisionStatus = 'APPROVED',
    @DecisionNotes = N'Procurement manager approved request';

DECLARE @RequestResult2 TABLE
(
    RequestID INT,
    RequestNo NVARCHAR(30),
    RequestStatus VARCHAR(20)
);

INSERT INTO @RequestResult2
EXEC dbo.usp_CreatePurchaseRequestWithItem
    @RequestedByEmployeeID = @BuyerID,
    @WarehouseID = @PlantWarehouseID,
    @NeededByDate = '2026-05-25',
    @PriorityCode = 'MEDIUM',
    @MaterialID = @LabelID,
    @RequestedQuantity = 250.00,
    @RequestNotes = N'Label roll request for the packaging line';

DECLARE @RequestID2 INT = (SELECT TOP (1) RequestID FROM @RequestResult2);

INSERT INTO dbo.PurchaseOffers
(
    RequestID,
    SupplierID,
    CreatedByEmployeeID,
    OfferDate,
    ValidUntil,
    OfferStatus,
    EvaluationNotes
)
VALUES
    (@RequestID1, @SupplierMetalID, @ProcurementManagerID, '2026-05-01', '2026-05-15', 'SUBMITTED', N'Primary steel supplier quotation'),
    (@RequestID1, @SupplierPackID, @ProcurementManagerID, '2026-05-02', '2026-05-16', 'SUBMITTED', N'Competitive quotation with mixed catalog items');

DECLARE
    @OfferMetalID INT = (
        SELECT OfferID
        FROM dbo.PurchaseOffers
        WHERE RequestID = @RequestID1
          AND SupplierID = @SupplierMetalID
    ),
    @OfferPackID INT = (
        SELECT OfferID
        FROM dbo.PurchaseOffers
        WHERE RequestID = @RequestID1
          AND SupplierID = @SupplierPackID
    ),
    @SteelRequestItemID INT = (
        SELECT RequestItemID
        FROM dbo.PurchaseRequestItems
        WHERE RequestID = @RequestID1
          AND MaterialID = @SteelID
    ),
    @BoltRequestItemID INT = (
        SELECT RequestItemID
        FROM dbo.PurchaseRequestItems
        WHERE RequestID = @RequestID1
          AND MaterialID = @BoltID
    );

INSERT INTO dbo.PurchaseOfferItems
(
    OfferID,
    RequestItemID,
    MaterialID,
    OfferedQuantity,
    UnitPrice,
    PromisedDeliveryDate,
    ItemStatus
)
VALUES
    (@OfferMetalID, @SteelRequestItemID, @SteelID, 300.00, 47.50, '2026-05-10', 'QUOTED'),
    (@OfferMetalID, @BoltRequestItemID, @BoltID, 600.00, 0.92, '2026-05-11', 'QUOTED'),
    (@OfferPackID, @SteelRequestItemID, @SteelID, 300.00, 46.80, '2026-05-12', 'QUOTED'),
    (@OfferPackID, @BoltRequestItemID, @BoltID, 600.00, 0.88, '2026-05-13', 'QUOTED');

UPDATE dbo.Suppliers
SET LastOfferDate = '2026-05-02'
WHERE PartnerID IN (@SupplierMetalID, @SupplierPackID);

DECLARE @OrderResult TABLE
(
    OrderID INT,
    OrderNo NVARCHAR(30),
    OrderStatus VARCHAR(20)
);

INSERT INTO @OrderResult
EXEC dbo.usp_ApproveOfferAndCreateOrder
    @OfferID = @OfferPackID,
    @ApprovedByEmployeeID = @ProcurementManagerID,
    @RequiredDeliveryDate = '2026-05-18',
    @OrderNotes = N'Approved best commercial offer';

DECLARE @OrderID INT = (SELECT TOP (1) OrderID FROM @OrderResult);
DECLARE @OrderApprovalID INT = (
    SELECT ApprovalID
    FROM dbo.ApprovalSteps
    WHERE TargetTable = 'PURCHASE_ORDER'
      AND TargetRecordID = @OrderID
      AND StepNo = 1
);

EXEC dbo.usp_SubmitApprovalDecision
    @ApprovalID = @OrderApprovalID,
    @DecisionByEmployeeID = @ProcurementManagerID,
    @DecisionStatus = 'APPROVED',
    @DecisionNotes = N'Commercial approval completed';

DECLARE @SteelOrderItemID INT = (
    SELECT OrderItemID
    FROM dbo.PurchaseOrderItems
    WHERE OrderID = @OrderID
      AND MaterialID = @SteelID
);

DECLARE @ReceiptResult TABLE
(
    ReceiptID INT,
    ReceiptNo NVARCHAR(30),
    ReceiptStatus VARCHAR(20)
);

INSERT INTO @ReceiptResult
EXEC dbo.usp_RecordDeliveryAndReceipt
    @OrderID = @OrderID,
    @WarehouseID = @CentralWarehouseID,
    @ReceivedByEmployeeID = @WarehouseChiefID,
    @OrderItemID = @SteelOrderItemID,
    @ReceivedQuantity = 250.00,
    @AcceptedQuantity = 240.00,
    @RejectedQuantity = 10.00,
    @InvoiceNo = N'INV-2026-0001',
    @CarrierName = N'Ankara Freight',
    @ReceiptNotes = N'Partial receipt with quality rejection';

DECLARE @ReceiptID INT = (SELECT TOP (1) ReceiptID FROM @ReceiptResult);
DECLARE @ReceiptItemID INT = (
    SELECT ReceiptItemID
    FROM dbo.DeliveryReceiptItems
    WHERE ReceiptID = @ReceiptID
      AND OrderItemID = @SteelOrderItemID
);

DECLARE @InspectionResult TABLE
(
    InspectionID INT,
    InspectionNo NVARCHAR(30),
    InspectionStatus VARCHAR(20)
);

INSERT INTO @InspectionResult
EXEC dbo.usp_RecordInspectionResult
    @ReceiptID = @ReceiptID,
    @InspectedByEmployeeID = @WarehouseChiefID,
    @ReceiptItemID = @ReceiptItemID,
    @AcceptedQuantity = 240.00,
    @RejectedQuantity = 10.00,
    @QuarantineQuantity = 0.00,
    @DefectCode = N'SURFACE_DAMAGE',
    @InspectionNotes = N'Quality inspection confirmed rejection on damaged sheets';

DECLARE @InspectionID INT = (SELECT TOP (1) InspectionID FROM @InspectionResult);
DECLARE @InspectionItemID INT = (
    SELECT TOP (1) qii.InspectionItemID
    FROM dbo.QualityInspectionItems AS qii
    WHERE qii.InspectionID = @InspectionID
);

DECLARE @ClaimResult TABLE
(
    ClaimID INT,
    ClaimNo NVARCHAR(30),
    ClaimStatus VARCHAR(20)
);

INSERT INTO @ClaimResult
EXEC dbo.usp_CreateVendorClaim
    @InspectionItemID = @InspectionItemID,
    @CreatedByEmployeeID = @ProcurementManagerID,
    @ClaimedQuantity = 10.00,
    @ClaimReason = N'Claim opened for rejected steel sheets after inspection',
    @SettlementAmount = 468.00;

DECLARE @ManualIssueTypeID INT = (
    SELECT TransactionTypeID
    FROM dbo.MaterialTransactionTypes
    WHERE TypeCode = N'MANUAL_ISSUE'
);

DECLARE @IssueTransactionID INT;

INSERT INTO dbo.MaterialTransactions
(
    TransactionTypeID,
    WarehouseID,
    RelatedRequestID,
    CreatedByEmployeeID,
    TransactionDate,
    PostingStatus
)
VALUES
(
    @ManualIssueTypeID,
    @CentralWarehouseID,
    @RequestID1,
    @WarehouseClerkID,
    SYSDATETIME(),
    'POSTED'
);

SET @IssueTransactionID = SCOPE_IDENTITY();

INSERT INTO dbo.MaterialTransactionItems
(
    TransactionID,
    MaterialID,
    Quantity,
    UnitCost
)
VALUES
(
    @IssueTransactionID,
    @BoltID,
    20.00,
    0.80
);

PRINT '--- Function demonstrations ---';
SELECT dbo.fn_GetInventoryOnHand(@CentralWarehouseID, @SteelID) AS SteelOnHandInCentralWarehouse;
SELECT dbo.fn_GetAvailableInventory(@CentralWarehouseID, @BoltID) AS BoltAvailableInCentralWarehouse;
SELECT dbo.fn_GetRequestFulfillmentRate(@RequestID1) AS Request1FulfillmentRate;
SELECT dbo.fn_GetSupplierLastQuotedPrice(@SupplierPackID, @SteelID) AS LastQuotedSteelPriceFromSupplier2;
SELECT dbo.fn_GetRemainingBudget(N'Procurement', YEAR(CAST(SYSDATETIME() AS DATE)), MONTH(CAST(SYSDATETIME() AS DATE))) AS ProcurementBudgetRemaining;
SELECT * FROM dbo.fn_WarehouseReorderAlerts(@CentralWarehouseID);
SELECT * FROM dbo.fn_RequestOfferRanking(@SteelRequestItemID);

PRINT '--- View demonstrations ---';
SELECT * FROM dbo.vw_ActiveSuppliers ORDER BY SupplierCode;
SELECT * FROM dbo.vw_CurrentInventory ORDER BY WarehouseCode, MaterialCode;
SELECT * FROM dbo.vw_OpenPurchaseRequests ORDER BY RequestDate DESC, RequestNo;
SELECT * FROM dbo.vw_SupplierOfferComparison ORDER BY RequestNo, MaterialCode, OfferRank;
SELECT * FROM dbo.vw_OrderReceiptStatus ORDER BY OrderDate DESC, OrderNo;
SELECT * FROM dbo.vw_PendingApprovals ORDER BY TargetTable, TargetRecordID, StepNo;
SELECT * FROM dbo.vw_BudgetUsage ORDER BY DepartmentName, BudgetYear, BudgetMonth;
SELECT * FROM dbo.vw_InspectionSummary ORDER BY InspectionDate DESC, InspectionNo;
SELECT * FROM dbo.vw_OpenVendorClaims ORDER BY ClaimDate DESC, ClaimNo;

PRINT '--- Trigger evidence ---';
SELECT RequestID, RequestNo, RequestStatus FROM dbo.PurchaseRequests ORDER BY RequestID;
SELECT OfferID, OfferNo, OfferStatus FROM dbo.PurchaseOffers ORDER BY OfferID;
SELECT OrderID, OrderNo, OrderStatus FROM dbo.PurchaseOrders ORDER BY OrderID;
SELECT ReceiptID, ReceiptNo, ReceiptStatus FROM dbo.DeliveryReceipts ORDER BY ReceiptID;
SELECT TransactionID, TransactionNo, PostingStatus FROM dbo.MaterialTransactions ORDER BY TransactionID;
SELECT * FROM dbo.AuditLogs ORDER BY ChangedAt DESC, AuditLogID DESC;

PRINT '--- Required outer join queries ---';

SELECT
    m.MaterialCode,
    m.MaterialName,
    w.WarehouseCode,
    ib.OnHandQuantity
FROM dbo.Materials AS m
LEFT OUTER JOIN dbo.InventoryBalances AS ib
    ON ib.MaterialID = m.MaterialID
LEFT OUTER JOIN dbo.Warehouses AS w
    ON w.WarehouseID = ib.WarehouseID
ORDER BY m.MaterialCode, w.WarehouseCode;

SELECT
    bp.LegalName AS SupplierName,
    po.OfferNo,
    po.OfferStatus
FROM dbo.PurchaseOffers AS po
RIGHT OUTER JOIN dbo.Suppliers AS s
    ON s.PartnerID = po.SupplierID
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.PartnerID = s.PartnerID
ORDER BY SupplierName, po.OfferNo;

SELECT
    pri.RequestItemID,
    pr.RequestNo,
    poi.OrderItemID,
    po.OrderNo,
    COALESCE(pri.MaterialID, poi.MaterialID) AS MaterialID
FROM dbo.PurchaseRequestItems AS pri
INNER JOIN dbo.PurchaseRequests AS pr
    ON pr.RequestID = pri.RequestID
FULL OUTER JOIN dbo.PurchaseOrderItems AS poi
    ON poi.RequestItemID = pri.RequestItemID
FULL OUTER JOIN dbo.PurchaseOrders AS po
    ON po.OrderID = poi.OrderID
ORDER BY COALESCE(pr.RequestNo, po.OrderNo), pri.RequestItemID, poi.OrderItemID;
GO
