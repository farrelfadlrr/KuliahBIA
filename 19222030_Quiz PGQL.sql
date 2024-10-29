WITH item_sales AS (
    -- Step 1: Calculate total sales and transaction frequency per product
    SELECT item_description AS product,
           SUM(sale_dollars) AS total_sales,
           COUNT(*) AS transaction_frequency
    FROM iowa_drink_sales
    GROUP BY item_description
),
total_sales AS (
    -- Step 2: Calculate total sales and total transaction count across all products
    SELECT SUM(total_sales) AS overall_sales, 
           SUM(transaction_frequency) AS overall_transactions
    FROM item_sales
),
sales_data AS (
    -- Step 3: Calculate share sales, cumulative sales, and assign ABC categories
    SELECT product,
           total_sales,
           total_sales / (SELECT overall_sales FROM total_sales) * 100 AS share_sales,
           SUM(total_sales) OVER (ORDER BY total_sales DESC) AS cumulative_sales,
           CASE
               WHEN SUM(total_sales) OVER (ORDER BY total_sales DESC) >= 80 THEN 'A'
               WHEN SUM(total_sales) OVER (ORDER BY total_sales DESC) >= 80 
                    AND SUM(total_sales) OVER (ORDER BY total_sales DESC) < 95 THEN 'B'
               ELSE 'C'
           END AS sales_category
    FROM item_sales
),
frequency_data AS (
    -- Step 4: Calculate share frequency and cumulative share
    SELECT product,
           transaction_frequency,
           transaction_frequency / (SELECT overall_transactions FROM total_sales) * 100 AS share_frequency,
           SUM(transaction_frequency) OVER (ORDER BY transaction_frequency DESC) AS cumulative_share
    FROM item_sales
),
xyz_data AS (
    -- Step 5: Calculate coefficient of variation and assign XYZ categories
    SELECT item_description AS product,
           AVG(bottles_sold) AS avg_bottles_sold,
           STDDEV(bottles_sold) AS stddev_bottles_sold,
           CASE
               WHEN (STDDEV(bottles_sold) / AVG(bottles_sold)) <= 0.2 THEN 'X'
               WHEN (STDDEV(bottles_sold) / AVG(bottles_sold)) > 0.2 
                    AND (STDDEV(bottles_sold) / AVG(bottles_sold)) <= 0.5 THEN 'Y'
               ELSE 'Z'
           END AS product_category
    FROM iowa_drink_sales
    GROUP BY item_description
),
combined_data AS (
    -- Combine sales data and frequency data to calculate the cumSalesShare * CumTransactionShare
    SELECT s.product,
           s.total_sales AS sales,
           s.share_sales,
           s.cumulative_sales,
           s.sales_category,
           f.transaction_frequency,
           f.share_frequency,
           f.cumulative_share,
           x.product_category,
           (s.cumulative_sales / (SELECT overall_sales FROM total_sales)) * 
           (f.cumulative_share / (SELECT overall_transactions FROM total_sales)) AS cumSalesShare_CumTransactionShare
    FROM sales_data s
    JOIN frequency_data f ON s.product = f.product
    JOIN xyz_data x ON s.product = x.product
)
-- Final query: Assign AX, AY, AZ, BX, BY, BZ, etc., based on the intersection of sales_category and product_category
SELECT *,
       CASE
           WHEN sales_category = 'A' AND product_category = 'X' THEN 'AX'
           WHEN sales_category = 'A' AND product_category = 'Y' THEN 'AY'
           WHEN sales_category = 'A' AND product_category = 'Z' THEN 'AZ'
           WHEN sales_category = 'B' AND product_category = 'X' THEN 'BX'
           WHEN sales_category = 'B' AND product_category = 'Y' THEN 'BY'
           WHEN sales_category = 'B' AND product_category = 'Z' THEN 'BZ'
           WHEN sales_category = 'C' AND product_category = 'X' THEN 'CX'
           WHEN sales_category = 'C' AND product_category = 'Y' THEN 'CY'
           ELSE 'CZ'
       END AS ProductFreq
FROM combined_data
ORDER BY sales DESC;
