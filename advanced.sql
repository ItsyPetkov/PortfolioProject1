--Selecting monthly active users where the required date of their order is set for the next day
WITH my_cte AS(
  SELECT *,
  ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS row_num,
  MONTH(order_date) AS event_month FROM orders
)
SELECT DISTINCT order_date,  COUNT(event_month) AS daily_active_users FROM my_cte
WHERE event_month = MONTH(required_date)-1
GROUP BY order_date



--Expanding columns using recursion to find the median of items per all of the customers' orders
--To do so I first prepare my target columns using a query
--Next I store them in a temp table ready for manipulation
CREATE TABLE #temp_customer_order_item(
	customer_id INT,
	order_id INT,
	item_count INT
)

INSERT INTO #temp_customer_order_item
SELECT C.customer_id, O.order_id, COUNT(OI.item_id) AS item_count FROM customers AS C
JOIN orders AS O
	ON O.customer_id = C.customer_id
JOIN order_items AS OI
	ON OI.order_id = O.order_id
GROUP BY C.customer_id, O.order_id
ORDER BY COUNT(OI.item_id)

WITH searies_expander AS(
	SELECT customer_id, order_id, item_count, 1 AS n FROM #temp_customer_order_item 
    UNION ALL
    SELECT customer_id, order_id, item_count, n + 1 FROM searies_expander
    WHERE n + 1 <= item_count
), my_cte AS(
  SELECT customer_id, order_id, item_count, COUNT(*) OVER() AS searches_count,
  ROW_NUMBER() OVER(ORDER BY customer_id, order_id, item_count) AS row_num FROM searies_expander
), my_cte2 AS(
	SELECT 
	CASE
		WHEN searches_count % 2 = 0 THEN ROUND((CAST((SELECT item_count FROM my_cte WHERE row_num = (searches_count/2)) AS DECIMAL)+CAST((SELECT item_count FROM my_cte WHERE row_num = (searches_count/2)+1)AS DECIMAL))/2.0,1)
		ELSE ROUND((SELECT item_count FROM my_cte WHERE row_num = (searches_count+1)/2), 1)
	END AS median FROM my_cte
)
SELECT DISTINCT CAST(median AS INT) AS item_median FROM my_cte2



--The rest of the queries in this section are applied ONLY
--to temp tables which do not contain data from the RDBMS
--I used in the BASICS,
--the INTERMEDIATES and
--so far in the ADVANCED sections.
--Reason: DATA UNSUITABILITY



--Writing a query to calculate the year-on-year growth rate for the total spend of each product, grouping the results by product ID.
--The output includes the year in ascending order, product ID, current year's spend, previous year's spend and year-on-year growth percentage, rounded to 2 decimal places.
CREATE TABLE #user_transactions(
	transaction_id INT,
	product_id INT,
	spend DECIMAL,
	transaction_date DATETIME
)

INSERT INTO #user_transactions VALUES 
(1341, 123424, 1500.60, '20191231 12:00:00 PM'),
(1423, 123424, 1000.20, '20201231 12:00:00 PM'),
(1623, 123424, 1246.44, '20211231 12:00:00 PM'),
(1322, 123424, 2145.32, '20221231 12:00:00 PM'),
(1344, 234412, 1800.00, '20191231 12:00:00 PM'),
(1435, 234412, 1234.00, '20201231 12:00:00 PM'),
(4325, 234412, 889.50,  '20211231 12:00:00 PM'),
(5233, 234412, 2900.00,	'20221231 12:00:00 PM'),
(2134, 543623, 6450.00,	'20191231 12:00:00 PM'),
(1234, 543623, 5348.12,	'20201231 12:00:00 PM'),
(2423, 543623, 2345.00,	'20211231 12:00:00 PM'),
(1245, 543623, 5680.00,	'20221231 12:00:00 PM')

WITH my_cte AS(
  SELECT YEAR(transaction_date) AS year, product_id, spend AS curr_year_spend,
  RANK() OVER(PARTITION BY product_id ORDER BY transaction_date) AS curr_year_rank FROM #user_transactions
), 
my_cte2 AS(
  SELECT *, curr_year_rank - 1 AS last_year_rank FROM my_cte
), 
my_cte3 AS(
  SELECT product_id, NULL AS last_year_spend, last_year_rank FROM my_cte2
  WHERE curr_year_rank = 1
), 
my_cte4 AS(
  SELECT product_id, CAST(curr_year_spend AS VARCHAR) AS last_year_spend, last_year_rank + 1 AS last_year_rank_plus_one FROM my_cte2
  WHERE curr_year_rank <> 4
), 
my_cte5 AS(
  SELECT * FROM my_cte3
  UNION
  SELECT * FROM my_cte4
), 
my_cte6 AS(
  SELECT *, COUNT(*) OVER(PARTITION BY product_id ORDER BY last_year_rank) AS sorting_count FROM my_cte5
), 
my_cte7 AS(
  SELECT MC2.year, MC2.product_id, MC2.curr_year_spend, MC6.last_year_spend, MC2.last_year_rank FROM my_cte2 AS MC2
  JOIN my_cte6 AS MC6
    ON MC6.product_id = MC2.product_id AND MC6.last_year_rank = MC2.last_year_rank
  GROUP BY MC2.year, MC2.product_id, MC2.curr_year_spend, MC6.last_year_spend, MC2.last_year_rank
)
SELECT year, product_id, curr_year_spend, last_year_spend, 
CASE
  WHEN last_year_rank = 0 THEN NULL
  ELSE ROUND(((curr_year_spend - CAST(last_year_spend AS DECIMAL))/CAST(last_year_spend AS DECIMAL))*100.0,2)
END AS yoy_rate FROM my_cte7
ORDER BY product_id



--Writing a query to find the maximum number of prime and non-prime batches that can be stored in a 500,000 square feet warehouse based on the following criteria:
----Prioritize stocking prime batches
----After accommodating prime items, allocate any remaining space to non-prime batches
--Output contains the item_type with prime_eligible first followed by not_prime, along with the maximum number of batches that can be stocked.
CREATE TABLE #inventory(
	item_id INT,
	item_type VARCHAR(255),
	item_category VARCHAR(255),
	square_footage DECIMAL(10,2)
)

INSERT INTO #inventory VALUES
(1374, 'prime_eligible', 'mini refrigerator', 68.00),
(4245, 'not_prime', 'standing lamp', 26.40),
(5743, 'prime_eligible', 'washing machine',	325.00),
(8543, 'not_prime',	'dining chair', 64.50),
(2556, 'not_prime',	'vase', 15.00),
(2452, 'prime_eligible', 'television', 85.00),
(3255, 'not_prime', 'side table', 22.60),
(1672, 'prime_eligible', 'laptop', 8.50),
(4256, 'prime_eligible', 'wall rack', 55.50),
(6325, 'prime_eligible', 'desktop computer', 13.20)

WITH my_cte AS(
  SELECT *, 
  SUM(square_footage) OVER() AS batch_total_squares, 
  COUNT(item_type) OVER() AS total_items_per_batch 
  FROM #inventory
  WHERE item_type = 'prime_eligible'
), 
my_cte2 AS(
  SELECT *, 
  SUM(square_footage) OVER() AS batch_total_squares, 
  COUNT(item_type) OVER() AS total_items_per_batch 
  FROM #inventory
  WHERE item_type = 'not_prime'
), 
my_cte3 AS(
  SELECT * FROM my_cte
  UNION 
  SELECT * FROM my_cte2
), 
my_cte4 AS(
  SELECT *,
  CASE
    WHEN item_type = 'prime_eligible' THEN (
      SELECT DISTINCT 
      FLOOR(500000.0 / batch_total_squares) * batch_total_squares AS total_occupied_space 
      FROM my_cte3
      WHERE item_type = 'prime_eligible'
    )
    ELSE (
      SELECT DISTINCT 
      500000.0 - FLOOR(500000.0 / batch_total_squares) * batch_total_squares AS total_occupied_space 
      FROM my_cte3
      WHERE item_type = 'prime_eligible'
    )
  END AS total_occupied_space 
  FROM my_cte3
), 
my_cte5 AS(
  SELECT *, 
  CASE
    WHEN item_type = 'prime_eligible' THEN 
      FLOOR(total_occupied_space / batch_total_squares) * total_items_per_batch
    ELSE 
      FLOOR(total_occupied_space / batch_total_squares) * total_items_per_batch
  END AS item_count 
  FROM my_cte4
) 

SELECT DISTINCT item_type, item_count 
FROM my_cte5
ORDER BY item_count DESC;



--Writing a query to update the payment status of Facebook advertisers based on the information in the daily_pay table.
--The output includes the user ID and their current payment status, sorted by the user id.
--The payment status of advertisers is classified into the following categories:
----New: Advertisers who are newly registered and have made their first payment.
----Existing: Advertisers who have made payments in the past and have recently made a current payment.
----Churn: Advertisers who have made payments in the past but have not made any recent payment.
----Resurrect: Advertisers who have not made a recent payment but may have made a previous payment and have made a payment again recently.
CREATE TABLE #advertiser(
	user_id VARCHAR(255),
	status VARCHAR(255)
)

INSERT INTO #advertiser VALUES
('bing', 'NEW'),
('yahoo', 'NEW'),
('alibaba',	'EXISTING'),
('baidu', 'EXISTING'),
('target',	'CHURN'),
('tesla', 'CHURN'),
('morgan',	'RESURRECT'),
('chase',	'RESURRECT')

CREATE TABLE #daily_pay(
	user_id VARCHAR(255),
	paid DECIMAL(10,2)
)

INSERT INTO #daily_pay VALUES
('yahoo', 45.00),
('alibaba',	100.00),
('target', 13.00),
('morgan', 600.00),
('fitdata',	25.00)

WITH my_cte AS(
  SELECT A.user_id AS advertiser_id, 
         A.status AS current_status, 
         DP.user_id AS payer_id, 
         DP.paid 
  FROM #advertiser AS A
  FULL OUTER JOIN #daily_pay AS DP
    ON DP.user_id = A.user_id
), 
my_cte2 AS(
  SELECT 
    CASE
      WHEN advertiser_id IS NULL THEN payer_id
      ELSE advertiser_id
    END AS user_id, 
    current_status, 
    payer_id, 
    paid 
  FROM my_cte
)  

SELECT user_id,
CASE 
  WHEN paid IS NULL THEN 'CHURN'
  WHEN current_status = 'CHURN' AND paid IS NOT NULL THEN 'RESURRECT'
  WHEN current_status IS NULL AND paid IS NOT NULL THEN 'NEW' 
  ELSE 'EXISTING'
END AS new_status 
FROM my_cte2
ORDER BY user_id;



--Given a list of pizza toppings, consider all the possible 3-topping pizzas, and print out the total cost of those 3 toppings. 
--Sort the results with the highest total cost on the top followed by pizza toppings in ascending order.
CREATE TABLE #pizza_toppings(
	topping_name VARCHAR(255),
	ingredient_cost	DECIMAL(10,2)
)

INSERT INTO #pizza_toppings VALUES
('Pepperoni', 0.50),
('Sausage', 0.70),
('Chicken', 0.55),
('Extra Cheese', 0.40),
('Mushrooms', 0.25),
('Green Peppers', 0.20),
('Onions', 0.15),
('Pineapple', 0.25),
('Spinach', 0.30),
('Jalapenos', 0.20)

WITH three_topping_pizza_with_duplicates AS (
  SELECT 
    P.topping_name AS topping_name_1, 
    PP.topping_name AS topping_name_2, 
    PPP.topping_name AS topping_name_3, 
    P.ingredient_cost + PP.ingredient_cost + PPP.ingredient_cost AS total_cost 
  FROM #pizza_toppings AS P
  CROSS JOIN #pizza_toppings AS PP
  CROSS JOIN #pizza_toppings AS PPP
  WHERE P.topping_name <> PP.topping_name 
    AND P.topping_name <> PPP.topping_name 
    AND PP.topping_name <> PPP.topping_name
), 
three_topping_pizza_without_duplicates AS (
  SELECT DISTINCT
    CASE 
      WHEN topping_name_1 <= topping_name_2 AND topping_name_1 <= topping_name_3 THEN topping_name_1
      WHEN topping_name_2 <= topping_name_1 AND topping_name_2 <= topping_name_3 THEN topping_name_2
      ELSE topping_name_3
    END AS topping_name_1,
    CASE
      WHEN topping_name_1 NOT IN (
        CASE 
          WHEN topping_name_1 <= topping_name_2 AND topping_name_1 <= topping_name_3 THEN topping_name_1
          WHEN topping_name_2 <= topping_name_1 AND topping_name_2 <= topping_name_3 THEN topping_name_2
          ELSE topping_name_3
        END
      ) AND topping_name_1 NOT IN (
        CASE 
          WHEN topping_name_1 >= topping_name_2 AND topping_name_1 >= topping_name_3 THEN topping_name_1
          WHEN topping_name_2 >= topping_name_1 AND topping_name_2 >= topping_name_3 THEN topping_name_2
          ELSE topping_name_3
        END
      ) THEN topping_name_1
      WHEN topping_name_2 NOT IN (
        CASE 
          WHEN topping_name_1 <= topping_name_2 AND topping_name_1 <= topping_name_3 THEN topping_name_1
          WHEN topping_name_2 <= topping_name_1 AND topping_name_2 <= topping_name_3 THEN topping_name_2
          ELSE topping_name_3
        END
      ) AND topping_name_2 NOT IN (
        CASE 
          WHEN topping_name_1 >= topping_name_2 AND topping_name_1 >= topping_name_3 THEN topping_name_1
          WHEN topping_name_2 >= topping_name_1 AND topping_name_2 >= topping_name_3 THEN topping_name_2
          ELSE topping_name_3
        END
      ) THEN topping_name_2
      ELSE topping_name_3
    END AS topping_name_2,
    CASE 
      WHEN topping_name_1 >= topping_name_2 AND topping_name_1 >= topping_name_3 THEN topping_name_1
      WHEN topping_name_2 >= topping_name_1 AND topping_name_2 >= topping_name_3 THEN topping_name_2
      ELSE topping_name_3
    END AS topping_name_3,
    total_cost
  FROM three_topping_pizza_with_duplicates
) 

SELECT topping_name_1 + ',' + topping_name_2 + ',' + topping_name_3 AS toppings, 
       total_cost 
FROM three_topping_pizza_without_duplicates
ORDER BY total_cost DESC, topping_name_1, topping_name_2, topping_name_3;



--Writing a query to compare the average salary of employees in each department to the company's average salary for March 2024. 
--Returning the comparison result as 'higher', 'lower', or 'same' for each department.
--Displaying the department ID, payment month (in MM-YYYY format), and the comparison result.
CREATE TABLE #employee(
	employee_id INT,
	name VARCHAR(255),
	salary INT,
	department_id INT,
	manager_id INT
)

INSERT INTO #employee VALUES
(1, 'Emma Thompson', 3800, 1, 6),
(2,	'Daniel Rodriguez',	2230, 1, 7),
(3,	'Olivia Smith',	7000, 1, 8),
(4,	'Noah Johnson',	6800, 2, 9),
(5,	'Sophia Martinez', 1750, 1, 11),
(6,	'Liam Brown', 13000, 3,	NULL),
(7,	'Ava Garcia', 12500, 3,	NULL),
(8,	'William Davis', 6800, 2, NULL),
(9,	'Isabella Wilson', 11000, 3, NULL),
(10, 'James Anderson', 4000, 1, 11),
(11, 'Mia Taylor', 10800, 3, NULL),
(12, 'Benjamin Hernandez', 9500, 3, 8),
(13, 'Charlotte Miller', 7000, 2, 6),
(14, 'Logan Moore',	8000, 2, 6),
(15, 'Amelia Lee', 4000, 1,	7)

CREATE TABLE #salary(
	salary_id INT,
	employee_id INT,
	amount INT,
	payment_date DATETIME
)

INSERT INTO #salary VALUES
(1, 1, 3800, '01/31/2024 00:00:00'),
(2,	2, 2230, '01/31/2024 00:00:00'),
(3,	3, 7000, '01/31/2024 00:00:00'),
(4,	4, 6800, '01/31/2024 00:00:00'),
(5,	5, 1750, '01/31/2024 00:00:00'),
(6,	6, 13000, '01/31/2024 00:00:00'),
(7,	7, 12500, '01/31/2024 00:00:00'),
(8,	8, 6800, '01/31/2024 00:00:00'),
(9,	9, 11000, '01/31/2024 00:00:00'),
(10, 10, 4000, '01/31/2024 00:00:00'),
(11, 11, 10800,	'01/31/2024 00:00:00'),
(12, 12, 9500, '01/31/2024 00:00:00'),
(13, 13, 7000, '01/31/2024 00:00:00'),
(14, 14, 8000, '01/31/2024 00:00:00'),
(15, 15, 4000, '01/31/2024 00:00:00'),
(16, 1, 3800, '02/28/2024 00:00:00'),
(17, 2,	2230, '02/28/2024 00:00:00'),
(18, 3,	7000, '02/28/2024 00:00:00'),
(19, 4,	6800, '02/28/2024 00:00:00'),
(20, 5,	1750, '02/28/2024 00:00:00'),
(21, 6,	13000, '02/28/2024 00:00:00'),
(22, 7,	12500, '02/28/2024 00:00:00'),
(23, 8,	6800, '02/28/2024 00:00:00'),
(24, 9,	11000, '02/28/2024 00:00:00'),
(25, 10, 4000, '02/28/2024 00:00:00'),
(26, 11, 10800,	'02/28/2024 00:00:00'),
(27, 12, 9500, '02/28/2024 00:00:00'),
(28, 13, 7000, '02/28/2024 00:00:00'),
(29, 14, 8000, '02/28/2024 00:00:00'),
(30, 15, 4000, '02/28/2024 00:00:00'),
(31, 1,	3800, '03/31/2024 00:00:00'),
(32, 2,	2230, '03/31/2024 00:00:00'),
(33, 3,	7000, '03/31/2024 00:00:00'),
(34, 4,	6800, '03/31/2024 00:00:00'),
(35, 5,	1750, '03/31/2024 00:00:00'),
(36, 6,	13000, '03/31/2024 00:00:00'),
(37, 7,	12500, '03/31/2024 00:00:00'),
(38, 8,	6800, '03/31/2024 00:00:00'),
(39, 9,	11000, '03/31/2024 00:00:00'),
(40, 10, 4000, '03/31/2024 00:00:00'),
(41, 11, 10800,	'03/31/2024 00:00:00'),
(42, 12, 9500, '03/31/2024 00:00:00'),
(43, 13, 7000, '03/31/2024 00:00:00'),
(44, 14, 8000, '03/31/2024 00:00:00'),
(45, 15, 4000, '03/31/2024 00:00:00')

WITH march_records AS (
  SELECT 
    E.employee_id, 
    E.name, 
    S.amount, 
    E.department_id, 
    S.payment_date,
    ROUND(AVG(S.amount) OVER(PARTITION BY E.department_id), 0) AS department_average,
    ROUND(AVG(S.amount) OVER(), 0) AS company_average 
  FROM #employee AS E
  JOIN #salary AS S
    ON S.employee_id = E.employee_id
  WHERE FORMAT(S.payment_date, 'MM') = '03'
) 

SELECT DISTINCT 
  department_id, 
  '0' + FORMAT(payment_date, 'MM') + '-' + FORMAT(payment_date, 'yyyy') AS payment_date,
  CASE
    WHEN department_average < company_average THEN 'lower'
    WHEN department_average > company_average THEN 'higher'
    ELSE 'same'
  END AS comparison
FROM march_records;



--Using a transactions table, identify any payments made at the same merchant with the same credit card for the same amount within 10 minutes of each other. 
--Count such repeated payments.
CREATE TABLE #transactions(
	transaction_id INT,
	merchant_id INT,
	credit_card_id INT,
	amount INT,
	transaction_timestamp DATETIME
)

INSERT INTO #transactions VALUES
(1, 101, 1, 100, '09/25/2022 12:00:00'),
(2,	101, 1,	100, '09/25/2022 12:08:00'),
(3,	101, 1,	100, '09/25/2022 12:28:00'),
(5,	101, 1,	100, '09/25/2022 13:37:00'),
(4,	101, 2,	300, '09/25/2022 12:20:00'),
(6,	102, 2,	400, '09/25/2022 14:00:00'),
(7,	102, 3,	300, '09/26/2022 10:00:00'),
(8,	102, 3,	300, '09/26/2022 10:10:00'),
(9,	102, 3,	300, '09/26/2022 10:14:00'),
(10, 103, 4, 50, '09/27/2022 12:00:00'),
(11, 103, 4, 50, '09/27/2022 12:09:00'),
(12, 103, 4, 50, '09/27/2022 22:00:00'),
(14, 105, 6, 100, '09/27/2022 12:10:00'),
(13, 105, 6, 200, '09/27/2022 12:00:00')

WITH my_cte AS (
  SELECT *, 
         LAG(transaction_timestamp, 1) OVER(PARTITION BY merchant_id ORDER BY transaction_id) AS previous_timestamp,
         LAG(amount, 1) OVER(PARTITION BY merchant_id ORDER BY transaction_id) AS previous_amount 
  FROM #transactions
), 
my_cte2 AS (
  SELECT * 
  FROM my_cte
  WHERE previous_timestamp IS NOT NULL AND previous_amount IS NOT NULL
) 

SELECT DISTINCT 
       COUNT(*) OVER() AS payment_count 
FROM my_cte2
WHERE CAST(transaction_timestamp AS DATE) = CAST(previous_timestamp AS DATE) AND 
      DATEPART(HOUR, transaction_timestamp) = DATEPART(HOUR, previous_timestamp) AND 
      DATEDIFF(MINUTE, previous_timestamp, transaction_timestamp) <= 10 AND 
      amount = previous_amount



--Writing a query that calculates the total time that a fleet of servers was running.
--The output is presented in units of full days.
CREATE TABLE #server_utilization(
	server_id INT,
	session_status VARCHAR(255),
	status_time DATETIME
)

INSERT INTO #server_utilization VALUES
(1,	'start', '08/02/2022 10:00:00'),
(1,	'stop',	'08/04/2022 10:00:00'),
(1,	'stop',	'08/13/2022 19:00:00'),
(1,	'start', '08/13/2022 10:00:00'),
(3,	'stop', '08/19/2022 10:00:00'),
(3,	'start', '08/18/2022 10:00:00'),
(5,	'stop',	'08/19/2022 10:00:00'),
(4,	'stop',	'08/19/2022 14:00:00'),
(4,	'start', '08/16/2022 10:00:00'),
(3,	'stop',	'08/14/2022 10:00:00'),
(3,	'start', '08/06/2022 10:00:00'),
(2,	'stop',	'08/24/2022 10:00:00'),
(2,	'start', '08/17/2022 10:00:00'),
(5,	'start', '08/14/2022 21:00:00')

WITH my_cte AS ( 
  SELECT *, 
         CASE
           WHEN session_status = 'stop' THEN 
                LAG(status_time, 1) OVER(PARTITION BY server_id ORDER BY status_time) 
         END AS previous_time 
  FROM #server_utilization
), 
my_cte2 AS (
  SELECT *,
         CASE
           WHEN DATEPART(HOUR, status_time) = DATEPART(HOUR, previous_time) AND 
                DATEPART(MINUTE, status_time) = DATEPART(MINUTE, previous_time) AND
                DATEPART(SECOND, status_time) = DATEPART(SECOND, previous_time) THEN 
                CAST(DATEDIFF(DAY, previous_time, status_time) AS VARCHAR)

           WHEN DATEPART(DAY, status_time) = DATEPART(DAY, previous_time) AND
                DATEPART(MONTH, status_time) = DATEPART(MONTH, previous_time) AND
                DATEPART(YEAR, status_time) = DATEPART(YEAR, previous_time) THEN 
                CAST(DATEDIFF(DAY, previous_time, status_time) AS VARCHAR)

           ELSE CAST(DATEDIFF(DAY, previous_time, status_time) AS VARCHAR)
         END AS total_uptime_per_server 
  FROM my_cte
  WHERE previous_time IS NOT NULL
)

SELECT DISTINCT 
       SUM(CAST(total_uptime_per_server AS INT)) OVER() AS total_uptime_days 
FROM my_cte2

--Demonstrating an application of triggers
CREATE TABLE Orders2 (
    OrderID INT PRIMARY KEY IDENTITY(1,1),
    CustomerName NVARCHAR(100),
    OrderDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE OrderLogs2 (
    LogID INT PRIMARY KEY IDENTITY(1,1),
    OrderID INT,
    Action NVARCHAR(50),
    LogDate DATETIME DEFAULT GETDATE()
);

CREATE TRIGGER trg_AfterInsert_Orders
ON Orders2
AFTER INSERT
AS
BEGIN
    -- Insert into OrderLogs based on inserted data
    INSERT INTO OrderLogs2 (OrderID, Action, LogDate)
    SELECT 
        OrderID,
        'INSERT',
        GETDATE()
    FROM 
        INSERTED;
END;

INSERT INTO Orders2 (CustomerName)
VALUES ('John Doe');

-- Check the logs
SELECT * FROM OrderLogs2;