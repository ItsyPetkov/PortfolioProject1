--Queries with included and excluded NULL values
SELECT * FROM customers AS C
WHERE C.phone <> 'NULL' --Selecting customers with phone numbers given
--WHERE C.phone = 'NULL' --Selecting customers without phone numbers



--Selecting the customers who ordered mote than once in 2018 and the distance between their first and their last order is more than 0 days
WITH orders_2018 AS(
	SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code,
	O.order_id, O.order_status, O.order_date, O.required_date, O.shipped_date, O.store_id, O.staff_id FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	WHERE O.order_date IN (SELECT O.order_date FROM customers AS C 
							JOIN orders AS O
								ON O.customer_id = C.customer_id
							WHERE O.order_date LIKE '2018%'
							GROUP BY O.order_date
							HAVING COUNT(O.order_date) > 1
							)
), customers_2018 AS(
	SELECT customer_id, DATEDIFF(DAY, MIN(order_date), MAX(order_date)) AS days_between_orders FROM orders_2018 
	GROUP BY customer_id
)
SELECT * FROM customers_2018
WHERE days_between_orders <> 0
ORDER BY customer_id --Ordering here is a personal choice. Depending on the task the following are also possible
--ORDER BY customer_id DESC
--ORDER BY days_between_orders
--ORDER BY days_between_orders DESC



--Categorizing customers based on how much they have ordered in 2017
WITH order_count_2017 AS (
  SELECT C.customer_id, COUNT(O.order_id) AS order_bucket FROM customers C
  JOIN orders AS O
	ON O.customer_id = C.customer_id
  WHERE CAST(O.order_date AS VARCHAR) LIKE '%2017%'
  GROUP BY C.customer_id 
)
SELECT OC.order_bucket, COUNT(DISTINCT C.customer_id) AS customer_count FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_count_2017 AS OC
	ON OC.customer_id = C.customer_id
WHERE CAST(O.order_date AS VARCHAR) LIKE '%2017%'
GROUP BY OC.order_bucket



--Selecting customers with single orders sorted by their ID
SELECT C.customer_id, C.first_name, C.last_name, O.order_id, COUNT(O.order_id) AS num_orders FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
GROUP BY C.customer_id, C.first_name, C.last_name, O.order_id
HAVING COUNT(O.order_id) = 3 --With exactly 3 items in their order
--HAVING COUNT(O.order_id) >= 3 --With at least 3 items in their order
--HAVING COUNT(O.order_id) <= 3 --With at most 3 items in their order
ORDER BY O.order_id ASC --Sort in ascending order, which the default sort
--ORDER BY O.order_id DESC --Sort in descending order



--Selecting order details of customers who have not bought an item from a specific brand
SELECT C.customer_id, O.order_id, O.order_status, O.order_date, O.required_date, O.shipped_date, O.store_id, O.staff_id, OI.product_id FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
WHERE OI.product_id NOT IN (SELECT P.product_id FROM order_items AS OI
							JOIN products AS P
								ON P.product_id = OI.product_id
							JOIN brands AS B
								ON B.brand_id = P.brand_id
							--WHERE B.brand_name = 'Electra' --Anything from the brand_name column can be chosen here se feel free to experiment
							WHERE B.brand_name IN ('Electra', 'Trek', 'Heller')) -- Multiple brands can be specifed as well 



--Selecting the count of customers per state
SELECT DISTINCT (SELECT COUNT(state) FROM customers WHERE state='NY') AS NY_COUNT, (SELECT COUNT(state) FROM customers WHERE state='CA') AS CA_COUNT,
(SELECT COUNT(state) FROM customers WHERE state='TX') AS TX_COUNT FROM customers



--Selecting customers based on wildcards and the city column
SELECT * FROM customers
WHERE city LIKE 'O%'		--Starts with the letter O
--WHERE city NOT LIKE 'O%'		--Does NOT start with the letter O
--WHERE city LIKE '%O'		--Ends with the letter O
--WHERE city NOT LIKE '%O'		--Does NOT end with the letter O
--WHERE city LIKE '%O%'			--Contains the letter O
--WHERE city NOT LIKE '%O%'			--Does NOT contain the letter O
--WHERE city LIKE '__T%'		--The third letter in the name is the letter T
--WHERE city NOT LIKE '__T%'		--The third letter in the name is NOT the letter T
--WHERE city LIKE '[A-E]%'		--The starting letter is anyone from A through E
--WHERE city NOT LIKE '[A-E]%'		--The starting letter is NOT anyone from A through E
--WHERE city LIKE '[AW]%'		--The starting letter is either A or W
--WHERE city NOT LIKE '[AW]%'		--The starting letter is NOT either A or W 
--WHERE city LIKE '[^AW]%'		--The starting letter is NOT either A or W



--Labelling discounts based on their percentage
SELECT C.customer_id AS "(Customer) customer_id", C.first_name AS "(Customer) first_name", C.last_name AS "(Customer) last_name", C.phone AS "(Customer) phone",
C.email AS "(Customer) email", C.street AS "(Customer) street", C.city AS "(Customer) city", C.state AS "(Customer) state", C.zip_code AS "(Customer) zip_code",
O.order_id AS "(Order) order_id", O.order_status AS "(Order) order_status", O.order_date AS "(Order) order_date", O.required_date AS "(Order) required_date",
O.shipped_date AS "(Order) shipped_date", O.store_id AS "(Order) store_id", O.staff_id AS "(Order) staff_id", 
OI.item_id AS "(Order_items) item_id", OI.product_id AS "(Order_items) product_id", OI.quantity AS "(Order_items) quantity",
OI.list_price AS "(Order_items) list_price", OI.discount AS "(Order_items) discount",
CASE 
	WHEN discount = 0.20 THEN 'Decent' --if 20% discount then I consider it a decent discount
	WHEN discount = 0.10 THEN 'Average' --if 10% discount then I consider it an average discount
	ELSE 'Low' --if below 10% then I consider it a low discount
END AS "(Order_items) discount_type" FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id



--Selecting the top five users who have placed the most orders in 2017
SELECT TOP 5 C.customer_id, COUNT(O.order_id) AS total_orders FROM customers AS C --TOP 5 return the first five results from a query
JOIN orders AS O
	ON O.customer_id = C.customer_id
WHERE order_date LIKE '2017%' --Can change this to be 2016 or 2018 or have multiple condtions here
GROUP BY C.customer_id
ORDER BY COUNT(O.order_id) DESC



--Selecting all of the zip codes from the customer table, which do not have duplicates
SELECT C.zip_code FROM customers AS C
WHERE C.zip_code IN (SELECT C.zip_code FROM customers AS C
					GROUP BY C.zip_code
					HAVING COUNT(C.zip_code) = 1 --This line ensures only zip_codes which appear once in the customers table are selected
					--HAVING COUNT(C.zip_code) > 1 --This line ensures only duplicate zip_codes from the customers table are selected
					)



--Selecting the amount each customer saves on their ordered items
WITH discount_amount AS(
	SELECT C.customer_id, OI.list_price, OI.discount, OI.list_price - (OI.list_price * OI.discount) AS discount_price FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	GROUP BY C.customer_id, OI.list_price, OI.discount, OI.item_id
)
SELECT *, list_price - discount_price AS savings_amount FROM discount_amount



--Selecting the top 3 customers with the most completed orders
SELECT TOP 3 C.customer_id, COUNT(O.order_status) AS total_complete_orders FROM customers AS C
JOIN orders O
	ON O.customer_id = C.customer_id
JOIN order_items OI
	ON OI.order_id = O.order_id
WHERE O.order_status = 4 --The number in this WHERE statement can be changed as follows: 1 - Pending, 2- Processing, 3 - Rejected, 4 - Completed
GROUP BY C.customer_id
ORDER BY COUNT(O.order_status) DESC



--Selecting the average quantity of items per customer in 2016
SELECT C.customer_id, O.order_id, ROUND(AVG(CAST(OI.quantity AS DECIMAL(10,2))),2) AS avg_quantity FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
WHERE O.order_date LIKE '2016%' --Can be tweeked to select results for other years
GROUP BY C.customer_id, O.order_id, O.order_date
ORDER BY O.order_date, C.customer_id



--Selecting the managers of each store and their details
SELECT M.staff_id, M.first_name, M.last_name, M.email, M.active, M.store_id, M.manager_id FROM staffs AS E
JOIN staffs AS M
	ON M.staff_id = E.manager_id --SELF join here is crucial as manager are also considered members of staff
WHERE E.manager_id <> 'NULL'
GROUP BY M.staff_id, M.first_name, M.last_name, M.email, M.active, M.store_id, M.manager_id



--Selecting the users who required their order to be delivered the next day after placing it
SELECT C.customer_id FROM customers AS C
JOIN orders O
	ON O.customer_id = C.customer_id
WHERE shipped_date <> 'NULL' AND DATEDIFF(DAY, O.order_date, O.shipped_date) = 1
ORDER BY C.customer_id



--Selecting every customer who have bought 3 individual products while providing their details
WITH customer_items AS(
	SELECT C.customer_id, O.order_id, COUNT(OI.item_id) AS total_items FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	GROUP BY C.customer_id, O.order_id
)
SELECT C.customer_id, O.order_id, OI.product_id, P.product_name, P.list_price FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
JOIN customer_items AS CI
	ON CI.customer_id = C.customer_id AND CI.order_id = O.order_id
JOIN products AS P
	ON P.product_id = OI.product_id
WHERE CI.total_items = 3 --Content of the query can change based on this line



--Selecting the distance between chapest and most expensive product for each year
SELECT model_year, MAX(list_price) - MIN(list_price) AS difference FROM products
GROUP BY model_year
ORDER BY MAX(list_price) - MIN(list_price) DESC



--Selecting each customer, their order and the compressed mean of the cost per order
SELECT C.customer_id, O.order_id, ROUND(SUM(OI.quantity*OI.list_price)/SUM(OI.list_price),1) AS compressed_mean FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
GROUP BY C.customer_id, O.order_id



--Selecting the discount price for each customer
SELECT C.customer_id, OI.list_price, OI.discount, OI.list_price - (OI.list_price * OI.discount) AS discount_price FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
GROUP BY C.customer_id, OI.list_price, OI.discount, OI.item_id



--Selecting the customer and adding curreny to their price
SELECT C.customer_id, O.order_id, OI.item_id, '$ ' + CAST(OI.list_price AS VARCHAR) + ' dollars' FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id



--Selecting the percentage of items sent to different stores in 2018
WITH items_per_stores AS(
	SELECT ST.store_id, SUM(quantity) AS total_items FROM stocks AS ST
	JOIN products AS P
		ON P.product_id = ST.product_id
	WHERE P.model_year = 2018
	GROUP BY ST.store_id
)
SELECT ST.store_id, ST.product_id, ST.quantity, ROUND((CAST(ST.quantity AS DECIMAL (20,4))/CAST(IPS.total_items AS DECIMAL (20,4)))*100.0,2) AS item_percent FROM stocks AS ST
JOIN products AS P
	ON P.product_id = ST.product_id
JOIN items_per_stores AS IPS
	ON IPS.store_id = ST.store_id
WHERE P.model_year = 2018
GROUP BY ST.store_id, ST.product_id, ST.quantity, IPS.total_items