# E-Commerce Returns & Revenue Leakage Analysis

## Tools Used
Python | MS SQL Server | Power BI

## Dataset
Amazon India Sales 2022 — Kaggle (55K+ orders)

## Key Findings
→ Overall cancellation rate: 14.21%
→ ₹11.83M in revenue lost to cancellations
→ Merchant fulfilment cancels at 17.47% vs Amazon FBA at 12.79%



## How to Run
1. Run amazon_india_eda_phase1.py to generate amazon_cleaned.csv
2. Import CSV into MS SQL Server
3. Run amazon_sql_queries.sql to create views
4. Open amazon_sales_report.pbix and refresh data source
