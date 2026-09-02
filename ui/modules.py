MODULES = [
    {
        "key": "dashboard",
        "title": "Dashboard",
        "description": "High-level KPIs, current inventory, and order receipt status.",
    },
    {
        "key": "suppliers",
        "title": "Suppliers",
        "description": "Supplier master data, contacts, and quotation analytics.",
    },
    {
        "key": "requests",
        "title": "Purchase Requests",
        "description": "Request listing and atomic request creation transaction.",
    },
    {
        "key": "offers_orders",
        "title": "Offers and Orders",
        "description": "Offer comparison and offer-to-order approval transaction.",
    },
    {
        "key": "warehouse",
        "title": "Warehouse Operations",
        "description": "Receipts, inventory balances, reorder alerts, and stock updates.",
    },
    {
        "key": "administration",
        "title": "Administration",
        "description": "Audit logs, roles, and query gallery for reporting.",
    },
    {
        "key": "approval_workflow",
        "title": "Approval Workflow",
        "description": "Pending approvals, document workflow, and decision entry.",
    },
    {
        "key": "budget_tracking",
        "title": "Budget Tracking",
        "description": "Department budgets, committed spend, and remaining balance analytics.",
    },
    {
        "key": "quality_control",
        "title": "Quality Control",
        "description": "Inspection summaries and receipt-level quality decisions.",
    },
    {
        "key": "vendor_claims",
        "title": "Vendor Claims",
        "description": "Supplier claim tracking for rejected or quarantined receipts.",
    },
]


OUTER_JOIN_QUERIES = {
    "left_inventory": {
        "label": "Left Outer Join - materials with optional inventory",
        "sql": """
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
""".strip(),
    },
    "right_suppliers": {
        "label": "Right Outer Join - suppliers with or without offers",
        "sql": """
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
""".strip(),
    },
    "full_request_order": {
        "label": "Full Outer Join - request items and order items",
        "sql": """
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
""".strip(),
    },
}


DASHBOARD_QUERIES = {
    "Open Requests": "SELECT COUNT(*) AS TotalCount FROM dbo.PurchaseRequests WHERE RequestStatus IN ('DRAFT', 'SUBMITTED', 'APPROVED');",
    "Active Suppliers": "SELECT COUNT(*) AS TotalCount FROM dbo.vw_ActiveSuppliers;",
    "Open Orders": "SELECT COUNT(*) AS TotalCount FROM dbo.PurchaseOrders WHERE OrderStatus IN ('APPROVED', 'PARTIAL');",
    "Low Stock Alerts": "SELECT COUNT(*) AS TotalCount FROM dbo.vw_CurrentInventory WHERE AvailableQuantity <= ReorderLevel;",
    "Pending Approvals": "SELECT COUNT(*) AS TotalCount FROM dbo.vw_PendingApprovals;",
    "Open Claims": "SELECT COUNT(*) AS TotalCount FROM dbo.vw_OpenVendorClaims;",
}
