WITH sale_base AS (
    SELECT *
        , FIRST_VALUE(InvoiceDate) OVER (PARTITION BY CustomerID ORDER BY InvoiceDate) as first_order_date
    FROM online_retail_raw tb1
    WHERE CustomerID IS NOT NULL
)
, cohort_by_customer AS (
    SELECT *, DATEDIFF(MONTH, first_order_month, purchase_month) AS months_since_first_purchase
    FROM (
        SELECT CustomerID
            , convert(varchar, DATEADD(MONTH, DATEDIFF(MONTH, 0,first_order_date ), 0), 23)  AS first_order_month
            , convert(varchar, DATEADD(MONTH, DATEDIFF(MONTH, 0,InvoiceDate ), 0), 23)  AS purchase_month
        FROM sale_base
        GROUP BY CustomerID
            , convert(varchar, DATEADD(MONTH, DATEDIFF(MONTH, 0,InvoiceDate ), 0), 23)
            , convert(varchar, DATEADD(MONTH, DATEDIFF(MONTH, 0,first_order_date ), 0), 23)  
    ) t
)

SELECT first_order_month AS cohort_month, purchase_month, months_since_first_purchase, COUNT(DISTINCT CustomerID) AS num_customers
FROM cohort_by_customer
GROUP BY first_order_month, purchase_month, months_since_first_purchase




