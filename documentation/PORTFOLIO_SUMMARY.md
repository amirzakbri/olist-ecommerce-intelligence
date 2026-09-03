# Portfolio Summary

## Project title

Olist E-Commerce Revenue and Order Intelligence

## Website description

Built a PostgreSQL-to-Power BI analytics project using Olist's historical Brazilian e-commerce dataset. Modeled nine relational tables, implemented ten analytical SQL queries using joins, CTEs, ranking and window functions, and documented data-quality and payment-reconciliation findings. A three-page Power BI report explores executive KPIs, revenue drivers, customer purchase frequency, and delivery/review outcomes. The delivered-order analysis covers 96,478 orders and R$13.22 million in merchandise value. Reproducible loading/export scripts, reporting extracts, metric definitions, an ERD, and report screenshots are included.

## Short project card

PostgreSQL and Power BI analysis of 96,478 delivered Olist orders, with R$13.22M in merchandise value, revenue-driver rankings, customer segmentation, and delivery-quality comparisons. Includes documented reconciliation and reproducible SQL workflows.

## Resume bullet

- Built a PostgreSQL and Power BI e-commerce analytics portfolio project covering 99,441 source orders; modeled nine tables, developed ten analytical SQL queries, reconciled delivered merchandise value to R$13.22M, and created a three-page report with documented data-quality controls.

## Key findings to discuss

- Health and Beauty leads delivered category merchandise value at R$1,233,131.72.
- Sao Paulo (SP) leads customer-state merchandise value at R$5,067,633.16.
- Repeat shoppers account for 2,801 of 93,358 purchasing customers (3.00%) within the observed window.
- Late reviewed deliveries average 2.57 versus 4.29 for on-time/early deliveries; low-review rates are 53.99% versus 9.19%.

These are descriptive findings, not measured business impact. Do not claim the project increased revenue, improved retention, reduced returns, or proved that delays caused poor reviews. The data does not include verified returns, profit, or customer acquisition costs.

## What a visitor can inspect

- [Executive Overview](../screenshots/01_executive_overview.png)
- [Revenue Drivers](../screenshots/02_revenue_drivers.png)
- [Customer and Delivery Quality](../screenshots/03_customer_delivery_quality.png)
- [Analytical SQL](../sql/02_analysis.sql)
- [Validation report](VALIDATION_REPORT.md)
- [Power BI model and refresh notes](../powerbi/README.md)

## Publication handoff

The local package is prepared; publication is controlled by the project owner.

1. Review the Git diff and staged-file list before committing. Include the documentation, source code, six aggregate reporting CSVs, and three screenshots. Keep raw CSVs, credentials, database dumps, and unrelated files out of the repository.
2. Create or select the intended GitHub repository and push the local project there. No repository URL is assumed in this package.
3. Verify that README images and relative documentation links render on GitHub.
4. Use the website description above on the portfolio page and link to the actual GitHub repository after publication.
5. Screenshots can demonstrate the report without Power BI sign-in. Add an interactive link only after deciding its audience and verifying access; a workspace URL is not automatically public.

The repository does not include a PBIX/PBIP backup, and GitHub does not host a live Power BI report simply by receiving CSVs or screenshots. The live report remains in Power BI Service unless separately exported or shared by the owner.
