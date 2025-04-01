--Regular daily refreshing of core fact
--In data staging, add columns "timestamp" and "loaded" to the core fact table
ALTER TABLE CoreFact ADD loaded BOOLEAN NOT NULL,
ADD f_timestamp TIMESTAMP NOT NULL;

--setting "loaded" values to 1 for all facts
--setting "timestamp" values to the day before yesterday for all facts
UPDATE CoreFact SET loaded = TRUE,
f_timestamp = NOW() - INTERVAL 2 day;


--Add two new facts to ZAGI (sales)
INSERT INTO ko_ZAGI.salestransaction (tid, customerid, storeid, tdate) VALUES ('T96666', '3-4-555', 'S10', CAST(NOW() AS DATE));
INSERT INTO ko_ZAGI.soldvia (productid, tid, noofitems) VALUES ('2X4', 'T96666', '3'), ('8X8', 'T96666', '1');

--Add two new facts to ZAGI (Daily rental and Weekly rental)
INSERT INTO ko_ZAGI.rentaltransaction (tid, customerid, storeid, tdate) VALUES ('R87630', '2-3-444', 'S3', CAST(NOW() AS DATE));
INSERT INTO ko_ZAGI.rentvia (productid, tid, rentaltype, duration) VALUES ('3X3', 'R87630', 'D', 2), ('5X5', 'R87630', 'W', 5);

--Create procedure
CREATE PROCEDURE Daily_corefact_refresh()
BEGIN

--Extracting only new facts
--Sales Products
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT sv.noofitems AS UnitsSoldRent, sv.noofitems * p.productprice AS RevenueGenerated, s.tid, s.customerid, s.storeid, sv.productid, s.tdate, 'Sales' AS RevenueSource
FROM ko_ZAGI.salestransaction s, ko_ZAGI.soldvia sv, ko_ZAGI.product p
WHERE s.tid = sv.tid AND p.productid = sv.productid
AND s.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM CoreFact)));

INSERT INTO CoreFact(UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey, loaded, f_timestamp)
SELECT i.UnitsSoldRent, i.RevenueGenerated, i.RevenueSource, i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey, FALSE, NOW()
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = 'Sales';

--Weekly rental products
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT rv.duration, rp.productpricedaily * rv.duration, r.tid, r.customerid, r.storeid, rv.productid, r.tdate, "Rental Weekly" AS RevenueSource
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid AND rv.rentaltype = "W"
AND r.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM CoreFact)));

--Daily rental products
INSERT INTO icf (UnitsSoldRent, RevenueGenerated, tid, customerid, storeid, productid, tdate, RevenueSource)
SELECT rv.duration AS UnitsSoldRent, rp.productpricedaily * rv.duration AS RevenueGenerated, r.tid, r.customerid, r.storeid, rv.productid, r.tdate, "Rental Daily" AS RevenueSource
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid AND rv.rentaltype = "D"
AND r.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM CoreFact)));

INSERT INTO CoreFact(UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey, loaded, f_timestamp)
SELECT i.UnitsSoldRent, i.RevenueGenerated, i.RevenueSource, i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey, FALSE, NOW()
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = 'Rental';

--Inserting from CoreFact in data staging to data warehouse
INSERT INTO ko_ZAGI_Datawarehouse.CoreFact(UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey)
SELECT UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey
FROM CoreFact 
WHERE loaded = 0;

UPDATE CoreFact
SET loaded = 1;

END

-- DAILY REFRESHING OF DIMENSION TABLES
--- updating ProductDimension Current Status
ALTER TABLE Product_Dimension ADD loaded BOOLEAN NOT NULL ,
ADD E_TimeStamp TIMESTAMP NOT NULL,
ADD DateValidUntil DATE,
ADD DateValidFrom DATE,
ADD status CHAR(1);

UPDATE Product_Dimension
SET status='C', DateValidUntil='2030-01-01', loaded = 1, DateValidFrom='2013-01-01',
E_TimeStamp = NOW()- INTERVAL 10 day;

ALTER TABLE ko_ZAGI_Datawarehouse.Product_Dimension ADD DateValidUntil DATE,
ADD DateValidFrom DATE,
ADD status CHAR(1);

UPDATE ko_ZAGI_Datawarehouse.Product_Dimension
SET status='C', DateValidUntil='2030-01-01', DateValidFrom='2013-01-01';

ALTER TABLE Product_Price ADD loaded BOOLEAN NOT NULL ,
ADD E_TimeStamp TIMESTAMP NOT NULL,
ADD DateValidUntil DATE,
ADD DateValidFrom DATE,
ADD status CHAR(1);

UPDATE Product_Price
SET status='C', DateValidUntil='2030-01-01', loaded = 1, DateValidFrom='2013-01-01',
E_TimeStamp = NOW()- INTERVAL 10 day;

ALTER TABLE ko_ZAGI_Datawarehouse.Product_Price ADD DateValidUntil DATE,
ADD DateValidFrom DATE,
ADD status CHAR(1);

UPDATE ko_ZAGI_Datawarehouse.Product_Price
SET status='C', DateValidUntil='2030-01-01', DateValidFrom='2013-01-01';

-- creating a new product (sales)
INSERT INTO ko_ZAGI.product(productid,productname,productprice,vendorid,categoryid)
VALUES ('6X9', 'You Pad', 1000, 'WL', 'EL');


--Create procedure
CREATE PROCEDURE Daily_SaleProducts_refresh()
BEGIN

--Insert product to product dimension
DROP TABLE IF EXISTS ipd;
CREATE TABLE ipd AS
SELECT p.productid, p.productname, v.vendorid, v.vendorname, c.categoryid, c.categoryname
FROM ko_ZAGI.product p, ko_ZAGI.vendor v, ko_ZAGI.category c
WHERE p.categoryid = c.categoryid AND p.vendorid = v.vendorid
AND p.productid NOT IN (SELECT ProductID FROM Product_Dimension WHERE ProductType = 'Sales');

INSERT INTO Product_Dimension (ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT i.productid, i.productname, i.vendorid, i.vendorname, i.categoryid, i.categoryname, 'Sales', 0, NOW(), CAST(NOW() AS DATE), '2030-01-01', 'C'
FROM ipd i;

INSERT INTO ko_ZAGI_Datawarehouse.Product_Dimension (ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status
FROM Product_Dimension
WHERE loaded = 0;

UPDATE Product_Dimension
SET loaded = 1;


--Insert product price to product price dimension
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT pd.ProductKey, p.productprice, 'Unit Sales Price', 0, NOW(), CAST(NOW() AS DATE), '2030-01-01', 'C'
FROM Product_Dimension pd, ko_ZAGI.product p 
WHERE pd.ProductID = p.productid AND pd.ProductName = p.productname 
AND pd.VendorID = p.vendorid AND pd.CategoryID = p.categoryid 
AND pd.ProductKey NOT IN (SELECT ProductKey FROM Product_Price WHERE ProductPriceType = 'Unit Sales Price')
AND pd.ProductType = 'Sales';

INSERT INTO ko_ZAGI_Datawarehouse.Product_Price (ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status
FROM Product_Price
WHERE loaded = 0;

UPDATE Product_Price
SET loaded = 1;

END

-- creating a new product (Rental)
INSERT INTO ko_ZAGI.rentalProducts(productid,productname,vendorid,categoryid,productpricedaily,productpriceweekly)
VALUES ('6X9', 'You Pad', 'WL', 'EL', 100, 500);

--Create procedure
CREATE PROCEDURE Daily_RentalProducts_refresh()
BEGIN

--Insert rental product to product dimension 
DROP TABLE IF EXISTS ipd;
CREATE TABLE ipd AS
SELECT rp.productid, rp.productname, rp.vendorid, v.vendorname, rp.categoryid, c.categoryname
FROM ko_ZAGI.rentalProducts rp, ko_ZAGI.vendor v, ko_ZAGI.category c
WHERE rp.vendorid = v.vendorid AND rp.categoryid = c.categoryid
AND rp.productid NOT IN (SELECT ProductID FROM Product_Dimension WHERE ProductType = 'Rental');

INSERT INTO Product_Dimension (ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT productid, productname, vendorid, vendorname, categoryid, categoryname, 'Rental', 0, NOW(), CAST(NOW() AS DATE), '2030-01-01', 'C'
FROM ipd;

--Insert rental product price (Daily)
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT pd.ProductKey, rp.productpricedaily, 'Daily rental',0, NOW(), CAST(NOW() AS DATE), '2030-01-01', 'C'
FROM ko_ZAGI.rentalProducts rp, Product_Dimension pd
WHERE rp.productid = pd.ProductID AND pd.ProductType = 'Rental'
AND rp.productid IN (SELECT productid FROM ipd);

--Insert rental product price (Weekly)
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT pd.ProductKey, rp.productpriceweekly, 'Weekly rental', 0, NOW(),CAST(NOW() AS DATE), '2030-01-01', 'C'
FROM ko_ZAGI.rentalProducts rp, Product_Dimension pd
WHERE rp.productid = pd.ProductID AND pd.ProductType = 'Rental'
AND rp.productid IN (SELECT productid FROM ipd);

--Insert into data warehouse
INSERT INTO ko_ZAGI_Datawarehouse.Product_Dimension (ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status
FROM Product_Dimension
WHERE loaded = 0;

INSERT INTO ko_ZAGI_Datawarehouse.Product_Price (ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status
FROM Product_Price
WHERE loaded = 0;

UPDATE Product_Dimension
SET loaded = 1;

UPDATE Product_Price
SET loaded = 1;

END

--Product dimension typeII change
--Update product (Sales)
UPDATE ko_ZAGI.product 
SET productname = 'Hard Boot'
WHERE productid = '2X2';

UPDATE ko_ZAGI.product 
SET productprice = 100
WHERE productid = '2X2';

--Create procedure
CREATE PROCEDURE Daily_SaleProducts_TypeII()
BEGIN
DROP TABLE IF EXISTS ipd;
CREATE TABLE ipd AS
SELECT p.productid, p.productname, p.vendorid, v.vendorname, p.categoryid, c.categoryname 
FROM ko_ZAGI.product p, ko_ZAGI.vendor v, ko_ZAGI.category c 
WHERE p.vendorid = v.vendorid AND p.categoryid = c.categoryid 
AND CONCAT(p.productname, p.vendorid, p.categoryid) NOT IN 
(SELECT CONCAT(ProductName, VendorID, CategoryID) FROM Product_Dimension WHERE ProductType = 'Sales');

UPDATE Product_Dimension
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE ProductID IN (SELECT productid FROM ipd) AND ProductType = 'Sales';

INSERT INTO Product_Dimension (ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT productid, productname, vendorid, vendorname, categoryid,  categoryname, 'Sales', 0, NOW(), CAST(NOW() AS Date), '2030-01-01', 'C'
FROM ipd;

UPDATE Product_Price
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE ProductKey IN (SELECT pd.ProductKey FROM Product_Dimension pd, ipd i WHERE i.productid = pd.ProductID) AND ProductPriceType = 'Unit Sales Price';

INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType, loaded, E_TimeStamp, DateValidFrom, DateValidUntil, status)
SELECT pd.ProductKey, p.productprice, 'Unit Sales Price', 0, NOW(), CAST(NOW() AS Date), '2030-01-01', 'C'
FROM ko_ZAGI.product p, Product_Dimension pd 
WHERE p.productid = pd.ProductID AND pd.ProductKey NOT IN (SELECT ProductKey FROM Product_Price)
AND pd.ProductType = 'Sales';

--Update datawarehouse
UPDATE ko_ZAGI_Datawarehouse.Product_Dimension
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE ProductID IN (SELECT productid FROM ipd) AND ProductType = 'Sales';

UPDATE ko_ZAGI_Datawarehouse.Product_Price
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE ProductKey IN (SELECT pd.ProductKey FROM Product_Dimension pd, ipd i WHERE i.productid = pd.ProductID) AND ProductPriceType = 'Unit Sales Price';

INSERT INTO ko_ZAGI_Datawarehouse.Product_Dimension (ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, status
FROM Product_Dimension
WHERE loaded = 0;

INSERT INTO ko_ZAGI_Datawarehouse.Product_Price (ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status)
SELECT ProductKey, ProductPrice, ProductPriceType, DateValidFrom, DateValidUntil, status
FROM Product_Price
WHERE loaded = 0;

UPDATE Product_Dimension
SET loaded = 1;
UPDATE Product_Price
SET loaded = 1;

END

--Rental product typeII change
DROP TABLE IF EXISTS ipd;
CREATE TABLE ipd AS 
SELECT rp.productid, rp.productname, rp.vendorid, v.vendorname, rp.categoryid, c.categoryname 
FROM ko_ZAGI.rentalProducts rp, ko_ZAGI.vendor v, ko_ZAGI.category c 
WHERE rp.vendorid = v.vendorid AND rp.categoryid = c.categoryid 
AND  CONCAT(rp.productname, rp.vendorid, rp.categoryid) NOT IN 
(SELECT CONCAT(ProductName, VendorID, CategoryID) FROM Product_Dimension WHERE ProductType = 'Rental');

UPDATE Product_Dimension
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE ProductID IN (SELECT productid FROM ipd) AND ProductType = 'Rental';

--Create intermediate product price table
DROP IF EXISTS ipp;
CREATE TABLE ipp AS 
SELECT pd.ProductKey, rp.productpricedaily AS ProductPrice, 'Daily rental' AS ProductPriceType
FROM ko_ZAGI.rentalProducts rp, Product_Dimension pd
WHERE rp.productid = pd.ProductID AND pd.ProductType = 'Rental'
AND CONCAT(pd.ProductKey, rp.productpricedaily) NOT IN (SELECT CONCAT(ProductKey, ProductPrice) FROM Product_Price WHERE ProductPriceType = 'Daily rental')

UPDATE Product_Price
SET status = 'N', DateValidUntil = CAST( NOW() AS Date )
WHERE CONCAT(ProductKey, ProductPriceType) IN (SELECT CONCAT(ProductKey, ProductPriceType) FROM ipp)