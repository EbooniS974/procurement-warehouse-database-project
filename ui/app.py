from __future__ import annotations

from datetime import date, timedelta
from pathlib import Path
import sys

import streamlit as st


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from ui.db import get_configuration_status_message, is_configured, query_dataframe
from ui.modules import DASHBOARD_QUERIES, MODULES, OUTER_JOIN_QUERIES


st.set_page_config(page_title="Procurement and Warehouse Database", layout="wide")


def _run_table(sql: str, params: tuple[object, ...] = ()) -> None:
    if not is_configured():
        st.info(f"{get_configuration_status_message()} The SQL shown below is what this module executes.")
        st.code(sql, language="sql")
        return

    try:
        frame = query_dataframe(sql, params)
    except Exception as exc:  # pragma: no cover - UI runtime path
        st.error(str(exc))
        st.code(sql, language="sql")
        return

    st.dataframe(frame, use_container_width=True, hide_index=True)
    st.caption(f"{len(frame)} row(s)")


def _render_dashboard() -> None:
    st.title("Dashboard")
    st.write("Summary widgets are backed by views and SQL queries from the project schema.")

    columns = st.columns(len(DASHBOARD_QUERIES))
    for column, (label, sql) in zip(columns, DASHBOARD_QUERIES.items()):
        with column:
            if is_configured():
                try:
                    frame = query_dataframe(sql)
                    value = int(frame.iloc[0, 0]) if not frame.empty else 0
                    st.metric(label, value)
                except Exception as exc:  # pragma: no cover - UI runtime path
                    st.metric(label, "ERR")
                    st.caption(str(exc))
            else:
                st.metric(label, "N/A")
                st.caption("Configure DB connection")

    st.subheader("Current Inventory")
    _run_table(
        """
SELECT TOP 20 *
FROM dbo.vw_CurrentInventory
ORDER BY WarehouseCode, MaterialCode;
""".strip()
    )

    st.subheader("Order Receipt Status")
    _run_table(
        """
SELECT TOP 20 *
FROM dbo.vw_OrderReceiptStatus
ORDER BY OrderDate DESC, OrderNo;
""".strip()
    )


def _render_suppliers() -> None:
    st.title("Suppliers")
    st.write("This module exposes supplier master data, contacts, and quotation-related functions.")

    st.subheader("Active Supplier View")
    _run_table(
        """
SELECT *
FROM dbo.vw_ActiveSuppliers
ORDER BY SupplierCode;
""".strip()
    )

    st.subheader("Last Quoted Price Function")
    material_id = st.number_input("Material ID", min_value=1, value=1, step=1, key="supplier_material_id")
    supplier_id = st.number_input("Supplier ID", min_value=1, value=6, step=1, key="supplier_supplier_id")
    _run_table(
        """
SELECT dbo.fn_GetSupplierLastQuotedPrice(?, ?) AS LastQuotedPrice;
""".strip(),
        (supplier_id, material_id),
    )

    st.subheader("Required RIGHT OUTER JOIN")
    _run_table(OUTER_JOIN_QUERIES["right_suppliers"]["sql"])


def _render_requests() -> None:
    st.title("Purchase Requests")
    st.write("The form below executes the atomic request-creation transaction.")

    with st.form("request_form"):
        requested_by = st.number_input("Requested By Employee ID", min_value=1, value=1, step=1)
        warehouse_id = st.number_input("Warehouse ID", min_value=1, value=1, step=1)
        needed_by = st.date_input("Needed By Date", value=date.today() + timedelta(days=7))
        priority = st.selectbox("Priority", ["LOW", "MEDIUM", "HIGH", "URGENT"], index=2)
        material_id = st.number_input("Material ID", min_value=1, value=1, step=1, key="request_material_id")
        quantity = st.number_input("Requested Quantity", min_value=1.0, value=25.0, step=1.0)
        notes = st.text_input("Request Notes", value="Created from Streamlit UI")
        submitted = st.form_submit_button("Create Request")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_CreatePurchaseRequestWithItem
    @RequestedByEmployeeID = ?,
    @WarehouseID = ?,
    @NeededByDate = ?,
    @PriorityCode = ?,
    @MaterialID = ?,
    @RequestedQuantity = ?,
    @RequestNotes = ?;
""".strip(),
            (requested_by, warehouse_id, needed_by, priority, material_id, quantity, notes),
        )

    st.subheader("Open Purchase Requests")
    _run_table(
        """
SELECT *
FROM dbo.vw_OpenPurchaseRequests
ORDER BY RequestDate DESC, RequestNo;
""".strip()
    )

    st.subheader("Required FULL OUTER JOIN")
    _run_table(OUTER_JOIN_QUERIES["full_request_order"]["sql"])


def _render_offers_orders() -> None:
    st.title("Offers and Orders")
    st.write("This module compares supplier quotations and converts a selected offer into an order.")

    st.subheader("Supplier Offer Comparison View")
    _run_table(
        """
SELECT *
FROM dbo.vw_SupplierOfferComparison
ORDER BY RequestNo, MaterialCode, OfferRank;
""".strip()
    )

    st.subheader("Offer Ranking Function")
    request_item_id = st.number_input("Request Item ID", min_value=1, value=1, step=1, key="offer_ranking_request_item_id")
    _run_table(
        """
SELECT *
FROM dbo.fn_RequestOfferRanking(?)
ORDER BY OfferRank;
""".strip(),
        (request_item_id,),
    )

    with st.form("approve_offer_form"):
        offer_id = st.number_input("Offer ID", min_value=1, value=1, step=1)
        approved_by = st.number_input("Approved By Employee ID", min_value=1, value=1, step=1)
        required_delivery = st.date_input("Required Delivery Date", value=date.today() + timedelta(days=14))
        notes = st.text_input("Order Notes", value="Approved through Streamlit")
        submitted = st.form_submit_button("Approve Offer and Create Order")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_ApproveOfferAndCreateOrder
    @OfferID = ?,
    @ApprovedByEmployeeID = ?,
    @RequiredDeliveryDate = ?,
    @OrderNotes = ?;
""".strip(),
            (offer_id, approved_by, required_delivery, notes),
        )


def _render_warehouse() -> None:
    st.title("Warehouse Operations")
    st.write("Warehouse users can inspect inventory, reorder alerts, and post receipt transactions.")

    st.subheader("Required LEFT OUTER JOIN")
    _run_table(OUTER_JOIN_QUERIES["left_inventory"]["sql"])

    st.subheader("Reorder Alert Function")
    warehouse_id = st.number_input("Warehouse ID for reorder alerts", min_value=1, value=1, step=1, key="warehouse_alert_id")
    _run_table(
        """
SELECT *
FROM dbo.fn_WarehouseReorderAlerts(?)
ORDER BY MaterialCode;
""".strip(),
        (warehouse_id,),
    )

    st.subheader("Inventory On-Hand Function")
    on_hand_warehouse_id = st.number_input("Warehouse ID for on-hand lookup", min_value=1, value=1, step=1, key="warehouse_on_hand_warehouse_id")
    on_hand_material_id = st.number_input("Material ID for on-hand lookup", min_value=1, value=1, step=1, key="warehouse_on_hand_material_id")
    _run_table(
        """
SELECT dbo.fn_GetInventoryOnHand(?, ?) AS OnHandQuantity;
""".strip(),
        (on_hand_warehouse_id, on_hand_material_id),
    )

    with st.form("delivery_form"):
        order_id = st.number_input("Order ID", min_value=1, value=1, step=1)
        receipt_warehouse_id = st.number_input("Receipt Warehouse ID", min_value=1, value=1, step=1)
        received_by = st.number_input("Received By Employee ID", min_value=1, value=2, step=1)
        order_item_id = st.number_input("Order Item ID", min_value=1, value=1, step=1)
        received_quantity = st.number_input("Received Quantity", min_value=1.0, value=10.0, step=1.0)
        accepted_quantity = st.number_input("Accepted Quantity", min_value=0.0, value=10.0, step=1.0)
        rejected_quantity = st.number_input("Rejected Quantity", min_value=0.0, value=0.0, step=1.0)
        invoice_no = st.text_input("Invoice No", value="INV-STREAM-001")
        carrier_name = st.text_input("Carrier Name", value="Demo Logistics")
        notes = st.text_input("Receipt Notes", value="Posted from Streamlit UI")
        submitted = st.form_submit_button("Record Delivery and Receipt")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_RecordDeliveryAndReceipt
    @OrderID = ?,
    @WarehouseID = ?,
    @ReceivedByEmployeeID = ?,
    @OrderItemID = ?,
    @ReceivedQuantity = ?,
    @AcceptedQuantity = ?,
    @RejectedQuantity = ?,
    @InvoiceNo = ?,
    @CarrierName = ?,
    @ReceiptNotes = ?;
""".strip(),
            (
                order_id,
                receipt_warehouse_id,
                received_by,
                order_item_id,
                received_quantity,
                accepted_quantity,
                rejected_quantity,
                invoice_no,
                carrier_name,
                notes,
            ),
        )


def _render_administration() -> None:
    st.title("Administration")
    st.write("Reporting, trigger evidence, audit logs, and role-oriented SQL gallery live here.")

    st.subheader("Audit Logs")
    _run_table(
        """
SELECT TOP 50 *
FROM dbo.AuditLogs
ORDER BY ChangedAt DESC, AuditLogID DESC;
""".strip()
    )

    st.subheader("SQL Query Gallery")
    selected_key = st.selectbox(
        "Choose one of the required outer join queries",
        options=list(OUTER_JOIN_QUERIES),
        format_func=lambda key: OUTER_JOIN_QUERIES[key]["label"],
    )
    _run_table(OUTER_JOIN_QUERIES[selected_key]["sql"])

    st.subheader("Security Objects")
    _run_table(
        """
SELECT principal_id, name, type_desc
FROM sys.database_principals
WHERE name IN ('procurement_clerk', 'warehouse_clerk', 'reporting_analyst',
               'procurement_demo', 'warehouse_demo', 'reporting_demo')
ORDER BY type_desc, name;
""".strip()
    )


def _render_approval_workflow() -> None:
    st.title("Approval Workflow")
    st.write("Approval steps are created automatically for requests and orders, then completed here.")

    st.subheader("Pending Approval View")
    _run_table(
        """
SELECT *
FROM dbo.vw_PendingApprovals
ORDER BY TargetTable, TargetRecordID, StepNo;
""".strip()
    )

    with st.form("approval_decision_form"):
        approval_id = st.number_input("Approval ID", min_value=1, value=1, step=1)
        decision_by = st.number_input("Decision By Employee ID", min_value=1, value=1, step=1)
        decision_status = st.selectbox("Decision", ["APPROVED", "REJECTED"])
        decision_notes = st.text_input("Decision Notes", value="Workflow decision recorded from Streamlit")
        submitted = st.form_submit_button("Submit Approval Decision")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_SubmitApprovalDecision
    @ApprovalID = ?,
    @DecisionByEmployeeID = ?,
    @DecisionStatus = ?,
    @DecisionNotes = ?;
""".strip(),
            (approval_id, decision_by, decision_status, decision_notes),
        )


def _render_budget_tracking() -> None:
    st.title("Budget Tracking")
    st.write("Budgets are tracked by department and period, and purchase orders consume budget as commitments.")

    st.subheader("Budget Usage View")
    _run_table(
        """
SELECT *
FROM dbo.vw_BudgetUsage
ORDER BY BudgetYear DESC, BudgetMonth DESC, DepartmentName;
""".strip()
    )

    st.subheader("Remaining Budget Function")
    department_name = st.text_input("Department Name", value="Procurement")
    budget_year = st.number_input("Budget Year", min_value=2024, value=date.today().year, step=1)
    budget_month = st.number_input("Budget Month", min_value=1, max_value=12, value=date.today().month, step=1)
    _run_table(
        """
SELECT dbo.fn_GetRemainingBudget(?, ?, ?) AS RemainingBudget;
""".strip(),
        (department_name, budget_year, budget_month),
    )

    st.subheader("Budget Transactions")
    _run_table(
        """
SELECT TOP 20 *
FROM dbo.BudgetTransactions
ORDER BY TransactionDate DESC, BudgetTransactionID DESC;
""".strip()
    )


def _render_quality_control() -> None:
    st.title("Quality Control")
    st.write("Inspection results are recorded against receipt items and feed claim tracking.")

    st.subheader("Inspection Summary View")
    _run_table(
        """
SELECT *
FROM dbo.vw_InspectionSummary
ORDER BY InspectionDate DESC, InspectionNo;
""".strip()
    )

    with st.form("quality_inspection_form"):
        receipt_id = st.number_input("Receipt ID", min_value=1, value=1, step=1)
        inspected_by = st.number_input("Inspected By Employee ID", min_value=1, value=3, step=1)
        receipt_item_id = st.number_input("Receipt Item ID", min_value=1, value=1, step=1)
        accepted_quantity = st.number_input("Accepted Quantity", min_value=0.0, value=10.0, step=1.0)
        rejected_quantity = st.number_input("Rejected Quantity", min_value=0.0, value=0.0, step=1.0)
        quarantine_quantity = st.number_input("Quarantine Quantity", min_value=0.0, value=0.0, step=1.0)
        defect_code = st.text_input("Defect Code", value="VISUAL_CHECK")
        inspection_notes = st.text_input("Inspection Notes", value="Quality inspection recorded from Streamlit")
        submitted = st.form_submit_button("Record Inspection Result")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_RecordInspectionResult
    @ReceiptID = ?,
    @InspectedByEmployeeID = ?,
    @ReceiptItemID = ?,
    @AcceptedQuantity = ?,
    @RejectedQuantity = ?,
    @QuarantineQuantity = ?,
    @DefectCode = ?,
    @InspectionNotes = ?;
""".strip(),
            (
                receipt_id,
                inspected_by,
                receipt_item_id,
                accepted_quantity,
                rejected_quantity,
                quarantine_quantity,
                defect_code,
                inspection_notes,
            ),
        )


def _render_vendor_claims() -> None:
    st.title("Vendor Claims")
    st.write("Rejected or quarantined inspection quantities can be escalated to supplier claims.")

    st.subheader("Open Vendor Claims View")
    _run_table(
        """
SELECT *
FROM dbo.vw_OpenVendorClaims
ORDER BY ClaimDate DESC, ClaimNo;
""".strip()
    )

    with st.form("vendor_claim_form"):
        inspection_item_id = st.number_input("Inspection Item ID", min_value=1, value=1, step=1)
        created_by = st.number_input("Created By Employee ID", min_value=1, value=1, step=1)
        claimed_quantity = st.number_input("Claimed Quantity", min_value=0.01, value=1.0, step=1.0)
        claim_reason = st.text_input("Claim Reason", value="Supplier claim created from Streamlit")
        settlement_amount = st.number_input("Settlement Amount", min_value=0.0, value=0.0, step=1.0)
        submitted = st.form_submit_button("Create Vendor Claim")

    if submitted:
        _run_table(
            """
EXEC dbo.usp_CreateVendorClaim
    @InspectionItemID = ?,
    @CreatedByEmployeeID = ?,
    @ClaimedQuantity = ?,
    @ClaimReason = ?,
    @SettlementAmount = ?;
""".strip(),
            (
                inspection_item_id,
                created_by,
                claimed_quantity,
                claim_reason,
                settlement_amount,
            ),
        )


RENDERERS = {
    "dashboard": _render_dashboard,
    "suppliers": _render_suppliers,
    "requests": _render_requests,
    "offers_orders": _render_offers_orders,
    "warehouse": _render_warehouse,
    "administration": _render_administration,
    "approval_workflow": _render_approval_workflow,
    "budget_tracking": _render_budget_tracking,
    "quality_control": _render_quality_control,
    "vendor_claims": _render_vendor_claims,
}


st.sidebar.title("Modules")
if not is_configured():
    st.sidebar.warning(get_configuration_status_message())
    st.sidebar.code(
        "\n".join(
            [
                "DB_SERVER=localhost,14333",
                "DB_NAME=ProcurementWarehouseDB",
                "DB_DRIVER={ODBC Driver 18 for SQL Server}",
                "DB_TRUSTED_CONNECTION=no",
                "DB_USERNAME=sa",
                "DB_PASSWORD=CHANGE_ME_LOCAL_PASSWORD",
                "DB_ENCRYPT=yes",
                "DB_TRUST_SERVER_CERTIFICATE=yes",
            ]
        ),
        language="bash",
    )
selected_title = st.sidebar.radio("Select a module", [module["title"] for module in MODULES])
selected_module = next(module for module in MODULES if module["title"] == selected_title)
st.sidebar.caption(selected_module["description"])

RENDERERS[selected_module["key"]]()
