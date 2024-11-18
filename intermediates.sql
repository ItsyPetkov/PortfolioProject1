--Selecting the details of each third item in a users order
WITH customer_order_third_item AS (
	SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code, O.order_id, O.order_status, O.order_date, O.required_date, O.shipped_date,
	O.store_id, O.staff_id, OI.item_id, OI.product_id, OI.quantity, OI.list_price, OI.discount, P.product_name, P.brand_id, P.category_id, P.model_year, B.brand_name, CT.category_name,
	DENSE_RANK() OVER(PARTITION BY C.customer_id, O.order_id ORDER BY OI.item_id) AS d_rank FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN products AS P
		ON P.product_id = OI.product_id
	JOIN brands AS B
		ON B.brand_id = P.brand_id
	JOIN categories AS CT
		ON CT.category_id = P.category_id
)
SELECT customer_id, order_id, product_id, list_price, product_name, brand_name, category_name FROM customer_order_third_item
WHERE d_rank = 3 --This value can be changed to reflect other items in a customer's order



--Selecting the second most expensive item in a customer's order
WITH customer_order_details AS(
	SELECT C.customer_id, O.order_id, OI.product_id, OI.list_price,
	ROW_NUMBER() OVER(PARTITION BY C.customer_id, O.order_id ORDER BY OI.list_price DESC) AS row_num FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
)
SELECT customer_id, order_id, product_id, list_price FROM customer_order_details
WHERE row_num = 2



--Selecting a 3-day rolling average of the price for all items in a customers order
SELECT C.customer_id, O.order_id, OI.item_id, OI.list_price,
ROUND(AVG(OI.list_price) OVER(PARTITION BY C.customer_id, O.order_id ORDER BY OI.list_price ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS threeDay_rolling_average FROM customers C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id



--Selecting the top 2 most expensive products from every year
WITH most_expensive_products AS(
	SELECT P.product_id, P.product_name, P.brand_id, P.category_id, P.model_year, P.list_price, B.brand_name, C.category_name,
	RANK() OVER(PARTITION BY P.model_year ORDER BY P.list_price DESC) AS rank FROM products AS P
	JOIN brands AS B
		ON B.brand_id = P.brand_id
	JOIN categories AS C
		ON C.category_id = P.category_id
)
SELECT product_id, product_name, brand_id, category_id, model_year, list_price, brand_name, category_name FROM most_expensive_products
WHERE rank <=2



--Selecting the top 3 most expensive brands for each year
WITH most_expensive_brands AS(
	SELECT P.product_id, P.product_name, P.brand_id, P.category_id, P.model_year, P.list_price, B.brand_name,
	DENSE_RANK() OVER(PARTITION BY P.model_year ORDER BY P.list_price DESC) AS d_rank FROM products AS P
	JOIN brands AS B
		ON B.brand_id = P.brand_id
)
SELECT brand_id, model_year, list_price, brand_name FROM most_expensive_brands
WHERE d_rank <= 3



--Selecting the 5 five cheapest brands on average based on their discounts for each year
WITH discount_prices AS(
	SELECT OI.product_id, P.model_year, OI.list_price, OI.discount, OI.list_price - (OI.list_price * OI.discount) AS discount_price, B.brand_name FROM order_items AS OI
	JOIN products AS P
		ON P.product_id = OI.product_id AND P.list_price = OI.list_price
	JOIN brands AS B
		ON B.brand_id = P.brand_id
), rolling_revenue_brands AS(
	SELECT *,
	SUM(discount_price) OVER(PARTITION BY model_year, brand_name) AS brand_revenue FROM discount_prices
), ranked_brands AS(
	SELECT brand_name, model_year, brand_revenue,
	DENSE_RANK() OVER(PARTITION BY model_year ORDER BY model_year, brand_revenue ASC) AS d_rank FROM rolling_revenue_brands
	GROUP BY brand_name, model_year, brand_revenue
)
SELECT brand_name, model_year AS year, brand_revenue FROM ranked_brands
WHERE d_rank <= 5



--Selecting the 3 brands who have the most losses per each year
WITH discount_prices AS(
	SELECT OI.product_id, P.model_year, OI.list_price, OI.discount, OI.list_price - (OI.list_price * OI.discount) AS discount_price, B.brand_name FROM order_items AS OI
	JOIN products AS P
		ON P.product_id = OI.product_id AND P.list_price = OI.list_price
	JOIN brands AS B
		ON B.brand_id = P.brand_id
), rolling_revenue_brands AS(
	SELECT *,
	SUM(discount_price) OVER(PARTITION BY model_year, brand_name) AS brand_discount_revenue,
	SUM(list_price) OVER(PARTITION BY model_year, brand_name) AS brand_total_revenue FROM discount_prices
), rolling_losses_brands AS(
	SELECT *, brand_discount_revenue/brand_total_revenue AS brand_rate_of_loss, 
	brand_total_revenue - brand_discount_revenue AS brand_losses FROM rolling_revenue_brands
), ranked_brands AS(
	SELECT brand_name, model_year AS year, brand_total_revenue, ROUND(brand_discount_revenue, 2) AS brand_discount_revenue,
	ROUND(brand_rate_of_loss, 2) AS brand_rate_of_loss, brand_losses,
	DENSE_RANK() OVER(PARTITION BY model_year ORDER BY model_year, brand_losses DESC) AS d_rank FROM rolling_losses_brands
	GROUP BY brand_name, model_year, brand_total_revenue, brand_discount_revenue, brand_rate_of_loss, brand_losses
)
SELECT brand_name, year, brand_total_revenue, brand_discount_revenue, brand_rate_of_loss, brand_losses FROM ranked_brands
WHERE d_rank <= 3



--Calculating the rate and the percentage of all possible order states
WITH total_orders AS(
	SELECT DISTINCT order_status, 
	CASE
		WHEN order_status = 1 THEN 'Pending'
		WHEN order_status = 2 THEN 'Processing'
		WHEN order_status = 3 THEN 'Rejected'
		ELSE 'Completed'
	END AS status_description,
	COUNT(order_id) OVER() AS total_orders,
	COUNT(order_id) OVER(PARTITION BY order_status) AS total_orders_per_state FROM orders
	GROUP BY order_status, order_id
)
SELECT *, ROUND(CAST(total_orders_per_state AS NUMERIC)/CAST(total_orders AS NUMERIC), 4) AS order_status_rate,
ROUND(CAST(total_orders_per_state AS NUMERIC)/CAST(total_orders AS NUMERIC) * 100.00, 2) AS order_status_percentage FROM total_orders AS TOS
ORDER BY order_status



--Selecting customers who have bought a product from every category
WITH customer_order_products_categories AS(
	SELECT C.customer_id, O.order_id, OI.item_id, OI.product_id, P.category_id, CT.category_name,
	MAX(P.category_id) OVER() AS max_category, 
	DENSE_RANK() OVER(PARTITION BY C.customer_id ORDER BY P.category_id) AS d_rank FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN products as P
		ON P.product_id = OI.product_id
	JOIN categories AS CT
		ON CT.category_id = P.category_id
)
SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code FROM customer_order_products_categories AS COPC
JOIN customers AS C
	ON C.customer_id = COPC.customer_id
WHERE d_rank = max_category



--Selecting the total order price for customers who have made them on days with an even or odd numbers
WITH my_cte AS(
	SELECT C.customer_id, O.order_id, O.order_date, OI.item_id, OI.list_price,
	SUM(OI.list_price) OVER(PARTITION BY C.customer_id ORDER BY order_date) AS date_sum FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	WHERE DAY(O.order_date) % 2 = 0 --Take into consideration only even days
), my_cte2 AS(
	SELECT C.customer_id, O.order_id, O.order_date, OI.item_id, OI.list_price,
	SUM(OI.list_price) OVER(PARTITION BY C.customer_id ORDER BY order_date) AS date_sum FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	WHERE DAY(O.order_date) % 2 <> 0 ----Take into consideration only odd days
)
SELECT * FROM my_cte
UNION
SELECT * FROM my_cte2
ORDER BY customer_id, date_sum



--Selecting an order of products where the position of the current and the next products are flipped 
WITH my_cte AS(
	SELECT *,
	ROW_NUMBER() OVER(ORDER BY P.product_id) AS row_num,
	MAX(P.product_id) OVER() AS max_product_id FROM products AS P
), my_cte2 AS(
	SELECT 
  CASE
    WHEN product_id = max_product_id AND max_product_id % 2 <> 0 THEN product_id
    WHEN row_num % 2 <> 0 THEN product_id + 1
    WHEN row_num % 2 = 0 THEN product_id - 1
  END AS corrected_product_id, *
  FROM my_cte
)
SELECT corrected_product_id, product_name, brand_id, category_id, model_year, list_price FROM my_cte2
ORDER BY corrected_product_id



--Selecting the total products purchased per each shipped order
SELECT DISTINCT O.order_id, O.order_date, C.customer_id, 
COUNT(O.order_id) OVER(PARTITION BY OI.item_id ORDER BY O.shipped_date) AS purchase_count FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
WHERE O.shipped_date <> 'NULL'
ORDER BY O.order_date



--Selecting the total qunatity of products sold per order where the customer has purchased at least 5 individual items in total 
WITH total_items_per_order AS(
	SELECT *,
	SUM(OI.quantity) OVER(PARTITION BY OI.order_id) AS quantity_sum FROM order_items AS OI
)
SELECT order_id, quantity_sum FROM total_items_per_order
WHERE item_id = 5 AND quantity_sum >= 5
ORDER BY order_id, quantity_sum DESC



--Calculating the percentage of incomplete orders
WITH total_orders AS(
	SELECT DISTINCT order_status, 
	CASE
		WHEN order_status = 1 THEN 'Pending'
		WHEN order_status = 2 THEN 'Processing'
		WHEN order_status = 3 THEN 'Rejected'
		ELSE 'Completed'
	END AS status_description,
	COUNT(order_id) OVER() AS total_orders,
	COUNT(order_id) OVER(PARTITION BY order_status) AS total_orders_per_state FROM orders
	GROUP BY order_status, order_id
), order_rates_and_percentages AS(
	SELECT *, ROUND(CAST(total_orders_per_state AS NUMERIC)/CAST(total_orders AS NUMERIC), 4) AS order_status_rate,
	ROUND(CAST(total_orders_per_state AS NUMERIC)/CAST(total_orders AS NUMERIC) * 100.00, 2) AS order_status_percentage FROM total_orders AS TOS
), incomplete_orders AS(
	SELECT *, SUM(order_status_percentage) OVER() AS total_orders_percentage FROM order_rates_and_percentages
	WHERE order_status IN (1,2,3)
), complete_orders AS(
	SELECT *, SUM(order_status_percentage) OVER() AS total_orders_percentage FROM order_rates_and_percentages
	WHERE order_status = 4
)
SELECT * FROM incomplete_orders
UNION 
SELECT * FROM complete_orders
ORDER BY order_status



--Selecting the most successful store and its manager
WITH my_cte AS(
	SELECT O.customer_id, O.order_id, O.store_id, OI.item_id, OI.list_price, M.staff_id, M.first_name, M.last_name, M.email, M.phone FROM orders AS O
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN staffs AS E
		ON E.staff_id = O.staff_id
	JOIN staffs AS M
		ON CAST(M.staff_id AS VARCHAR) = E.manager_id
), my_cte2 AS(
	SELECT *, SUM(list_price) OVER(PARTITION BY store_id) AS total_revenue_per_store FROM my_cte
), my_cte3 AS(
	SELECT TOP 1 store_id, staff_id, first_name, last_name, email, phone, total_revenue_per_store, 
	DENSE_RANK() OVER(ORDER BY total_revenue_per_store DESC) as d_rank FROM my_cte2
	GROUP BY store_id, staff_id, first_name, last_name, email, phone, total_revenue_per_store
)
SELECT MC3.store_id, S.store_name, S.phone AS store_phone, S.email AS store_email, S.street, S.city, S.state, S.zip_code, MC3.total_revenue_per_store AS total_revenue,
MC3.staff_id AS manager_id, MC3.first_name, MC3.last_name, MC3.email AS manager_email, MC3.phone AS manager_phone FROM my_cte3 AS MC3
JOIN stores AS S
	ON S.store_id = MC3.store_id



--Selecting the mode of products per each order
WITH my_cte AS(
  SELECT OI.quantity, MAX(OI.quantity) OVER() AS max_quantity FROM order_items AS OI
  GROUP BY OI.quantity
), my_cte2 AS(
	SELECT OI.order_id, OI.product_id, OI.item_id AS mode_per_order FROM order_items AS OI
	JOIN my_cte AS MC
		ON MC.quantity = OI.quantity
	WHERE OI.quantity = MC.max_quantity
) 
SELECT DISTINCT order_id, MAX(mode_per_order) OVER(PARTITION BY order_id) AS max_mode FROM my_cte2



--Creating a view which can be used in BI Tools such as Tableau and Power-BI
CREATE VIEW Most_successful_manager_store AS
WITH my_cte AS(
	SELECT O.customer_id, O.order_id, O.store_id, OI.item_id, OI.list_price, M.staff_id, M.first_name, M.last_name, M.email, M.phone FROM orders AS O
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN staffs AS E
		ON E.staff_id = O.staff_id
	JOIN staffs AS M
		ON CAST(M.staff_id AS VARCHAR) = E.manager_id
), my_cte2 AS(
	SELECT *, SUM(list_price) OVER(PARTITION BY store_id) AS total_revenue_per_store FROM my_cte
), my_cte3 AS(
	SELECT TOP 1 store_id, staff_id, first_name, last_name, email, phone, total_revenue_per_store, 
	DENSE_RANK() OVER(ORDER BY total_revenue_per_store DESC) as d_rank FROM my_cte2
	GROUP BY store_id, staff_id, first_name, last_name, email, phone, total_revenue_per_store
)
SELECT MC3.store_id, S.store_name, S.phone AS store_phone, S.email AS store_email, S.street, S.city, S.state, S.zip_code, MC3.total_revenue_per_store AS total_revenue,
MC3.staff_id AS manager_id, MC3.first_name, MC3.last_name, MC3.email AS manager_email, MC3.phone AS manager_phone FROM my_cte3 AS MC3
JOIN stores AS S
	ON S.store_id = MC3.store_id