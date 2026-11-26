# Olist E-commerce Sales Analysis

End-to-end analysis of the Brazilian e-commerce marketplace **Olist** (2016–2018): SQL schema design, sales and customer metrics, ABC and RFM analysis, delivery-delay impact on reviews, and an interactive Power BI dashboard.

**Tools:** PostgreSQL (pgAdmin), SQL (CTEs, window functions), Power BI

## Dataset

Public [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce): about 99K orders across 9 related tables (orders, order items, customers, products, sellers, payments, reviews, geolocation, category translation).

## Key findings

| Metric | Result |
|---|---|
| Orders / total revenue | 99.4K orders, 13.6M revenue |
| Average order value (AOV) | 137.75 |
| Items per order | 1.14 |
| Repeat purchase rate | **3.0%** (2,801 of 93,358 customers ordered more than once) |
| Category concentration (ABC) | Top 6 of 74 categories give about **45%** of revenue (leader: `beleza_saude`) |
| Late deliveries | 8.1% of orders arrive after the promised date |
| Average delivery time | 12 days |
| Review score, on-time orders | **4.29** (88,653 orders) |
| Review score, late orders | **2.57** (7,700 orders), about 40% lower |
| Revenue by state | São Paulo (SP) is the largest market by a wide margin |
| Payment methods | Credit card is about 78% of payment value |

**Takeaways**
- Customer retention is very low: almost all buyers purchase once, so repeat-purchase growth is the main opportunity.
- Late delivery is the clearest driver of bad reviews: a late order is rated 1.7 points lower on average.
- Revenue is concentrated in a few categories and in São Paulo.

## Database schema

9 tables with primary and composite keys: `orders`, `order_items`, `customers`, `products`, `sellers`, `payment`, `order_review`, `geolocation`, `category_name`. The full DDL is in the first block of [`queries.sql`](queries.sql).

## SQL queries

All queries are in [`queries.sql`](queries.sql). Only `delivered` orders are used for business metrics.

| # | Query | Techniques |
|---|---|---|
| 2.1–2.2 | Order totals, monthly revenue | `JOIN`, `DATE_TRUNC`, `GROUP BY` |
| 2.3–2.4 | Revenue, orders and AOV by category (with English names) | `LEFT JOIN`, `COALESCE` |
| 2.5 | AOV and items per order | subquery |
| 3.1 | Monthly revenue, orders, AOV, items sold | aggregation |
| 3.2 | Sales by state | `JOIN`, aggregation |
| 3.3 | Top-20 sellers | `ORDER BY`, `LIMIT` |
| 3.4 | Repeat purchase rate | CTE, `CASE` |
| 3.5 | ABC analysis of categories | CTE, window function `SUM() OVER` |
| 3.6 | Revenue share of the top 10% of sellers | `NTILE(10)` |
| 4.1 | Delivery time and late-delivery rate by state | `EXTRACT`, `CASE` |
| 4.2 | Review score: late vs on-time orders | `CASE`, `JOIN` |
| 5.1 | RFM scoring of customers | CTE, `NTILE(5)` |

## Power BI dashboard

Two pages with State, Period and Order Status filters.

**Sales:** orders, total revenue, AOV, average rating, revenue by month, payment methods, revenue by state, top 10 categories.

![Sales page](<img width="932" height="520" alt="image" src="https://github.com/user-attachments/assets/a54a9d5f-bc03-472f-bf5e-74d2d8ba17d8" />
)

**Logistics:** delivery days and late-arrival share by state, orders by status, review score for on-time vs late orders.

![Logistics page](<img width="931" height="519" alt="image" src="https://github.com/user-attachments/assets/cd457cc0-9edb-4849-a899-55e3c556b3a4" />
)

The Power BI file (`.pbix`) is available in [Releases](../../releases).

## How to run

1. Create a PostgreSQL database and load the Olist CSV files into the tables created by the DDL block.
2. Run `queries.sql` block by block in pgAdmin or `psql`.
3. Open the `.pbix` file in Power BI Desktop and point it to your database.

## Limitations and next steps

- RFM currently assigns scores only (1–5 per dimension); next step is to map them to named segments (for example Champions, Loyal, At Risk).
- Recency in RFM should be measured from the last order date in the dataset, not from today's date.
- Dashboard figures and SQL results differ slightly in the late-delivery share (8.1% vs about 8.0%) because of different filters.
