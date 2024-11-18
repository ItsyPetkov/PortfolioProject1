IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'server_config')
BEGIN
	EXEC('
		CREATE PROCEDURE server_config
		AS
	
		EXEC sp_configure ''show advanced options'', 1;
		RECONFIGURE;
		EXEC sp_configure;

		EXEC sp_configure ''ad hoc distributed queries'', 1;
		RECONFIGURE;
		EXEC sp_configure;
	');
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'database_config')
BEGIN
	EXEC('
		CREATE PROCEDURE database_config
		AS

		EXEC PortfolioProject.dbo.sp_MSset_oledb_prop N''Microsoft.ACE.OLEDB.12.0'', N''AllowInProcess'', 1 

		EXEC PortfolioProject.dbo.sp_MSset_oledb_prop N''Microsoft.ACE.OLEDB.12.0'', N''DynamicParameters'', 1 
	');
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'populate_database')
BEGIN
	EXEC('
		CREATE PROCEDURE populate_database
		@path NVARCHAR(MAX)
		AS

		DECLARE @SQL NVARCHAR(MAX) = '''';
		DECLARE @directory NVARCHAR(MAX);

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''customers'')
		BEGIN
		CREATE TABLE customers(
			customer_id INT PRIMARY KEY,
			first_name VARCHAR(255) NOT NULL,
			last_name VARCHAR(255) NOT NULL,
			phone VARCHAR(255),
			email VARCHAR(255) NOT NULL,
			street VARCHAR(255) NOT NULL,
			city VARCHAR(255) NOT NULL,
			state VARCHAR(255) NOT NULL,
			zip_code INT NOT NULL
		);

		BULK INSERT customers FROM ''C:\Users\Hristo\Downloads\archive\customers.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''orders'')
		BEGIN
		CREATE TABLE orders(
			order_id INT PRIMARY KEY,
			customer_id INT NOT NULL,
			order_status INT NOT NULL,
			order_date VARCHAR(255) NOT NULL,
			required_date VARCHAR(255) NOT NULL,
			shipped_date VARCHAR(255),
			store_id INT NOT NULL,
			staff_id INT NOT NULL
		);

		BULK INSERT orders FROM ''C:\Users\Hristo\Downloads\archive\orders.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''staffs'')
		BEGIN
		CREATE TABLE staffs(
			staff_id INT PRIMARY KEY,
			first_name VARCHAR(255) NOT NULL,
			last_name VARCHAR(255) NOT NULL,
			email VARCHAR(255) NOT NULL,
			phone VARCHAR(255) NOT NULL,
			active INT NOT NULL,
			store_id INT NOT NULL,
			manager_id VARCHAR(255) 
		);

		BULK INSERT staffs FROM ''C:\Users\Hristo\Downloads\archive\staffs.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''stores'')
		BEGIN
		CREATE TABLE stores(
			store_id INT PRIMARY KEY,
			store_name VARCHAR(255) NOT NULL,
			phone VARCHAR(255) NOT NULL,
			email VARCHAR(255) NOT NULL,
			street VARCHAR(255) NOT NULL,
			city VARCHAR(255) NOT NULL,
			state VARCHAR(255) NOT NULL,
			zip_code VARCHAR(255) NOT NULL
		);

		BULK INSERT stores FROM ''C:\Users\Hristo\Downloads\archive\stores.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''order_items'')
		BEGIN
		CREATE TABLE order_items(
			order_id INT NOT NULL,
			item_id INT NOT NULL,
			product_id INT NOT NULL,
			quantity INT NOT NULL,
			list_price DECIMAL(10,2) NOT NULL,
			discount DECIMAL(10,2) NOT NULL,
			PRIMARY KEY (order_id, item_id)
		);

		BULK INSERT order_items FROM ''C:\Users\Hristo\Downloads\archive\order_items.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''categories'')
		BEGIN
		CREATE TABLE categories(
			category_id INT PRIMARY KEY,
			category_name VARCHAR(255) NOT NULL
		);

		BULK INSERT categories FROM ''C:\Users\Hristo\Downloads\archive\categories.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''products'')
		BEGIN
		CREATE TABLE products(
			product_id INT PRIMARY KEY,
			product_name VARCHAR(255) NOT NULL,
			brand_id INT NOT NULL,
			category_id INT NOT NULL,
			model_year INT NOT NULL,
			list_price DECIMAL(10,2) NOT NULL
		);

		BULK INSERT products FROM ''C:\Users\Hristo\Downloads\archive\products.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''stocks'')
		BEGIN
		CREATE TABLE stocks(
			store_id INT NOT NULL,
			product_id INT NOT NULL,
			quantity INT NOT NULL,
			PRIMARY KEY (store_id, product_id)
		);

		BULK INSERT stocks FROM ''C:\Users\Hristo\Downloads\archive\stocks.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;

		IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = ''brands'')
		BEGIN
		CREATE TABLE brands(
			brand_id INT PRIMARY KEY,
			brand_name VARCHAR(255) NOT NULL
		);

		BULK INSERT brands FROM ''C:\Users\Hristo\Downloads\archive\brands.csv''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''\n''
			);
		END;
	');
END;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'portfolio_project_data_setup')
BEGIN
	EXEC('
		CREATE PROCEDURE portfolio_project_data_setup
		AS

		EXEC server_config
		EXEC database_config
		EXEC populate_database @path = ''C:\Users\Hristo\Downloads\archive''
	');
END;

CREATE PROCEDURE joins
@relational_type AS NVARCHAR(MAX)
AS

IF @relational_type = 'all'
BEGIN
	SELECT C.customer_id AS "(Customer) customer_id", C.first_name AS "(Customer) first_name", C.last_name AS "(Customer) last_name", C.phone AS "(Customer) phone",
	C.email AS "(Customer) email", C.street AS "(Customer) street", C.city AS "(Customer) city", C.state AS "(Customer) state", C.zip_code AS "(Customer) zip_code",
	O.order_id AS "(Order) order_id", O.order_status AS "(Order) order_status", O.order_date AS "(Order) order_date", O.required_date AS "(Order) required_date",
	O.shipped_date AS "(Order) shipped_date", O.store_id AS "(Order) store_id", O.staff_id AS "(Order) staff_id",
	E.first_name AS "(Employee) first_name", E.last_name AS "(Employee) last_name", E.email AS "(Employee) email", E.phone AS "(Employee) phone",
	E.active AS "(Employee) active", E.store_id AS "(Employee) store_id", E.manager_id AS "(Employee) maanger_id",
	M.first_name AS "(Manager) first_name", M.last_name AS "(Manager) last_name", M.email AS "(Manager) email",
	M.phone AS "(Manager) phone", M.active AS "(Manager) active", M.store_id AS "(Manager) store_id", M.manager_id AS "(Manager) maanger_id",
	S.store_name AS "(Store) store_name", S.phone AS "(Store) phone", S.email AS "(Store) email", S.street AS "(Store) street", 
	S.city AS "(Store) city", S.state AS "(Store) state", S.zip_code AS "(Store) zip_code",
	OI.item_id AS "(Order_items) item_id", OI.product_id AS "(Order_items) product_id", OI.quantity AS "(Order_items) quantity",
	OI.list_price AS "(Order_items) list_price", OI.discount AS "(Order_items) discount",
	P.product_name AS "(Products) product_name", P.brand_id AS "(Products) brand_id",
	P.category_id AS "(Products) category_id", P.model_year AS "(Products) model_year",
	CT.category_name AS "(Categories) category_name", B.brand_name AS "(Brands) brand_name",
	ST.quantity AS "(Stocks) quantity" FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN staffs AS E
		ON E.staff_id = O.staff_id
	JOIN staffs AS M
		ON M.staff_id = E.manager_id
	JOIN stores AS S
		ON S.store_id = E.store_id AND S.store_id = O.store_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN products AS P
		ON P.product_id = OI.product_id AND P.list_price = OI.list_price
	JOIN categories AS CT
		ON CT.category_id = P.category_id
	JOIN brands AS B
		ON B.brand_id = P.brand_id
	JOIN stocks AS ST
		ON ST.store_id = S.store_id AND ST.product_id = P.product_id
	WHERE E.manager_id != 'NULL'
END;

IF @relational_type = 'customers -> orders -> order_items'
BEGIN
	SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code, O.order_id, O.order_status, O.order_date,
	O.required_date, O.shipped_date, O.store_id, O.staff_id, OI.item_id, OI.product_id, OI.quantity, OI.list_price, OI.discount FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
END;

IF @relational_type = 'order_items -> products -> brands'
BEGIN
	SELECT OI.order_id, OI.item_id, OI.product_id, OI.quantity, OI.list_price, OI.discount, P.product_name, P.brand_id, P.category_id, P.model_year, B.brand_name FROM order_items AS OI
	JOIN products AS P
		ON P.product_id = OI.product_id
	JOIN brands AS B
		ON B.brand_id = P.brand_id
END;

IF @relational_type = 'staffs -> staffs'
BEGIN
	SELECT M.staff_id, M.first_name, M.last_name, M.email, M.active, M.store_id, M.manager_id FROM staffs AS E
	JOIN staffs AS M
		ON M.staff_id = E.manager_id 
	WHERE E.manager_id <> 'NULL'
	GROUP BY M.staff_id, M.first_name, M.last_name, M.email, M.active, M.store_id, M.manager_id
END;

IF @relational_type = 'stocks -> products -> stores'
BEGIN
	SELECT ST.store_id, ST.product_id, ST.quantity, P.product_name, P.brand_id, P.category_id, P.model_year, P.list_price,
	S.store_name, S.phone, S.email, S.street, S.city, S.state, S.zip_code FROM stocks AS ST
	JOIN products AS P
		ON P.product_id = ST.product_id
	JOIN stores AS S
		ON S.store_id = ST.store_id
END;

IF @relational_type = 'customers -> orders -> order_items -> products -> brands -> categories'
BEGIN
	SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code, O.order_id, O.order_status, O.order_date, O.required_date, O.shipped_date,
	O.store_id, O.staff_id, OI.item_id, OI.product_id, OI.quantity, OI.list_price, OI.discount, P.product_name, P.brand_id, P.category_id, P.model_year, B.brand_name, CT.category_name
	FROM customers AS C
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
END;

IF @relational_type = 'customers -> orders -> order_items -> products -> categories'
BEGIN
	SELECT C.customer_id, C.first_name, C.last_name, C.phone, C.email, C.street, C.city, C.state, C.zip_code, O.order_id, O.order_status, O.order_date, O.required_date, O.shipped_date,
	O.store_id, O.staff_id, OI.item_id, OI.product_id, OI.quantity, OI.list_price, OI.discount, P.product_name, P.brand_id, P.category_id, P.model_year, CT.category_name FROM customers AS C
	JOIN orders AS O
		ON O.customer_id = C.customer_id
	JOIN order_items AS OI
		ON OI.order_id = O.order_id
	JOIN products as P
		ON P.product_id = OI.product_id
	JOIN categories AS CT
		ON CT.category_id = P.category_id
END;

EXEC PortfolioProject.dbo.portfolio_project_data_setup
EXEC PortfolioProject.dbo.joins @relational_type = 'all'
EXEC PortfolioProject.dbo.joins @relational_type = 'customers -> orders -> order_items'
EXEC PortfolioProject.dbo.joins @relational_type = 'order_items -> products -> brands'
EXEC PortfolioProject.dbo.joins @relational_type = 'staffs -> staffs'
EXEC PortfolioProject.dbo.joins @relational_type = 'stocks -> products -> stores'
EXEC PortfolioProject.dbo.joins @relational_type = 'customers -> orders -> order_items -> products -> brands -> categories'
EXEC PortfolioProject.dbo.joins @relational_type = 'customers -> orders -> order_items -> products -> categories'


--CREATE PROCEDURE test_case
--@path NVARCHAR(MAX)
--AS

--DECLARE @SQL NVARCHAR(MAX) = '';
--DECLARE @directory NVARCHAR(MAX);

--IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'customers')
--BEGIN
--CREATE TABLE customers(
--	customer_id INT PRIMARY KEY,
--	first_name VARCHAR(255) NOT NULL,
--	last_name VARCHAR(255) NOT NULL,
--	phone VARCHAR(255),
--	email VARCHAR(255) NOT NULL,
--	street VARCHAR(255) NOT NULL,
--	city VARCHAR(255) NOT NULL,
--	state VARCHAR(255) NOT NULL,
--	zip_code INT NOT NULL
--);

--SELECT @directory = @path + '\customers.csv';

--SET @SQL = N'BULK INSERT customers
--           FROM ''' + @directory + '''
--           WITH (
--                FIELDTERMINATOR = '','',        
--                ROWTERMINATOR = ''\n'',        
--                FIRSTROW = 2                   
--           );';

--EXEC sp_executesql @SQL;
--END;

--EXEC test_case @path = 'C:\Users\Hristo\Downloads\archive'


