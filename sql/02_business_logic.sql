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

CREATE OR ALTER FUNCTION dbo.fn_GetInventoryOnHand
(
    @WarehouseID INT,
    @MaterialID INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @result DECIMAL(18, 2);

    SELECT @result = ib.OnHandQuantity
    FROM dbo.InventoryBalances AS ib
    WHERE ib.WarehouseID = @WarehouseID
      AND ib.MaterialID = @MaterialID;

    RETURN ISNULL(@result, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetAvailableInventory
(
    @WarehouseID INT,
    @MaterialID INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @result DECIMAL(18, 2);

    SELECT @result = ib.OnHandQuantity - ib.ReservedQuantity
    FROM dbo.InventoryBalances AS ib
    WHERE ib.WarehouseID = @WarehouseID
      AND ib.MaterialID = @MaterialID;

    RETURN ISNULL(@result, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetRequestFulfillmentRate
(
    @RequestID INT
)
RETURNS DECIMAL(5, 2)
AS
BEGIN
    DECLARE @rate DECIMAL(5, 2);

    SELECT
        @rate = CAST(
            CASE
                WHEN SUM(pri.RequestedQuantity) = 0 THEN 0
                ELSE (SUM(pri.IssuedQuantity) * 100.0) / SUM(pri.RequestedQuantity)
            END AS DECIMAL(5, 2)
        )
    FROM dbo.PurchaseRequestItems AS pri
    WHERE pri.RequestID = @RequestID;

    RETURN ISNULL(@rate, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetSupplierLastQuotedPrice
(
    @SupplierID INT,
    @MaterialID INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @price DECIMAL(18, 2);

    SELECT TOP (1)
        @price = poi.UnitPrice
    FROM dbo.PurchaseOfferItems AS poi
    INNER JOIN dbo.PurchaseOffers AS po
        ON po.OfferID = poi.OfferID
    WHERE po.SupplierID = @SupplierID
      AND poi.MaterialID = @MaterialID
    ORDER BY po.OfferDate DESC, poi.OfferItemID DESC;

    RETURN ISNULL(@price, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_WarehouseReorderAlerts
(
    @WarehouseID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        w.WarehouseCode,
        m.MaterialID,
        m.MaterialCode,
        m.MaterialName,
        ib.OnHandQuantity,
        ib.ReservedQuantity,
        dbo.fn_GetAvailableInventory(ib.WarehouseID, ib.MaterialID) AS AvailableQuantity,
        m.ReorderLevel
    FROM dbo.InventoryBalances AS ib
    INNER JOIN dbo.Materials AS m
        ON m.MaterialID = ib.MaterialID
    INNER JOIN dbo.Warehouses AS w
        ON w.WarehouseID = ib.WarehouseID
    WHERE ib.WarehouseID = @WarehouseID
      AND dbo.fn_GetAvailableInventory(ib.WarehouseID, ib.MaterialID) <= m.ReorderLevel
);
GO

CREATE OR ALTER FUNCTION dbo.fn_RequestOfferRanking
(
    @RequestItemID INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY poi.UnitPrice ASC, poi.PromisedDeliveryDate ASC, po.OfferDate DESC
        ) AS OfferRank,
        po.OfferID,
        po.OfferNo,
        bp.LegalName AS SupplierName,
        poi.MaterialID,
        poi.OfferedQuantity,
        poi.UnitPrice,
        poi.PromisedDeliveryDate,
        po.ValidUntil
    FROM dbo.PurchaseOfferItems AS poi
    INNER JOIN dbo.PurchaseOffers AS po
        ON po.OfferID = poi.OfferID
    INNER JOIN dbo.Suppliers AS s
        ON s.PartnerID = po.SupplierID
    INNER JOIN dbo.BusinessPartners AS bp
        ON bp.PartnerID = s.PartnerID
    WHERE poi.RequestItemID = @RequestItemID
      AND po.OfferStatus IN ('SUBMITTED', 'ACCEPTED')
);
GO

CREATE OR ALTER VIEW dbo.vw_ActiveSuppliers
AS
SELECT
    s.PartnerID AS SupplierID,
    s.SupplierCode,
    bp.LegalName AS SupplierName,
    s.TaxNumber,
    s.PaymentTermDays,
    s.PreferredSupplier,
    bp.Email,
    bp.Phone,
    COUNT(sc.ContactID) AS ActiveContactCount
FROM dbo.Suppliers AS s
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.PartnerID = s.PartnerID
LEFT JOIN dbo.SupplierContacts AS sc
    ON sc.SupplierID = s.PartnerID
   AND sc.IsActive = 1
WHERE bp.IsActive = 1
GROUP BY
    s.PartnerID,
    s.SupplierCode,
    bp.LegalName,
    s.TaxNumber,
    s.PaymentTermDays,
    s.PreferredSupplier,
    bp.Email,
    bp.Phone;
GO

CREATE OR ALTER VIEW dbo.vw_CurrentInventory
AS
SELECT
    w.WarehouseID,
    w.WarehouseCode,
    w.WarehouseName,
    m.MaterialID,
    m.MaterialCode,
    m.MaterialName,
    mt.TypeName AS MaterialType,
    u.UnitCode,
    ib.OnHandQuantity,
    ib.ReservedQuantity,
    dbo.fn_GetAvailableInventory(ib.WarehouseID, ib.MaterialID) AS AvailableQuantity,
    m.ReorderLevel,
    ib.LastUpdated
FROM dbo.InventoryBalances AS ib
INNER JOIN dbo.Warehouses AS w
    ON w.WarehouseID = ib.WarehouseID
INNER JOIN dbo.Materials AS m
    ON m.MaterialID = ib.MaterialID
INNER JOIN dbo.MaterialTypes AS mt
    ON mt.MaterialTypeID = m.MaterialTypeID
INNER JOIN dbo.MeasurementUnits AS u
    ON u.UnitID = m.BaseUnitID;
GO

CREATE OR ALTER VIEW dbo.vw_OpenPurchaseRequests
AS
SELECT
    pr.RequestID,
    pr.RequestNo,
    pr.RequestDate,
    pr.NeededByDate,
    pr.RequestStatus,
    pr.PriorityCode,
    w.WarehouseCode,
    e.EmployeeNo,
    CONCAT(e.FirstName, ' ', e.LastName) AS RequestedBy,
    dbo.fn_GetRequestFulfillmentRate(pr.RequestID) AS FulfillmentRate,
    COUNT(pri.RequestItemID) AS ItemCount
FROM dbo.PurchaseRequests AS pr
INNER JOIN dbo.Warehouses AS w
    ON w.WarehouseID = pr.WarehouseID
INNER JOIN dbo.Employees AS e
    ON e.PartnerID = pr.RequestedByEmployeeID
LEFT JOIN dbo.PurchaseRequestItems AS pri
    ON pri.RequestID = pr.RequestID
WHERE pr.RequestStatus IN ('DRAFT', 'SUBMITTED', 'APPROVED', 'ORDERED')
GROUP BY
    pr.RequestID,
    pr.RequestNo,
    pr.RequestDate,
    pr.NeededByDate,
    pr.RequestStatus,
    pr.PriorityCode,
    w.WarehouseCode,
    e.EmployeeNo,
    e.FirstName,
    e.LastName;
GO

CREATE OR ALTER VIEW dbo.vw_SupplierOfferComparison
AS
SELECT
    pr.RequestNo,
    pri.RequestItemID,
    m.MaterialCode,
    m.MaterialName,
    po.OfferNo,
    bp.LegalName AS SupplierName,
    poi.OfferedQuantity,
    poi.UnitPrice,
    poi.PromisedDeliveryDate,
    ROW_NUMBER() OVER (
        PARTITION BY pri.RequestItemID
        ORDER BY poi.UnitPrice ASC, poi.PromisedDeliveryDate ASC, po.OfferDate DESC
    ) AS OfferRank
FROM dbo.PurchaseOfferItems AS poi
INNER JOIN dbo.PurchaseOffers AS po
    ON po.OfferID = poi.OfferID
INNER JOIN dbo.PurchaseRequestItems AS pri
    ON pri.RequestItemID = poi.RequestItemID
INNER JOIN dbo.PurchaseRequests AS pr
    ON pr.RequestID = pri.RequestID
INNER JOIN dbo.Materials AS m
    ON m.MaterialID = poi.MaterialID
INNER JOIN dbo.Suppliers AS s
    ON s.PartnerID = po.SupplierID
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.PartnerID = s.PartnerID;
GO

CREATE OR ALTER VIEW dbo.vw_OrderReceiptStatus
AS
SELECT
    po.OrderID,
    po.OrderNo,
    po.OrderDate,
    po.OrderStatus,
    bp.LegalName AS SupplierName,
    poi.OrderItemID,
    m.MaterialCode,
    m.MaterialName,
    poi.OrderedQuantity,
    poi.ReceivedQuantity,
    poi.OrderedQuantity - poi.ReceivedQuantity AS RemainingQuantity,
    SUM(ISNULL(dri.AcceptedQuantity, 0)) AS AcceptedQuantity,
    MAX(dr.ReceiptDate) AS LastReceiptDate
FROM dbo.PurchaseOrders AS po
INNER JOIN dbo.Suppliers AS s
    ON s.PartnerID = po.SupplierID
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.PartnerID = s.PartnerID
INNER JOIN dbo.PurchaseOrderItems AS poi
    ON poi.OrderID = po.OrderID
INNER JOIN dbo.Materials AS m
    ON m.MaterialID = poi.MaterialID
LEFT JOIN dbo.DeliveryReceiptItems AS dri
    ON dri.OrderItemID = poi.OrderItemID
LEFT JOIN dbo.DeliveryReceipts AS dr
    ON dr.ReceiptID = dri.ReceiptID
GROUP BY
    po.OrderID,
    po.OrderNo,
    po.OrderDate,
    po.OrderStatus,
    bp.LegalName,
    poi.OrderItemID,
    m.MaterialCode,
    m.MaterialName,
    poi.OrderedQuantity,
    poi.ReceivedQuantity;
GO

CREATE OR ALTER FUNCTION dbo.fn_GetRemainingBudget
(
    @DepartmentName NVARCHAR(100),
    @BudgetYear INT,
    @BudgetMonth INT
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @remaining DECIMAL(18, 2);

    SELECT
        @remaining = db.BudgetAmount - ISNULL(SUM(bt.Amount), 0)
    FROM dbo.DepartmentBudgets AS db
    LEFT JOIN dbo.BudgetTransactions AS bt
        ON bt.BudgetID = db.BudgetID
    WHERE db.DepartmentName = @DepartmentName
      AND db.BudgetYear = @BudgetYear
      AND db.BudgetMonth = @BudgetMonth
    GROUP BY db.BudgetAmount;

    RETURN ISNULL(@remaining, 0);
END;
GO

CREATE OR ALTER VIEW dbo.vw_PendingApprovals
AS
SELECT
    aps.ApprovalID,
    aps.TargetTable,
    aps.TargetRecordID,
    aps.StepNo,
    ar.RuleName,
    ug.GroupName AS AssignedGroup,
    COALESCE(pr.RequestNo, po.OrderNo) AS DocumentNo,
    COALESCE(CAST(pr.RequestDate AS DATETIME2(0)), CAST(po.OrderDate AS DATETIME2(0))) AS DocumentDate,
    COALESCE(pr.RequestStatus, po.OrderStatus) AS CurrentStatus,
    COALESCE(reqbp.LegalName, suppbp.LegalName) AS MainPartyName,
    aps.CreatedAt
FROM dbo.ApprovalSteps AS aps
INNER JOIN dbo.ApprovalRules AS ar
    ON ar.ApprovalRuleID = aps.ApprovalRuleID
INNER JOIN dbo.UserGroups AS ug
    ON ug.GroupID = aps.AssignedGroupID
LEFT JOIN dbo.PurchaseRequests AS pr
    ON aps.TargetTable = 'PURCHASE_REQUEST'
   AND pr.RequestID = aps.TargetRecordID
LEFT JOIN dbo.Employees AS reqe
    ON reqe.PartnerID = pr.RequestedByEmployeeID
LEFT JOIN dbo.BusinessPartners AS reqbp
    ON reqbp.PartnerID = reqe.PartnerID
LEFT JOIN dbo.PurchaseOrders AS po
    ON aps.TargetTable = 'PURCHASE_ORDER'
   AND po.OrderID = aps.TargetRecordID
LEFT JOIN dbo.Suppliers AS supp
    ON supp.PartnerID = po.SupplierID
LEFT JOIN dbo.BusinessPartners AS suppbp
    ON suppbp.PartnerID = supp.PartnerID
WHERE aps.ApprovalStatus = 'PENDING';
GO

CREATE OR ALTER VIEW dbo.vw_BudgetUsage
AS
SELECT
    db.BudgetID,
    db.DepartmentName,
    db.BudgetYear,
    db.BudgetMonth,
    db.BudgetAmount,
    db.AlertThresholdPct,
    ISNULL(SUM(bt.Amount), 0) AS CommittedAmount,
    dbo.fn_GetRemainingBudget(db.DepartmentName, db.BudgetYear, db.BudgetMonth) AS RemainingAmount,
    CASE
        WHEN db.BudgetAmount = 0 THEN 0
        ELSE CAST((ISNULL(SUM(bt.Amount), 0) * 100.0) / db.BudgetAmount AS DECIMAL(5, 2))
    END AS UsagePct
FROM dbo.DepartmentBudgets AS db
LEFT JOIN dbo.BudgetTransactions AS bt
    ON bt.BudgetID = db.BudgetID
GROUP BY
    db.BudgetID,
    db.DepartmentName,
    db.BudgetYear,
    db.BudgetMonth,
    db.BudgetAmount,
    db.AlertThresholdPct;
GO

CREATE OR ALTER VIEW dbo.vw_InspectionSummary
AS
SELECT
    qi.InspectionID,
    qi.InspectionNo,
    qi.InspectionDate,
    qi.InspectionStatus,
    dr.ReceiptNo,
    po.OrderNo,
    m.MaterialCode,
    m.MaterialName,
    qii.AcceptedQuantity,
    qii.RejectedQuantity,
    qii.QuarantineQuantity,
    qii.DefectCode,
    qii.ResolutionStatus,
    bp.LegalName AS InspectedBy
FROM dbo.QualityInspectionItems AS qii
INNER JOIN dbo.QualityInspections AS qi
    ON qi.InspectionID = qii.InspectionID
INNER JOIN dbo.DeliveryReceiptItems AS dri
    ON dri.ReceiptItemID = qii.ReceiptItemID
INNER JOIN dbo.DeliveryReceipts AS dr
    ON dr.ReceiptID = qi.ReceiptID
INNER JOIN dbo.PurchaseOrders AS po
    ON po.OrderID = dr.OrderID
INNER JOIN dbo.Materials AS m
    ON m.MaterialID = qii.MaterialID
INNER JOIN dbo.Employees AS e
    ON e.PartnerID = qi.InspectedByEmployeeID
INNER JOIN dbo.BusinessPartners AS bp
    ON bp.PartnerID = e.PartnerID;
GO

CREATE OR ALTER VIEW dbo.vw_OpenVendorClaims
AS
SELECT
    vc.ClaimID,
    vc.ClaimNo,
    vc.ClaimDate,
    vc.ClaimStatus,
    suppbp.LegalName AS SupplierName,
    po.OrderNo,
    qi.InspectionNo,
    m.MaterialCode,
    m.MaterialName,
    vci.ClaimedQuantity,
    vci.UnitPrice,
    CAST(vci.ClaimedQuantity * vci.UnitPrice AS DECIMAL(18, 2)) AS ClaimedLineAmount,
    vc.SettlementAmount,
    vc.ClaimReason
FROM dbo.VendorClaims AS vc
INNER JOIN dbo.Suppliers AS s
    ON s.PartnerID = vc.SupplierID
INNER JOIN dbo.BusinessPartners AS suppbp
    ON suppbp.PartnerID = s.PartnerID
LEFT JOIN dbo.PurchaseOrders AS po
    ON po.OrderID = vc.OrderID
LEFT JOIN dbo.QualityInspections AS qi
    ON qi.InspectionID = vc.InspectionID
INNER JOIN dbo.VendorClaimItems AS vci
    ON vci.ClaimID = vc.ClaimID
INNER JOIN dbo.Materials AS m
    ON m.MaterialID = vci.MaterialID
WHERE vc.ClaimStatus IN ('OPEN', 'SUBMITTED');
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseRequests_SetRequestNo
ON dbo.PurchaseRequests
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE pr
    SET RequestNo = CONCAT('PR-', RIGHT('000000' + CONVERT(VARCHAR(6), pr.RequestID), 6))
    FROM dbo.PurchaseRequests AS pr
    INNER JOIN inserted AS i
        ON i.RequestID = pr.RequestID
    WHERE pr.RequestNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseOffers_SetOfferNo
ON dbo.PurchaseOffers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE po
    SET OfferNo = CONCAT('OF-', RIGHT('000000' + CONVERT(VARCHAR(6), po.OfferID), 6))
    FROM dbo.PurchaseOffers AS po
    INNER JOIN inserted AS i
        ON i.OfferID = po.OfferID
    WHERE po.OfferNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseOrders_SetOrderNo
ON dbo.PurchaseOrders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE po
    SET OrderNo = CONCAT('PO-', RIGHT('000000' + CONVERT(VARCHAR(6), po.OrderID), 6))
    FROM dbo.PurchaseOrders AS po
    INNER JOIN inserted AS i
        ON i.OrderID = po.OrderID
    WHERE po.OrderNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DeliveryReceipts_SetReceiptNo
ON dbo.DeliveryReceipts
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dr
    SET ReceiptNo = CONCAT('GR-', RIGHT('000000' + CONVERT(VARCHAR(6), dr.ReceiptID), 6))
    FROM dbo.DeliveryReceipts AS dr
    INNER JOIN inserted AS i
        ON i.ReceiptID = dr.ReceiptID
    WHERE dr.ReceiptNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_MaterialTransactions_SetTransactionNo
ON dbo.MaterialTransactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE mt
    SET TransactionNo = CONCAT('MT-', RIGHT('000000' + CONVERT(VARCHAR(6), mt.TransactionID), 6))
    FROM dbo.MaterialTransactions AS mt
    INNER JOIN inserted AS i
        ON i.TransactionID = mt.TransactionID
    WHERE mt.TransactionNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseRequests_CreateApprovalSteps
ON dbo.PurchaseRequests
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ApprovalSteps
    (
        ApprovalRuleID,
        TargetTable,
        TargetRecordID,
        StepNo,
        AssignedGroupID,
        ApprovalStatus,
        CreatedAt
    )
    SELECT
        ar.ApprovalRuleID,
        'PURCHASE_REQUEST',
        i.RequestID,
        ar.StepNo,
        ar.GroupID,
        'PENDING',
        SYSDATETIME()
    FROM inserted AS i
    INNER JOIN dbo.ApprovalRules AS ar
        ON ar.TargetTable = 'PURCHASE_REQUEST'
       AND ar.IsActive = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseOrders_CreateApprovalSteps
ON dbo.PurchaseOrders
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.ApprovalSteps
    (
        ApprovalRuleID,
        TargetTable,
        TargetRecordID,
        StepNo,
        AssignedGroupID,
        ApprovalStatus,
        CreatedAt
    )
    SELECT
        ar.ApprovalRuleID,
        'PURCHASE_ORDER',
        i.OrderID,
        ar.StepNo,
        ar.GroupID,
        'PENDING',
        SYSDATETIME()
    FROM inserted AS i
    INNER JOIN dbo.ApprovalRules AS ar
        ON ar.TargetTable = 'PURCHASE_ORDER'
       AND ar.IsActive = 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_MaterialTransactionItems_ApplyInventory
ON dbo.MaterialTransactionItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Delta TABLE
    (
        WarehouseID INT NOT NULL,
        MaterialID INT NOT NULL,
        QtyDelta DECIMAL(18, 2) NOT NULL
    );

    DECLARE @Aggregated TABLE
    (
        WarehouseID INT NOT NULL,
        MaterialID INT NOT NULL,
        QtyDelta DECIMAL(18, 2) NOT NULL
    );

    INSERT INTO @Delta (WarehouseID, MaterialID, QtyDelta)
    SELECT
        mt.WarehouseID,
        i.MaterialID,
        i.Quantity * mtt.StockEffect
    FROM inserted AS i
    INNER JOIN dbo.MaterialTransactions AS mt
        ON mt.TransactionID = i.TransactionID
    INNER JOIN dbo.MaterialTransactionTypes AS mtt
        ON mtt.TransactionTypeID = mt.TransactionTypeID
    UNION ALL
    SELECT
        mt.WarehouseID,
        d.MaterialID,
        -1 * d.Quantity * mtt.StockEffect
    FROM deleted AS d
    INNER JOIN dbo.MaterialTransactions AS mt
        ON mt.TransactionID = d.TransactionID
    INNER JOIN dbo.MaterialTransactionTypes AS mtt
        ON mtt.TransactionTypeID = mt.TransactionTypeID;

    INSERT INTO @Aggregated (WarehouseID, MaterialID, QtyDelta)
    SELECT
        WarehouseID,
        MaterialID,
        SUM(QtyDelta) AS QtyDelta
    FROM @Delta
    GROUP BY WarehouseID, MaterialID
    HAVING SUM(QtyDelta) <> 0;

    IF EXISTS (
        SELECT 1
        FROM @Aggregated AS a
        LEFT JOIN dbo.InventoryBalances AS ib
            ON ib.WarehouseID = a.WarehouseID
           AND ib.MaterialID = a.MaterialID
        WHERE ib.InventoryID IS NULL
          AND a.QtyDelta < 0
    )
    BEGIN
        THROW 51001, 'Inventory cannot go negative for a missing stock record.', 1;
    END;

    UPDATE ib
    SET
        ib.OnHandQuantity = ib.OnHandQuantity + a.QtyDelta,
        ib.LastUpdated = SYSDATETIME()
    FROM dbo.InventoryBalances AS ib
    INNER JOIN @Aggregated AS a
        ON a.WarehouseID = ib.WarehouseID
       AND a.MaterialID = ib.MaterialID;

    INSERT INTO dbo.InventoryBalances
    (
        WarehouseID,
        MaterialID,
        OnHandQuantity,
        ReservedQuantity,
        LastUpdated
    )
    SELECT
        a.WarehouseID,
        a.MaterialID,
        a.QtyDelta,
        0,
        SYSDATETIME()
    FROM @Aggregated AS a
    LEFT JOIN dbo.InventoryBalances AS ib
        ON ib.WarehouseID = a.WarehouseID
       AND ib.MaterialID = a.MaterialID
    WHERE ib.InventoryID IS NULL
      AND a.QtyDelta > 0;

    IF EXISTS (
        SELECT 1
        FROM dbo.InventoryBalances
        WHERE OnHandQuantity < 0
           OR ReservedQuantity > OnHandQuantity
    )
    BEGIN
        THROW 51002, 'Inventory quantity validation failed.', 1;
    END;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_ApprovalSteps_SyncDocumentStatus
ON dbo.ApprovalSteps
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Affected TABLE
    (
        TargetTable VARCHAR(30) NOT NULL,
        TargetRecordID INT NOT NULL,
        PRIMARY KEY (TargetTable, TargetRecordID)
    );

    INSERT INTO @Affected (TargetTable, TargetRecordID)
    SELECT DISTINCT TargetTable, TargetRecordID
    FROM inserted;

    UPDATE pr
    SET RequestStatus =
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_REQUEST'
                  AND aps.TargetRecordID = pr.RequestID
                  AND aps.ApprovalStatus = 'REJECTED'
            ) THEN 'CANCELLED'
            WHEN EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_REQUEST'
                  AND aps.TargetRecordID = pr.RequestID
            ) AND NOT EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_REQUEST'
                  AND aps.TargetRecordID = pr.RequestID
                  AND aps.ApprovalStatus <> 'APPROVED'
            ) THEN 'APPROVED'
            ELSE pr.RequestStatus
        END
    FROM dbo.PurchaseRequests AS pr
    INNER JOIN @Affected AS a
        ON a.TargetTable = 'PURCHASE_REQUEST'
       AND a.TargetRecordID = pr.RequestID;

    UPDATE po
    SET OrderStatus =
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_ORDER'
                  AND aps.TargetRecordID = po.OrderID
                  AND aps.ApprovalStatus = 'REJECTED'
            ) THEN 'CANCELLED'
            WHEN EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_ORDER'
                  AND aps.TargetRecordID = po.OrderID
            ) AND NOT EXISTS (
                SELECT 1
                FROM dbo.ApprovalSteps AS aps
                WHERE aps.TargetTable = 'PURCHASE_ORDER'
                  AND aps.TargetRecordID = po.OrderID
                  AND aps.ApprovalStatus <> 'APPROVED'
            ) THEN 'APPROVED'
            ELSE po.OrderStatus
        END
    FROM dbo.PurchaseOrders AS po
    INNER JOIN @Affected AS a
        ON a.TargetTable = 'PURCHASE_ORDER'
       AND a.TargetRecordID = po.OrderID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_PurchaseOrders_AuditStatusChange
ON dbo.PurchaseOrders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs
    (
        TableName,
        RecordID,
        ActionName,
        OldValue,
        NewValue,
        ChangedByEmployeeID
    )
    SELECT
        'PurchaseOrders',
        i.OrderID,
        'STATUS_CHANGE',
        d.OrderStatus,
        i.OrderStatus,
        COALESCE(i.ApprovedByEmployeeID, i.CreatedByEmployeeID)
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.OrderID = i.OrderID
    WHERE ISNULL(i.OrderStatus, '') <> ISNULL(d.OrderStatus, '');
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Suppliers_SoftDelete
ON dbo.Suppliers
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE bp
    SET IsActive = 0
    FROM dbo.BusinessPartners AS bp
    INNER JOIN deleted AS d
        ON d.PartnerID = bp.PartnerID;

    INSERT INTO dbo.AuditLogs
    (
        TableName,
        RecordID,
        ActionName,
        OldValue,
        NewValue,
        ChangedByEmployeeID
    )
    SELECT
        'Suppliers',
        d.PartnerID,
        'SOFT_DELETE',
        'ACTIVE',
        'INACTIVE',
        NULL
    FROM deleted AS d;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_QualityInspections_SetInspectionNo
ON dbo.QualityInspections
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE qi
    SET InspectionNo = CONCAT('QC-', RIGHT('000000' + CONVERT(VARCHAR(6), qi.InspectionID), 6))
    FROM dbo.QualityInspections AS qi
    INNER JOIN inserted AS i
        ON i.InspectionID = qi.InspectionID
    WHERE qi.InspectionNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_QualityInspectionItems_UpdateReceiptStatus
ON dbo.QualityInspectionItems
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AffectedInspections TABLE
    (
        InspectionID INT PRIMARY KEY
    );

    DECLARE @AffectedReceipts TABLE
    (
        ReceiptID INT PRIMARY KEY
    );

    INSERT INTO @AffectedInspections (InspectionID)
    SELECT DISTINCT InspectionID FROM inserted
    UNION
    SELECT DISTINCT InspectionID FROM deleted;

    INSERT INTO @AffectedReceipts (ReceiptID)
    SELECT DISTINCT qi.ReceiptID
    FROM dbo.QualityInspections AS qi
    INNER JOIN @AffectedInspections AS ai
        ON ai.InspectionID = qi.InspectionID;

    UPDATE qi
    SET InspectionStatus =
        CASE
            WHEN sums.AcceptedQty = 0 AND sums.NonAcceptedQty > 0 THEN 'REJECTED'
            WHEN sums.NonAcceptedQty > 0 THEN 'PARTIAL'
            ELSE 'ACCEPTED'
        END
    FROM dbo.QualityInspections AS qi
    INNER JOIN (
        SELECT
            qii.InspectionID,
            SUM(qii.AcceptedQuantity) AS AcceptedQty,
            SUM(qii.RejectedQuantity + qii.QuarantineQuantity) AS NonAcceptedQty
        FROM dbo.QualityInspectionItems AS qii
        INNER JOIN @AffectedInspections AS ai
            ON ai.InspectionID = qii.InspectionID
        GROUP BY qii.InspectionID
    ) AS sums
        ON sums.InspectionID = qi.InspectionID;

    UPDATE dr
    SET ReceiptStatus =
        CASE
            WHEN sums.AcceptedQty = 0 AND sums.NonAcceptedQty > 0 THEN 'REJECTED'
            WHEN sums.NonAcceptedQty > 0 THEN 'PARTIAL'
            ELSE 'POSTED'
        END
    FROM dbo.DeliveryReceipts AS dr
    INNER JOIN (
        SELECT
            qi.ReceiptID,
            SUM(qii.AcceptedQuantity) AS AcceptedQty,
            SUM(qii.RejectedQuantity + qii.QuarantineQuantity) AS NonAcceptedQty
        FROM dbo.QualityInspections AS qi
        INNER JOIN dbo.QualityInspectionItems AS qii
            ON qii.InspectionID = qi.InspectionID
        INNER JOIN @AffectedReceipts AS ar
            ON ar.ReceiptID = qi.ReceiptID
        GROUP BY qi.ReceiptID
    ) AS sums
        ON sums.ReceiptID = dr.ReceiptID;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_VendorClaims_SetClaimNo
ON dbo.VendorClaims
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vc
    SET ClaimNo = CONCAT('VC-', RIGHT('000000' + CONVERT(VARCHAR(6), vc.ClaimID), 6))
    FROM dbo.VendorClaims AS vc
    INNER JOIN inserted AS i
        ON i.ClaimID = vc.ClaimID
    WHERE vc.ClaimNo IS NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_BudgetTransactions_AuditInsert
ON dbo.BudgetTransactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLogs
    (
        TableName,
        RecordID,
        ActionName,
        OldValue,
        NewValue,
        ChangedByEmployeeID
    )
    SELECT
        'BudgetTransactions',
        i.BudgetTransactionID,
        'INSERT',
        NULL,
        CONCAT(i.TransactionType, ':', CONVERT(VARCHAR(40), i.Amount)),
        i.CreatedByEmployeeID
    FROM inserted AS i;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreatePurchaseRequestWithItem
    @RequestedByEmployeeID INT,
    @WarehouseID INT,
    @NeededByDate DATE,
    @PriorityCode VARCHAR(10),
    @MaterialID INT,
    @RequestedQuantity DECIMAL(18, 2),
    @RequestNotes NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE @RequestID INT;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO dbo.PurchaseRequests
        (
            RequestedByEmployeeID,
            WarehouseID,
            RequestDate,
            NeededByDate,
            RequestStatus,
            PriorityCode,
            RequestNotes
        )
        VALUES
        (
            @RequestedByEmployeeID,
            @WarehouseID,
            CAST(SYSDATETIME() AS DATE),
            @NeededByDate,
            'SUBMITTED',
            @PriorityCode,
            @RequestNotes
        );

        SET @RequestID = SCOPE_IDENTITY();

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
        (
            @RequestID,
            @MaterialID,
            @RequestedQuantity,
            0,
            0,
            'OPEN'
        );

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        RequestID,
        RequestNo,
        RequestStatus
    FROM dbo.PurchaseRequests
    WHERE RequestID = @RequestID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SubmitApprovalDecision
    @ApprovalID INT,
    @DecisionByEmployeeID INT,
    @DecisionStatus VARCHAR(20),
    @DecisionNotes NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE
        @TargetTable VARCHAR(30),
        @TargetRecordID INT,
        @StepNo INT,
        @AssignedGroupID INT,
        @CurrentStatus VARCHAR(20);

    IF @DecisionStatus NOT IN ('APPROVED', 'REJECTED')
    BEGIN
        THROW 51010, 'Decision status must be APPROVED or REJECTED.', 1;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @TargetTable = aps.TargetTable,
            @TargetRecordID = aps.TargetRecordID,
            @StepNo = aps.StepNo,
            @AssignedGroupID = aps.AssignedGroupID,
            @CurrentStatus = aps.ApprovalStatus
        FROM dbo.ApprovalSteps AS aps WITH (UPDLOCK, HOLDLOCK)
        WHERE aps.ApprovalID = @ApprovalID;

        IF @TargetRecordID IS NULL
        BEGIN
            THROW 51011, 'Approval step was not found.', 1;
        END;

        IF @CurrentStatus <> 'PENDING'
        BEGIN
            THROW 51012, 'Approval step has already been decided.', 1;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Employees AS e
            WHERE e.PartnerID = @DecisionByEmployeeID
              AND e.GroupID = @AssignedGroupID
        )
        BEGIN
            THROW 51013, 'Decision employee does not belong to the assigned approval group.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ApprovalSteps AS aps
            WHERE aps.TargetTable = @TargetTable
              AND aps.TargetRecordID = @TargetRecordID
              AND aps.StepNo < @StepNo
              AND aps.ApprovalStatus <> 'APPROVED'
        )
        BEGIN
            THROW 51014, 'Earlier approval steps must be completed first.', 1;
        END;

        UPDATE dbo.ApprovalSteps
        SET
            ApprovalStatus = @DecisionStatus,
            DecisionByEmployeeID = @DecisionByEmployeeID,
            DecisionDate = SYSDATETIME(),
            DecisionNotes = @DecisionNotes
        WHERE ApprovalID = @ApprovalID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        ApprovalID,
        TargetTable,
        TargetRecordID,
        StepNo,
        ApprovalStatus,
        DecisionByEmployeeID,
        DecisionDate
    FROM dbo.ApprovalSteps
    WHERE ApprovalID = @ApprovalID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ApproveOfferAndCreateOrder
    @OfferID INT,
    @ApprovedByEmployeeID INT,
    @RequiredDeliveryDate DATE,
    @OrderNotes NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    DECLARE
        @SupplierID INT,
        @RequestID INT,
        @OrderID INT,
        @OrderTotal DECIMAL(18, 2),
        @RequestDepartment NVARCHAR(100),
        @BudgetID INT,
        @BudgetRemaining DECIMAL(18, 2),
        @OrderDate DATE = CAST(SYSDATETIME() AS DATE),
        @InitialOrderStatus VARCHAR(20);

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @SupplierID = po.SupplierID,
            @RequestID = po.RequestID
        FROM dbo.PurchaseOffers AS po WITH (UPDLOCK, HOLDLOCK)
        WHERE po.OfferID = @OfferID
          AND po.OfferStatus IN ('SUBMITTED', 'ACCEPTED');

        IF @SupplierID IS NULL
        BEGIN
            THROW 51003, 'Offer not found or not available for approval.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.PurchaseOrderItems AS poi
            INNER JOIN dbo.PurchaseOfferItems AS pfi WITH (UPDLOCK, HOLDLOCK)
                ON pfi.OfferItemID = poi.OfferItemID
            WHERE pfi.OfferID = @OfferID
        )
        BEGIN
            THROW 51004, 'This offer has already been converted into an order.', 1;
        END;

        SELECT
            @RequestDepartment = e.DepartmentName
        FROM dbo.PurchaseRequests AS pr
        INNER JOIN dbo.Employees AS e
            ON e.PartnerID = pr.RequestedByEmployeeID
        WHERE pr.RequestID = @RequestID;

        SELECT
            @BudgetID = db.BudgetID
        FROM dbo.DepartmentBudgets AS db
        WHERE db.DepartmentName = @RequestDepartment
          AND db.BudgetYear = YEAR(@OrderDate)
          AND db.BudgetMonth = MONTH(@OrderDate);

        SET @InitialOrderStatus =
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.ApprovalRules
                    WHERE TargetTable = 'PURCHASE_ORDER'
                      AND IsActive = 1
                ) THEN 'DRAFT'
                ELSE 'APPROVED'
            END;

        INSERT INTO dbo.PurchaseOrders
        (
            SupplierID,
            CreatedByEmployeeID,
            ApprovedByEmployeeID,
            OrderDate,
            RequiredDeliveryDate,
            OrderStatus,
            PaymentStatus,
            OrderNotes
        )
        VALUES
        (
            @SupplierID,
            @ApprovedByEmployeeID,
            @ApprovedByEmployeeID,
            @OrderDate,
            @RequiredDeliveryDate,
            @InitialOrderStatus,
            'OPEN',
            @OrderNotes
        );

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO dbo.PurchaseOrderItems
        (
            OrderID,
            OfferItemID,
            RequestItemID,
            MaterialID,
            OrderedQuantity,
            ReceivedQuantity,
            UnitPrice,
            ItemStatus
        )
        SELECT
            @OrderID,
            poi.OfferItemID,
            poi.RequestItemID,
            poi.MaterialID,
            poi.OfferedQuantity,
            0,
            poi.UnitPrice,
            'OPEN'
        FROM dbo.PurchaseOfferItems AS poi WITH (UPDLOCK, HOLDLOCK)
        WHERE poi.OfferID = @OfferID
          AND poi.ItemStatus IN ('QUOTED', 'AWARDED');

        IF @@ROWCOUNT = 0
        BEGIN
            THROW 51005, 'Offer approval requires at least one quote item.', 1;
        END;

        SELECT
            @OrderTotal = SUM(poi.OfferedQuantity * poi.UnitPrice)
        FROM dbo.PurchaseOfferItems AS poi
        WHERE poi.OfferID = @OfferID;

        IF @BudgetID IS NOT NULL
        BEGIN
            SET @BudgetRemaining = dbo.fn_GetRemainingBudget(@RequestDepartment, YEAR(@OrderDate), MONTH(@OrderDate));

            IF @BudgetRemaining < @OrderTotal
            BEGIN
                THROW 51015, 'The budget does not have enough remaining amount for this order.', 1;
            END;

            INSERT INTO dbo.BudgetTransactions
            (
                BudgetID,
                RelatedOrderID,
                TransactionType,
                Amount,
                TransactionNotes,
                CreatedByEmployeeID,
                TransactionDate
            )
            VALUES
            (
                @BudgetID,
                @OrderID,
                'COMMITMENT',
                @OrderTotal,
                CONCAT('Committed by purchase order ', @OrderID),
                @ApprovedByEmployeeID,
                SYSDATETIME()
            );
        END;

        UPDATE dbo.PurchaseOffers
        SET OfferStatus = 'ACCEPTED'
        WHERE OfferID = @OfferID;

        UPDATE dbo.PurchaseOfferItems
        SET ItemStatus = 'AWARDED'
        WHERE OfferID = @OfferID;

        UPDATE pri
        SET
            pri.ApprovedQuantity =
                CASE
                    WHEN pri.ApprovedQuantity < poi.OfferedQuantity THEN poi.OfferedQuantity
                    ELSE pri.ApprovedQuantity
                END,
            pri.ItemStatus = 'SOURCED'
        FROM dbo.PurchaseRequestItems AS pri
        INNER JOIN dbo.PurchaseOfferItems AS poi
            ON poi.RequestItemID = pri.RequestItemID
        WHERE poi.OfferID = @OfferID;

        UPDATE dbo.PurchaseRequests
        SET RequestStatus = 'ORDERED'
        WHERE RequestID = @RequestID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        OrderID,
        OrderNo,
        OrderStatus
    FROM dbo.PurchaseOrders
    WHERE OrderID = @OrderID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordDeliveryAndReceipt
    @OrderID INT,
    @WarehouseID INT,
    @ReceivedByEmployeeID INT,
    @OrderItemID INT,
    @ReceivedQuantity DECIMAL(18, 2),
    @AcceptedQuantity DECIMAL(18, 2),
    @RejectedQuantity DECIMAL(18, 2),
    @InvoiceNo NVARCHAR(50),
    @CarrierName NVARCHAR(100) = NULL,
    @ReceiptNotes NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    DECLARE
        @MaterialID INT,
        @UnitPrice DECIMAL(18, 2),
        @OrderedQuantity DECIMAL(18, 2),
        @CurrentReceived DECIMAL(18, 2),
        @ReceiptID INT,
        @TransactionID INT,
        @TransactionTypeID INT;

    IF @AcceptedQuantity + @RejectedQuantity <> @ReceivedQuantity
    BEGIN
        THROW 51006, 'Accepted quantity plus rejected quantity must equal received quantity.', 1;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @MaterialID = poi.MaterialID,
            @UnitPrice = poi.UnitPrice,
            @OrderedQuantity = poi.OrderedQuantity,
            @CurrentReceived = poi.ReceivedQuantity
        FROM dbo.PurchaseOrderItems AS poi WITH (UPDLOCK, HOLDLOCK)
        WHERE poi.OrderItemID = @OrderItemID
          AND poi.OrderID = @OrderID;

        IF @MaterialID IS NULL
        BEGIN
            THROW 51007, 'Order item not found for delivery posting.', 1;
        END;

        IF @CurrentReceived + @AcceptedQuantity > @OrderedQuantity
        BEGIN
            THROW 51008, 'Accepted quantity exceeds the remaining order quantity.', 1;
        END;

        SELECT
            @TransactionTypeID = TransactionTypeID
        FROM dbo.MaterialTransactionTypes
        WHERE TypeCode = 'PURCHASE_RECEIPT';

        IF @TransactionTypeID IS NULL
        BEGIN
            THROW 51009, 'PURCHASE_RECEIPT transaction type is missing.', 1;
        END;

        INSERT INTO dbo.DeliveryReceipts
        (
            OrderID,
            ReceivedWarehouseID,
            ReceivedByEmployeeID,
            InvoiceNo,
            CarrierName,
            ReceiptDate,
            ReceiptStatus,
            ReceiptNotes
        )
        VALUES
        (
            @OrderID,
            @WarehouseID,
            @ReceivedByEmployeeID,
            @InvoiceNo,
            @CarrierName,
            CAST(SYSDATETIME() AS DATE),
            CASE WHEN @RejectedQuantity > 0 THEN 'PARTIAL' ELSE 'POSTED' END,
            @ReceiptNotes
        );

        SET @ReceiptID = SCOPE_IDENTITY();

        INSERT INTO dbo.DeliveryReceiptItems
        (
            ReceiptID,
            OrderItemID,
            MaterialID,
            ReceivedQuantity,
            AcceptedQuantity,
            RejectedQuantity
        )
        VALUES
        (
            @ReceiptID,
            @OrderItemID,
            @MaterialID,
            @ReceivedQuantity,
            @AcceptedQuantity,
            @RejectedQuantity
        );

        UPDATE dbo.PurchaseOrderItems
        SET
            ReceivedQuantity = ReceivedQuantity + @AcceptedQuantity,
            ItemStatus =
                CASE
                    WHEN ReceivedQuantity + @AcceptedQuantity >= OrderedQuantity THEN 'RECEIVED'
                    ELSE 'PARTIAL'
                END
        WHERE OrderItemID = @OrderItemID;

        INSERT INTO dbo.MaterialTransactions
        (
            TransactionTypeID,
            WarehouseID,
            RelatedOrderID,
            ReferenceReceiptID,
            CreatedByEmployeeID,
            TransactionDate,
            PostingStatus
        )
        VALUES
        (
            @TransactionTypeID,
            @WarehouseID,
            @OrderID,
            @ReceiptID,
            @ReceivedByEmployeeID,
            SYSDATETIME(),
            'POSTED'
        );

        SET @TransactionID = SCOPE_IDENTITY();

        IF @AcceptedQuantity > 0
        BEGIN
            INSERT INTO dbo.MaterialTransactionItems
            (
                TransactionID,
                MaterialID,
                Quantity,
                UnitCost
            )
            VALUES
            (
                @TransactionID,
                @MaterialID,
                @AcceptedQuantity,
                @UnitPrice
            );
        END;

        UPDATE dbo.PurchaseOrders
        SET OrderStatus =
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM dbo.PurchaseOrderItems AS poi
                    WHERE poi.OrderID = @OrderID
                      AND poi.ReceivedQuantity < poi.OrderedQuantity
                      AND poi.ItemStatus <> 'CANCELLED'
                )
                THEN 'PARTIAL'
                ELSE 'RECEIVED'
            END
        WHERE OrderID = @OrderID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        ReceiptID,
        ReceiptNo,
        ReceiptStatus
    FROM dbo.DeliveryReceipts
    WHERE ReceiptID = @ReceiptID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordInspectionResult
    @ReceiptID INT,
    @InspectedByEmployeeID INT,
    @ReceiptItemID INT,
    @AcceptedQuantity DECIMAL(18, 2),
    @RejectedQuantity DECIMAL(18, 2),
    @QuarantineQuantity DECIMAL(18, 2),
    @DefectCode NVARCHAR(50) = NULL,
    @InspectionNotes NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    DECLARE
        @InspectionID INT,
        @MaterialID INT,
        @ReceivedQuantity DECIMAL(18, 2),
        @ExistingInspectedQuantity DECIMAL(18, 2);

    IF @AcceptedQuantity + @RejectedQuantity + @QuarantineQuantity <= 0
    BEGIN
        THROW 51016, 'Inspection quantities must be greater than zero.', 1;
    END;

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @MaterialID = dri.MaterialID,
            @ReceivedQuantity = dri.ReceivedQuantity
        FROM dbo.DeliveryReceiptItems AS dri WITH (UPDLOCK, HOLDLOCK)
        WHERE dri.ReceiptItemID = @ReceiptItemID
          AND dri.ReceiptID = @ReceiptID;

        IF @MaterialID IS NULL
        BEGIN
            THROW 51017, 'Receipt item was not found for inspection.', 1;
        END;

        SELECT
            @ExistingInspectedQuantity = ISNULL(SUM(qii.AcceptedQuantity + qii.RejectedQuantity + qii.QuarantineQuantity), 0)
        FROM dbo.QualityInspectionItems AS qii
        INNER JOIN dbo.QualityInspections AS qi
            ON qi.InspectionID = qii.InspectionID
        WHERE qi.ReceiptID = @ReceiptID
          AND qii.ReceiptItemID = @ReceiptItemID;

        IF @ExistingInspectedQuantity + @AcceptedQuantity + @RejectedQuantity + @QuarantineQuantity > @ReceivedQuantity
        BEGIN
            THROW 51018, 'Inspection quantity exceeds the received quantity for this receipt item.', 1;
        END;

        INSERT INTO dbo.QualityInspections
        (
            ReceiptID,
            InspectedByEmployeeID,
            InspectionDate,
            InspectionStatus,
            InspectionNotes
        )
        VALUES
        (
            @ReceiptID,
            @InspectedByEmployeeID,
            CAST(SYSDATETIME() AS DATE),
            CASE
                WHEN @AcceptedQuantity = 0 AND (@RejectedQuantity + @QuarantineQuantity) > 0 THEN 'REJECTED'
                WHEN (@RejectedQuantity + @QuarantineQuantity) > 0 THEN 'PARTIAL'
                ELSE 'ACCEPTED'
            END,
            @InspectionNotes
        );

        SET @InspectionID = SCOPE_IDENTITY();

        INSERT INTO dbo.QualityInspectionItems
        (
            InspectionID,
            ReceiptItemID,
            MaterialID,
            AcceptedQuantity,
            RejectedQuantity,
            QuarantineQuantity,
            DefectCode,
            ResolutionStatus
        )
        VALUES
        (
            @InspectionID,
            @ReceiptItemID,
            @MaterialID,
            @AcceptedQuantity,
            @RejectedQuantity,
            @QuarantineQuantity,
            @DefectCode,
            'OPEN'
        );

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        InspectionID,
        InspectionNo,
        InspectionStatus
    FROM dbo.QualityInspections
    WHERE InspectionID = @InspectionID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_CreateVendorClaim
    @InspectionItemID INT,
    @CreatedByEmployeeID INT,
    @ClaimedQuantity DECIMAL(18, 2),
    @ClaimReason NVARCHAR(250),
    @SettlementAmount DECIMAL(18, 2) = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

    DECLARE
        @ClaimID INT,
        @SupplierID INT,
        @OrderID INT,
        @InspectionID INT,
        @MaterialID INT,
        @AvailableClaimQty DECIMAL(18, 2),
        @UnitPrice DECIMAL(18, 2);

    BEGIN TRY
        BEGIN TRAN;

        SELECT
            @SupplierID = po.SupplierID,
            @OrderID = po.OrderID,
            @InspectionID = qi.InspectionID,
            @MaterialID = qii.MaterialID,
            @AvailableClaimQty = qii.RejectedQuantity + qii.QuarantineQuantity,
            @UnitPrice = poi.UnitPrice
        FROM dbo.QualityInspectionItems AS qii WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.QualityInspections AS qi
            ON qi.InspectionID = qii.InspectionID
        INNER JOIN dbo.DeliveryReceiptItems AS dri
            ON dri.ReceiptItemID = qii.ReceiptItemID
        INNER JOIN dbo.PurchaseOrderItems AS poi
            ON poi.OrderItemID = dri.OrderItemID
        INNER JOIN dbo.PurchaseOrders AS po
            ON po.OrderID = poi.OrderID
        WHERE qii.InspectionItemID = @InspectionItemID;

        IF @InspectionID IS NULL
        BEGIN
            THROW 51019, 'Inspection item was not found for vendor claim creation.', 1;
        END;

        IF @ClaimedQuantity <= 0 OR @ClaimedQuantity > @AvailableClaimQty
        BEGIN
            THROW 51020, 'Claimed quantity must be positive and cannot exceed the rejected plus quarantine quantity.', 1;
        END;

        INSERT INTO dbo.VendorClaims
        (
            SupplierID,
            OrderID,
            InspectionID,
            ClaimDate,
            ClaimStatus,
            ClaimReason,
            CreatedByEmployeeID,
            SettlementAmount
        )
        VALUES
        (
            @SupplierID,
            @OrderID,
            @InspectionID,
            CAST(SYSDATETIME() AS DATE),
            'SUBMITTED',
            @ClaimReason,
            @CreatedByEmployeeID,
            @SettlementAmount
        );

        SET @ClaimID = SCOPE_IDENTITY();

        INSERT INTO dbo.VendorClaimItems
        (
            ClaimID,
            InspectionItemID,
            MaterialID,
            ClaimedQuantity,
            UnitPrice,
            ResolutionCode
        )
        VALUES
        (
            @ClaimID,
            @InspectionItemID,
            @MaterialID,
            @ClaimedQuantity,
            @UnitPrice,
            NULL
        );

        UPDATE dbo.QualityInspectionItems
        SET ResolutionStatus = 'CLAIMED'
        WHERE InspectionItemID = @InspectionItemID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        THROW;
    END CATCH;

    SELECT
        ClaimID,
        ClaimNo,
        ClaimStatus
    FROM dbo.VendorClaims
    WHERE ClaimID = @ClaimID;
END;
GO

GRANT SELECT ON OBJECT::dbo.vw_ActiveSuppliers TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_CurrentInventory TO warehouse_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_OpenPurchaseRequests TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_SupplierOfferComparison TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_OrderReceiptStatus TO warehouse_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_PendingApprovals TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_BudgetUsage TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_InspectionSummary TO warehouse_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.vw_OpenVendorClaims TO procurement_clerk, warehouse_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.AuditLogs TO reporting_analyst;
GO

GRANT EXECUTE ON OBJECT::dbo.fn_GetInventoryOnHand TO warehouse_clerk, reporting_analyst;
GRANT EXECUTE ON OBJECT::dbo.fn_GetAvailableInventory TO warehouse_clerk, reporting_analyst;
GRANT EXECUTE ON OBJECT::dbo.fn_GetRequestFulfillmentRate TO procurement_clerk, reporting_analyst;
GRANT EXECUTE ON OBJECT::dbo.fn_GetSupplierLastQuotedPrice TO procurement_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.fn_WarehouseReorderAlerts TO warehouse_clerk, reporting_analyst;
GRANT SELECT ON OBJECT::dbo.fn_RequestOfferRanking TO procurement_clerk, reporting_analyst;
GRANT EXECUTE ON OBJECT::dbo.fn_GetRemainingBudget TO procurement_clerk, reporting_analyst;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_CreatePurchaseRequestWithItem TO procurement_clerk;
GRANT EXECUTE ON OBJECT::dbo.usp_SubmitApprovalDecision TO procurement_clerk;
GRANT EXECUTE ON OBJECT::dbo.usp_ApproveOfferAndCreateOrder TO procurement_clerk;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordDeliveryAndReceipt TO warehouse_clerk;
GRANT EXECUTE ON OBJECT::dbo.usp_RecordInspectionResult TO warehouse_clerk;
GRANT EXECUTE ON OBJECT::dbo.usp_CreateVendorClaim TO procurement_clerk, warehouse_clerk;
GO
