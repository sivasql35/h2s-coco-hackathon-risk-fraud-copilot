import os
import streamlit as st

st.set_page_config(
    page_title="Risk, Fraud & Regulatory Copilot",
    page_icon=":shield:",
    layout="wide",
)

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=120)
def load_executive_summary():
    return conn.query("SELECT * FROM RISK_COPILOT.CURATED.V_EXECUTIVE_SUMMARY")


@st.cache_data(ttl=120)
def load_fraud_alerts():
    return conn.query("""
        SELECT ALERT_ID, ACCOUNT_ID, CUSTOMER_ID, FULL_NAME, SEGMENT,
               KYC_RISK_RATING, TYPOLOGY, RISK_SCORE, RECOMMENDED_ACTION,
               ROUND(INFLOW_AMT_48H) AS INFLOW_48H_INR,
               ROUND(OUTFLOW_AMT_48H) AS OUTFLOW_48H_INR,
               ARRAY_TO_STRING(FLAG_NAMES, ', ') AS RED_FLAGS
        FROM RISK_COPILOT.CURATED.DT_FRAUD_ALERTS
        ORDER BY RISK_SCORE DESC
    """)


@st.cache_data(ttl=120)
def load_lcr():
    return conn.query("""
        SELECT AS_OF_DATE, LCR_PCT, LCR_STRESS_S1_PCT, LCR_STATUS,
               ROUND(HQLA_STOCK / 1e7) AS HQLA_CR,
               ROUND(NET_CASH_OUTFLOWS_30D / 1e7) AS NET_OUTFLOWS_CR,
               ROUND(NET_OUT_1_7D / 1e7) AS GAP_1_7D_CR,
               ROUND(NET_OUT_8_14D / 1e7) AS GAP_8_14D_CR,
               ROUND(NET_OUT_15_30D / 1e7) AS GAP_15_30D_CR
        FROM RISK_COPILOT.CURATED.DT_LCR_DAILY
        ORDER BY AS_OF_DATE
    """)


@st.cache_data(ttl=120)
def load_credit_ews():
    return conn.query("""
        SELECT LOAN_ID, CUSTOMER_ID, FULL_NAME, SEGMENT, PRODUCT, INDUSTRY,
               ASSET_CLASS, IFRS9_STAGE, DPD, OUTSTANDING, UTILIZATION_PCT,
               EWS_TRIGGER_COUNT, EWS_ACTION
        FROM RISK_COPILOT.CURATED.DT_LOAN_EWS
        ORDER BY DPD DESC, OUTSTANDING DESC
    """)


@st.cache_data(ttl=120)
def load_concentration():
    return conn.query("SELECT * FROM RISK_COPILOT.CURATED.V_INDUSTRY_CONCENTRATION ORDER BY SHARE_PCT DESC")


@st.cache_data(ttl=120)
def load_cases():
    return conn.query("""
        SELECT CASE_ID, ALERT_ID, ACCOUNT_ID, CUSTOMER_ID, TYPOLOGY,
               RISK_SCORE, STATUS, ACTION_TAKEN, CREATED_BY,
               CREATED_AT, REVIEWED_BY, REVIEW_DECISION
        FROM RISK_COPILOT.APP.CASES
        ORDER BY CREATED_AT DESC
    """)


@st.cache_data(ttl=120)
def load_validation():
    return conn.query("SELECT * FROM RISK_COPILOT.APP.V_VALIDATION_RESULTS")


# -- Header --
st.title(":shield: Risk, Fraud & Regulatory Copilot")
st.caption("Executive Dashboard — Synthetic Data")

# Refresh button
if st.button("Refresh Data", type="secondary"):
    load_executive_summary.clear()
    load_fraud_alerts.clear()
    load_lcr.clear()
    load_credit_ews.clear()
    load_concentration.clear()
    load_cases.clear()
    load_validation.clear()
    st.rerun()

# -- Tabs --
tab_exec, tab_fraud, tab_lcr, tab_credit, tab_cases = st.tabs(
    ["Executive Summary", "Fraud Alerts", "Liquidity (LCR)", "Credit EWS", "Cases & Validation"]
)

# =====================================================
# TAB 1: Executive Summary
# =====================================================
with tab_exec:
    with st.spinner("Loading executive summary..."):
        summary = load_executive_summary()

    if summary.empty:
        st.warning("No executive summary data available.")
    else:
        row = summary.iloc[0]

        with st.container(horizontal=True):
            st.metric("Open Alerts", int(row["TOTAL_OPEN_ALERTS"]), border=True)
            st.metric("Freeze Alerts", int(row["CRITICAL_FREEZE_ALERTS"]), border=True)
            st.metric("Pending SARs", int(row["PENDING_SAR_CASES"]), border=True)
            st.metric("Filed SARs", int(row["FILED_SAR_CASES"]), border=True)

        with st.container(horizontal=True):
            exposure = row["TOTAL_48H_OUTFLOW_EXPOSURE_INR"]
            st.metric(
                "48h Outflow Exposure",
                f"INR {exposure / 1e7:.1f} Cr" if exposure else "INR 0",
                border=True,
            )
            lcr_val = row["LATEST_LCR_PCT"]
            lcr_status = row["LATEST_LCR_STATUS"]
            delta_color = "normal" if lcr_val and lcr_val >= 110 else "inverse"
            st.metric(
                "Latest LCR",
                f"{lcr_val:.1f}%" if lcr_val else "N/A",
                delta=lcr_status,
                delta_color=delta_color,
                border=True,
            )
            npa = row["GROSS_NPA_PCT"]
            st.metric("Gross NPA %", f"{npa:.2f}%" if npa else "N/A", border=True)
            sma = row["SMA_EXPOSURE_INR"]
            st.metric(
                "SMA Exposure",
                f"INR {sma / 1e7:.1f} Cr" if sma else "INR 0",
                border=True,
            )

# =====================================================
# TAB 2: Fraud Alerts
# =====================================================
with tab_fraud:
    with st.spinner("Loading fraud alerts..."):
        alerts = load_fraud_alerts()

    if alerts.empty:
        st.info("No fraud alerts currently active.")
    else:
        col_f1, col_f2, col_f3 = st.columns(3)
        with col_f1:
            typology_filter = st.multiselect(
                "Typology", alerts["TYPOLOGY"].unique().tolist(), default=alerts["TYPOLOGY"].unique().tolist()
            )
        with col_f2:
            action_filter = st.multiselect(
                "Action", alerts["RECOMMENDED_ACTION"].unique().tolist(), default=alerts["RECOMMENDED_ACTION"].unique().tolist()
            )
        with col_f3:
            min_score = st.slider("Min Risk Score", 0, 100, 0)

        filtered = alerts[
            (alerts["TYPOLOGY"].isin(typology_filter))
            & (alerts["RECOMMENDED_ACTION"].isin(action_filter))
            & (alerts["RISK_SCORE"] >= min_score)
        ]

        with st.container(horizontal=True):
            st.metric("Filtered Alerts", len(filtered), border=True)
            st.metric("Avg Risk Score", f"{filtered['RISK_SCORE'].mean():.0f}" if len(filtered) > 0 else "N/A", border=True)
            st.metric(
                "Total Outflow 48h",
                f"INR {filtered['OUTFLOW_48H_INR'].sum() / 1e7:.1f} Cr" if len(filtered) > 0 else "INR 0",
                border=True,
            )

        with st.container(border=True):
            st.subheader("Alert Details")
            st.dataframe(
                filtered,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "RISK_SCORE": st.column_config.ProgressColumn("Risk Score", min_value=0, max_value=100, format="%d"),
                    "INFLOW_48H_INR": st.column_config.NumberColumn("Inflow 48h (INR)", format="%.0f"),
                    "OUTFLOW_48H_INR": st.column_config.NumberColumn("Outflow 48h (INR)", format="%.0f"),
                },
            )

        col_c1, col_c2 = st.columns(2)
        with col_c1:
            with st.container(border=True):
                st.subheader("Alerts by Typology")
                typo_counts = filtered.groupby("TYPOLOGY").size().reset_index(name="COUNT")
                st.bar_chart(typo_counts, x="TYPOLOGY", y="COUNT")
        with col_c2:
            with st.container(border=True):
                st.subheader("Alerts by Action")
                action_counts = filtered.groupby("RECOMMENDED_ACTION").size().reset_index(name="COUNT")
                st.bar_chart(action_counts, x="RECOMMENDED_ACTION", y="COUNT")

# =====================================================
# TAB 3: Liquidity (LCR)
# =====================================================
with tab_lcr:
    with st.spinner("Loading LCR data..."):
        lcr_data = load_lcr()

    if lcr_data.empty:
        st.info("No LCR data available.")
    else:
        latest = lcr_data.iloc[-1]
        status = latest["LCR_STATUS"]
        status_emoji = {"GREEN": ":large_green_circle:", "AMBER_ALCO": ":large_orange_circle:", "RED_CFP_TRIGGER": ":red_circle:", "REGULATORY_BREACH": ":rotating_light:"}.get(
            status, ":white_circle:"
        )

        with st.container(horizontal=True):
            st.metric("LCR", f"{latest['LCR_PCT']:.1f}%", border=True)
            st.metric("Stress LCR (S1)", f"{latest['LCR_STRESS_S1_PCT']:.1f}%", border=True)
            st.metric(f"Status {status_emoji}", status, border=True)
            st.metric("HQLA Stock", f"INR {latest['HQLA_CR']:.0f} Cr", border=True)

        col_l1, col_l2 = st.columns(2)
        with col_l1:
            with st.container(border=True):
                st.subheader("LCR Trend (30 Days)")
                chart_df = lcr_data[["AS_OF_DATE", "LCR_PCT", "LCR_STRESS_S1_PCT"]].copy()
                chart_df = chart_df.rename(columns={"LCR_PCT": "LCR %", "LCR_STRESS_S1_PCT": "Stress LCR %"})
                st.line_chart(chart_df, x="AS_OF_DATE", y=["LCR %", "Stress LCR %"])

        with col_l2:
            with st.container(border=True):
                st.subheader("Liquidity Gap Buckets (INR Cr)")
                gap_data = {
                    "Bucket": ["1-7D", "8-14D", "15-30D"],
                    "Net Outflows (Cr)": [float(latest["GAP_1_7D_CR"]), float(latest["GAP_8_14D_CR"]), float(latest["GAP_15_30D_CR"])],
                }
                st.bar_chart(gap_data, x="Bucket", y="Net Outflows (Cr)")

        with st.container(border=True):
            st.subheader("Daily LCR Data")
            st.dataframe(lcr_data, use_container_width=True, hide_index=True)

# =====================================================
# TAB 4: Credit EWS
# =====================================================
with tab_credit:
    with st.spinner("Loading credit EWS data..."):
        ews = load_credit_ews()
        conc = load_concentration()

    if ews.empty:
        st.info("No loan EWS data available.")
    else:
        total_outstanding = ews["OUTSTANDING"].sum()
        npa_outstanding = ews[ews["ASSET_CLASS"] == "NPA"]["OUTSTANDING"].sum()
        sma_outstanding = ews[ews["DPD"].between(1, 90)]["OUTSTANDING"].sum()

        with st.container(horizontal=True):
            st.metric("Total Loans", len(ews), border=True)
            st.metric("Total Outstanding", f"INR {total_outstanding / 1e7:.0f} Cr", border=True)
            st.metric("Gross NPA %", f"{100 * npa_outstanding / total_outstanding:.2f}%" if total_outstanding else "N/A", border=True)
            st.metric("SMA Exposure", f"INR {sma_outstanding / 1e7:.0f} Cr", border=True)

        col_e1, col_e2 = st.columns(2)
        with col_e1:
            with st.container(border=True):
                st.subheader("Asset Classification")
                class_counts = ews.groupby("ASSET_CLASS").size().reset_index(name="COUNT")
                st.bar_chart(class_counts, x="ASSET_CLASS", y="COUNT")

        with col_e2:
            with st.container(border=True):
                st.subheader("Industry Concentration")
                if not conc.empty:
                    st.dataframe(
                        conc,
                        use_container_width=True,
                        hide_index=True,
                        column_config={
                            "SHARE_PCT": st.column_config.ProgressColumn("Share %", min_value=0, max_value=30, format="%.1f%%"),
                        },
                    )

        # EWS filter
        ews_filter = st.selectbox("Filter by EWS Action", ["ALL"] + sorted(ews["EWS_ACTION"].unique().tolist()))
        filtered_ews = ews if ews_filter == "ALL" else ews[ews["EWS_ACTION"] == ews_filter]

        with st.container(border=True):
            st.subheader(f"Loan Book ({len(filtered_ews)} loans)")
            st.dataframe(
                filtered_ews,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "DPD": st.column_config.NumberColumn("DPD", format="%d"),
                    "OUTSTANDING": st.column_config.NumberColumn("Outstanding (INR)", format="%.0f"),
                    "UTILIZATION_PCT": st.column_config.ProgressColumn("Utilization %", min_value=0, max_value=100, format="%.0f%%"),
                },
            )

# =====================================================
# TAB 5: Cases & Validation
# =====================================================
with tab_cases:
    case_tab, val_tab = st.tabs(["Investigation Cases", "Validation Suite"])

    with case_tab:
        with st.spinner("Loading cases..."):
            cases = load_cases()

        if cases.empty:
            st.info("No investigation cases yet. Use the Cortex Agent to generate SAR drafts.")
        else:
            with st.container(horizontal=True):
                st.metric("Total Cases", len(cases), border=True)
                st.metric("Pending Review", len(cases[cases["STATUS"] == "PENDING_REVIEW"]), border=True)
                st.metric("Approved for Filing", len(cases[cases["STATUS"] == "APPROVED_FOR_FILING"]), border=True)
                st.metric("Closed (No STR)", len(cases[cases["STATUS"] == "CLOSED_NO_STR"]), border=True)

            status_filter = st.multiselect("Filter by Status", cases["STATUS"].unique().tolist(), default=cases["STATUS"].unique().tolist())
            filtered_cases = cases[cases["STATUS"].isin(status_filter)]

            with st.container(border=True):
                st.subheader("Case List")
                st.dataframe(filtered_cases, use_container_width=True, hide_index=True)

    with val_tab:
        with st.spinner("Running validation suite..."):
            validation = load_validation()

        if validation.empty:
            st.info("No validation results available.")
        else:
            passed = len(validation[validation["RESULT"] == "PASS"])
            failed = len(validation[validation["RESULT"] == "FAIL"])

            with st.container(horizontal=True):
                st.metric("Total Tests", len(validation), border=True)
                st.metric("Passed", passed, border=True)
                st.metric("Failed", failed, border=True)
                pct = 100 * passed / len(validation) if len(validation) > 0 else 0
                st.metric("Pass Rate", f"{pct:.0f}%", border=True)

            with st.container(border=True):
                st.subheader("Test Results")
                st.dataframe(
                    validation,
                    use_container_width=True,
                    hide_index=True,
                    column_config={
                        "RESULT": st.column_config.TextColumn("Result"),
                    },
                )
