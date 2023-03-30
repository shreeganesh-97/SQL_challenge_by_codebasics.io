use gdb023;

select * from dim_customer;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;

# 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT DISTINCT
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC';


/* 2. What is the percentage of unique product increase in 2021 vs. 2020? 
The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg
*/

with cte as
( 
SELECT 
    COUNT(DISTINCT CASE
            WHEN fiscal_year = 2020 THEN product_code
        END) AS unique_products_2020,
    COUNT(DISTINCT CASE
            WHEN fiscal_year = 2021 THEN product_code
        END) AS unique_products_2021
FROM
    fact_sales_monthly
)
SELECT 
    *,
    ROUND(((unique_products_2021 - unique_products_2020) / unique_products_2020) * 100,
            2) AS percentage_chg
FROM
    cte;

/* 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields, segment product_count
*/
SELECT 
    segment, COUNT(DISTINCT product_code) AS count_of_products
FROM
    dim_product
GROUP BY segment
ORDER BY count_of_products DESC;


/* 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields, segment product_count_2020 product_count_2021 difference
*/

with cte1 as
(
SELECT 
    p.segment, COUNT(distinct s.product_code) AS counts_2020
FROM
    fact_sales_monthly s
        INNER JOIN
    dim_product p ON s.product_code = p.product_code
WHERE
    fiscal_year = 2020
GROUP BY s.fiscal_year , p.segment
),
cte2 as
(
SELECT 
    p.segment, COUNT(distinct s.product_code) AS counts_2021
FROM
    fact_sales_monthly s
        INNER JOIN
    dim_product p ON s.product_code = p.product_code
WHERE
    fiscal_year = 2021
GROUP BY s.fiscal_year , p.segment
)
SELECT 
    *, (counts_2021 - counts_2020) AS difference
FROM
    cte1
        INNER JOIN
    cte2 USING (segment)
ORDER BY difference DESC;

select segment, count(distinct s.product_code) from dim_product p inner join fact_sales_monthly s on p.product_code=s.product_code
where fiscal_year=2020
group by segment;

/* 5. Get the products that have the highest and lowest manufacturing costs. 
The final output should contain these fields, product_code product manufacturing_cost
*/

with cte as 
(
SELECT 
    c.product_code, p.product, manufacturing_cost, row_number() over(order by manufacturing_cost desc) as rn1
FROM
    fact_manufacturing_cost c
        INNER JOIN
    dim_product p ON c.product_code = p.product_code),
cte1 as (
SELECT 
    c.product_code, p.product, manufacturing_cost, row_number() over(order by manufacturing_cost asc) as rn2
FROM
    fact_manufacturing_cost c
        INNER JOIN
    dim_product p ON c.product_code = p.product_code)
SELECT 
    product_code, product, manufacturing_cost
FROM
    cte
WHERE
    rn1 = 1 
UNION SELECT 
    product_code, product, manufacturing_cost
FROM
    cte1
WHERE
    rn2 = 1;
    
/* 
6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. 
The final output contains these fields, customer_code customer average_discount_percentage 
*/

SELECT 
    c.customer_code,
    c.customer,
    AVG(pre_invoice_discount_pct) AS average_discount_percentage
FROM
    dim_customer c
        INNER JOIN
    fact_pre_invoice_deductions d ON c.customer_code = d.customer_code
WHERE
    market = 'India' AND fiscal_year = 2021
GROUP BY c.customer_code , c.customer
ORDER BY avg_discount DESC
LIMIT 5;

/*
7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
The final report contains these columns: Month Year Gross sales Amount 
*/

SELECT 
    MONTH(s.date) AS month,
    s.fiscal_year,
    ROUND(SUM((s.sold_quantity * g.gross_price))) AS gross_sales_amount
FROM
    fact_sales_monthly s
        INNER JOIN
    dim_customer c USING (customer_code)
        INNER JOIN
    fact_gross_price g ON s.product_code = g.product_code
        AND s.fiscal_year = g.fiscal_year
WHERE
    customer = 'Atliq Exclusive'
GROUP BY MONTH(s.date) , s.fiscal_year
ORDER BY fiscal_year ASC , month ASC;

/* 8. In which quarter of 2020, got the maximum total_sold_quantity? 
The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity
*/

with cte as(
select sold_quantity, case when month(date) = 1 or month(date) = 2 or month(date) = 3 then 'Q1'
			   when month(date) = 4 or month(date) = 5 or month(date) = 6 then 'Q2'
			   when month(date) = 7 or month(date) = 8 or month(date) = 9 then 'Q3'
			   when month(date) = 10 or month(date) = 11 or month(date) = 12 then 'Q4' end as quarters
        from fact_sales_monthly
        where fiscal_year=2020)
select quarters, sum(sold_quantity) as total_sold_quantity from cte
group by quarters
order by total_sold_quantity desc
limit 1;

/*
9. Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? 
The final output contains these fields, channel gross_sales_mln percentage
*/

with cte as
(
SELECT 
    c.channel, round(sum(sold_quantity*gross_price)/1000000)  as gross_sales_mln
FROM
    fact_sales_monthly s
        INNER JOIN
    dim_customer c USING (customer_code)
        INNER JOIN
    fact_gross_price g ON s.product_code = g.product_code
        AND s.fiscal_year = g.fiscal_year
where s.fiscal_year=2021
group by c.channel)
select *, round((gross_sales_mln/(select sum(gross_sales_mln) from cte))*100) as Percentage from cte
order by Percentage desc;

/*
10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
The final output contains these fields, division product_code product total_sold_quantity rank_order
*/
with cte as 
(
SELECT 
    division,
    s.product_code,
    p.product,
    SUM(sold_quantity) AS Total_sold_quantity
FROM
    fact_sales_monthly s
        INNER JOIN
    dim_product p USING (product_code)
WHERE
    s.fiscal_year = 2021
GROUP BY division , s.product_code , p.product
),
cte2 as 
(select *, row_number() over(partition by division order by Total_sold_quantity desc) as rank_order from cte)
SELECT 
    *
FROM
    cte2
WHERE
    rank_order <= 3;




