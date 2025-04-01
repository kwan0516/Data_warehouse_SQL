--Create Dimensions
CREATE TABLE Calendar_Dimension(
    CalendarKey INT NOT NULL AUTO_INCREMENT,
    Fulldate DATE NOT NULL,
    CalendarMonth INT,
    CalendarYear INT,
    MonthYear VARCHAR(10),
    PRIMARY KEY (CalendarKey)
);

CREATE TABLE Store_Dimension(
    StoreKey INT NOT NULL AUTO_INCREMENT,
    StoreID VARCHAR(3) NOT NULL,
    RegionName VARCHAR(15) NOT NULL,
    StoreZip VARCHAR(5) NOT NULL,
    RegionID VARCHAR(3) NOT NULL,
    PRIMARY KEY (StoreKey)
);

CREATE TABLE Product_Dimension(
    ProductKey INT NOT NULL AUTO_INCREMENT,
    ProductID CHAR(3) NOT NULL,
    ProductName VARCHAR(25) NOT NULL,
    VendorID VARCHAR(3) NOT NULL,
    VendorName VARCHAR(25) NOT NULL,
    CategoryID CHAR(2) NOT NULL,
    CategoryName VARCHAR(25) NOT NULL,
    ProductType VARCHAR(15) NOT NULL,
    PRIMARY KEY (ProductKey)
);

CREATE TABLE Customer_Dimension(
    CustomerKey INT NOT NULL AUTO_INCREMENT,
    CustomerID CHAR(7) NOT NULL,
    CustomerName VARCHAR(15) NOT NULL,
    CustomerZip CHAR(5) NOT NULL,
    PRIMARY KEY (CustomerKey)
);

CREATE TABLE Product_Price (
    ProductKey INT NOT NULL,
    ProductPrice DECIMAL(7,2),
    ProductPriceType VARCHAR(20),
    PRIMARY KEY (ProductPrice, ProductPriceType, ProductKey),
    FOREIGN KEY (ProductKey) REFERENCES Product_Dimension(ProductKey)
);

CREATE TABLE CoreFact(
    UnitsSoldRent INT NOT NULL,
    RevenueGenerated NUMERIC(9,2) NOT NULL,
    RevenueSource VARCHAR(50) NOT NULL,
    tid VARCHAR(8) NOT NULL,
    CustomerKey INT NOT NULL,
    StoreKey INT NOT NULL,
    ProductKey INT NOT NULL,
    CalendarKey INT NOT NULL
);

--Insert data into dimensions
--Product dimension
--Insert sale product
INSERT INTO Product_Dimension (ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType)
SELECT p.productid, p.productname, v.vendorid, v.vendorname, ca.categoryID, ca.categoryname, "Sales"
FROM ko_ZAGI.product p, ko_ZAGI.vendor v, ko_ZAGI.category ca 
WHERE p.vendorid = v.vendorid AND p.categoryid = ca.categoryid

--Insert rental product
INSERT INTO Product_Dimension (ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType)
SELECT r.productid, r.productname, v.vendorid, v.vendorname, ca.categoryID, ca.categoryname, "Rental"
FROM ko_ZAGI.rentalProducts r, ko_ZAGI.vendor v, ko_ZAGI.category ca 
WHERE r.vendorid = v.vendorid AND r.categoryid = ca.categoryid

--Product price
--Insert product sale price
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType)
SELECT p.ProductKey, pr.productprice, "Unit Sales Price"
FROM Product_Dimension p, ko_ZAGI.product pr
WHERE p.ProductID = pr.productid

--Insert daily rental price
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType)
SELECT p.ProductKey, r.productpricedaily, "Daily rental"
FROM Product_Dimension p, ko_ZAGI.rentalProducts r
WHERE p.ProductID = r.productid
AND p.ProductType = "Rental"

--Insert daily rental price
INSERT INTO Product_Price (ProductKey, ProductPrice, ProductPriceType)
SELECT p.ProductKey, r.productpriceweekly, "Weekly rental"
FROM Product_Dimension p, ko_ZAGI.rentalProducts r
WHERE p.ProductID = r.productid
AND p.ProductType = "Rental"

--Store Dimension
INSERT INTO Store_Dimension (StoreID, RegionID, RegionName, StoreZip)
SELECT s.storeid, s.regionid, r.regionname, s.storezip
FROM ko_ZAGI.store s, ko_ZAGI.region r 
WHERE s.regionid = r.regionid

--Customer Dimension
INSERT INTO Customer_Dimension (CustomerID, CustomerName, CustomerZip)
SELECT c.customerid, c.customername, c.customerzip
FROM ko_ZAGI.customer c

--populate calendar dimension
CREATE PROCEDURE populateCalendar()
BEGIN
  DECLARE i INT DEFAULT 0;   
myloop: LOOP
 INSERT INTO Calendar_Dimension(FullDate)
 SELECT DATE_ADD('2013-01-01', INTERVAL i DAY);
 SET i=i+1;
    IF i=6000 then
            LEAVE myloop;
    END IF;

END LOOP myloop;

UPDATE Calendar_Dimension
SET CalendarMonth = MONTH(FullDate), CalendarYear = YEAR(FullDate), 
     MonthYear = concat(Year(FullDate),lpad(Month(FullDate),2,'0'));

END;

--Insert core fact table
--intermediate core fact 
--sales product
CREATE TABLE icf AS
SELECT sv.noofitems, sv.noofitems * p.productprice AS RevenueGenerated, s.tid, s.customerid, s.storeid, sv.productid, s.tdate
FROM ko_ZAGI.salestransaction s, ko_ZAGI.soldvia sv, ko_ZAGI.product p
WHERE s.tid = sv.tid AND p.productid = sv.productid;

INSERT INTO CoreFact (UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey)
SELECT i.noofitems, i.RevenueGenerated, "Sales", i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = "Sales";

--Daily rental product
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT rv.duration, rp.productpricedaily * rv.duration AS RevenueGenerated, r.tid, r.customerid, r.storeid, rv.productid, r.tdate
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid
AND rv.rentaltype = "D"

INSERT INTO CoreFact (UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey)
SELECT i.duration, i.RevenueGenerated, "Rental Daily", i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = "Rental";

--Weekly rental product
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT rv.duration, rp.productpriceweekly * rv.duration AS RevenueGenerated, r.tid, r.customerid, r.storeid, rv.productid, r.tdate
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid
AND rv.rentaltype = "W"

INSERT INTO CoreFact (UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey)
SELECT i.duration, i.RevenueGenerated, "Rental Weekly", i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = "Rental";

