-- REGULAR DAILY REFRESHING OF FACT TABLE

--in ZAGIMORE_DataStaging, add columns "timestamp" and "loaded" to the fact table

ALTER TABLE RevenueFact ADD loaded BOOLEAN NOT NULL ,

ADD f_timestamp TIMESTAMP NOT NULL ;

--setting "loaded" values to 1 for all facts so far

UPDATE RevenueFact SET loaded = TRUE,
f_timestamp = NOW()- INTERVAL 10 day;

------add two new facts (this code is from previous year make sure date of transaction is from that current day you are writing the code)
INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T10000', '3-4-555', 'S10', '2024-03-25');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T10000', '4'), ('6X6', 'T10000', '1');


-- extracting only new facts (that occurred since the last load, as signified by the f_timestamp value)
DROP TABLE intermediateRevenueFactTable;
CREATE TABLE intermediateRevenueFactTable as
SELECT sv.noofitems, sv.noofitems*p.productprice as RevenueGenerated, st.CustomerID, st.StoreID, sv.ProductID, st.tdate, st.tid,'Sales' as RevenueType
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.soldvia sv, ko_ZAGIMORE.salestransaction st
WHERE p.ProductID = sv.ProductID
AND sv.Tid = st.Tid
AND st.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM RevenueFact)));

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.noofitems,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Sales', 'NoofUnitSold'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND LEFT(i.RevenueType,1) = LEFT(p.ProductType, 1)

---- Short clip after part 6 -----
-- Inserting from CoreFact in data staging (the two new facts)
--loading new facts and updating f_timestamp and loaded status

INSERT INTO ko_ZAGIMORE_DW.RevenueFact(CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource)
SELECT CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource
FROM RevenueFact
WHERE loaded = 0;

-- now setting status to true of two new facts, to signify they have been loaded
UPDATE RevenueFact

SET loaded = 1




--Late arriving fact
INSERT INTO ko.ZAGIMORE.salestransaction(tid, customerid, storeid, tdate)
VALUES ('T12345', '3-4-555', 'S2', '2024-03-24');
INSERT INTO ko.ZAGIMORE.salestransaction(tid, customerid, storeid, tdate)
VALUES ('T1357', '9-0-111', 'S10', '2024-03-24');
INSERT INTO ko.ZAGIMORE.salestransaction(tid, customerid, storeid, tdate)
VALUES ('T17788', '0-1-222', 'S8', '2024-03-24');

-- adding new events in the transaction tables--

--make sure that the dates of this transaction are from at least one day AFTER the date you used in part 6a--

INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T22222', '3-4-555', 'S10', '2024-03-27');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T22222', '5'), ('6X6', 'T22222', '10');

INSERT INTO ko_ZAGIMORE.rentaltransaction (tid, customerid, storeid, tdate) VALUES ('T33333', '3-4-555', 'S10', '2024-03-27');
INSERT INTO ko_ZAGIMORE.rentvia (productid, tid, rentaltype, duration) VALUES ('5X5', 'T33333', 'D', '3');

INSERT INTO ko_ZAGIMORE.rentaltransaction (tid, customerid, storeid, tdate) VALUES ('T44444', '3-4-555', 'S10', '2024-03-27');
INSERT INTO ko_ZAGIMORE.rentvia (productid, tid, rentaltype, duration) VALUES ('5X5', 'T44444', 'W', '6');

INSERT INTO ko_ZAGIMORE.rentaltransaction (tid, customerid, storeid, tdate) VALUES ('T55555', '3-4-555', 'S10', '2024-03-27');
INSERT INTO ko_ZAGIMORE.rentvia (productid, tid, rentaltype, duration) VALUES ('5X5', 'T55555', 'W', '6');



--- creating the Revenue Fact update procedure---
create procedure Daily_Fact_Refresh()
begin

DROP TABLE intermediateRevenueFactTable;
CREATE TABLE intermediateRevenueFactTable as
SELECT sv.noofitems as UnitSoldRent, sv.noofitems*p.productprice as RevenueGenerated, st.CustomerID, st.StoreID, sv.ProductID, st.tdate, st.tid,'Sales' as RevenueType, 'NoofUnitSold' as MeasureUnits
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.soldvia sv, ko_ZAGIMORE.salestransaction st
WHERE p.ProductID = sv.ProductID
AND sv.Tid = st.Tid
AND st.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM RevenueFact)));

ALTER TABLE intermediateRevenueFactTable CHANGE RevenueType RevenueType VARCHAR( 25 );
ALTER TABLE intermediateRevenueFactTable CHANGE MeasureUnits MeasureUnits VARCHAR( 25 );


INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Sales', 'NoofUnitSold'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND LEFT(i.RevenueType,1) = LEFT(p.ProductType, 1);

INSERT INTO intermediateRevenueFactTable(UnitSoldRent, RevenueGenerated, CustomerID, StoreID, ProductID, tdate, tid, RevenueType, MeasureUnits)
SELECT rv.duration as UnitSoldRent, rv.duration*r.productpricedaily as RevenueGenerated, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, rt.tid,'Daily Rental' as RevenueType, 'Duration In Days' as MeasureUnits
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE r.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rt.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM RevenueFact)));

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Daily Rental', 'Duration In Days'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND i.RevenueType LIKE "Daily%";

INSERT INTO intermediateRevenueFactTable(UnitSoldRent, RevenueGenerated, CustomerID, StoreID, ProductID, tdate, tid, RevenueType, MeasureUnits)
SELECT rv.duration as UnitSoldRent, rv.duration*r.productpricedaily as RevenueGenerated, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, rt.tid,'Weekly Rental' as RevenueType, 'Duration In Weeks' as MeasureUnits
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE r.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rt.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM RevenueFact)));

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Weekly Rental', 'Duration In Weeks'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND i.RevenueType LIKE "Weekly%";

INSERT INTO ko_ZAGIMORE_DW.RevenueFact(CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource)

SELECT CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource

FROM RevenueFact

WHERE loaded = 0;

UPDATE RevenueFact

SET loaded = 1;

END

UPDATE RevenueFact SET f_timestamp = f_timestamp - INTERVAL 1 DAY

INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T22233', '3-4-555', 'S10', '2024-03-27');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T22233', '5'), ('6X6', 'T22233', '10');

--LATE DAILY FACT REFRESH
INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T25566', '3-4-555', 'S10', '2024-03-30');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T25566', '5'), ('6X6', 'T25566', '10');

INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T33448', '3-4-555', 'S5', '2024-04-03');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T33448', '3'), ('6X6', 'T33448', '2');

--- creating the Late Arriving Fact update procedure---
create procedure Late_Arriving_Fact_Refresh()
begin

DROP TABLE intermediateRevenueFactTable;
CREATE TABLE intermediateRevenueFactTable as
SELECT sv.noofitems as UnitSoldRent, sv.noofitems*p.productprice as RevenueGenerated, st.CustomerID, st.StoreID, sv.ProductID, st.tdate, st.tid,'Sales' as RevenueType, 'NoofUnitSold' as MeasureUnits
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.soldvia sv, ko_ZAGIMORE.salestransaction st
WHERE p.ProductID = sv.ProductID
AND sv.Tid = st.Tid
AND st.Tid NOT IN (SELECT TransactionID FROM RevenueFact);

ALTER TABLE intermediateRevenueFactTable CHANGE RevenueType RevenueType VARCHAR( 25 );
ALTER TABLE intermediateRevenueFactTable CHANGE MeasureUnits MeasureUnits VARCHAR( 25 );

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Sales', 'NoofUnitSold'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND LEFT(i.RevenueType,1) = LEFT(p.ProductType, 1);

INSERT INTO intermediateRevenueFactTable(UnitSoldRent, RevenueGenerated, CustomerID, StoreID, ProductID, tdate, tid, RevenueType, MeasureUnits)
SELECT rv.duration as UnitSoldRent, rv.duration*r.productpricedaily as RevenueGenerated, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, rt.tid,'Daily Rental' as RevenueType, 'Duration In Days' as MeasureUnits
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE r.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rv.rentaltype = "D"
AND rt.Tid NOT IN (SELECT TransactionID FROM RevenueFact);

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Daily Rental', 'Duration In Days'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND i.RevenueType LIKE "Daily%";

INSERT INTO intermediateRevenueFactTable(UnitSoldRent, RevenueGenerated, CustomerID, StoreID, ProductID, tdate, tid, RevenueType, MeasureUnits)
SELECT rv.duration as UnitSoldRent, rv.duration*r.productpricedaily as RevenueGenerated, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, rt.tid,'Weekly Rental' as RevenueType, 'Duration In Weeks' as MeasureUnits
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE r.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rv.rentaltype = "W"
AND rt.Tid NOT IN (SELECT TransactionID FROM RevenueFact);

INSERT INTO RevenueFact(CustomerKey, ProductKey, StoreKey,
UnitSoldRent, DollarSold, CalendarKey,TransactionID, f_timestamp, loaded, RevenueSource, MeasureUnits)
SELECT c.CustomerKey, p.ProductKey, s.StoreKey, i.UnitSoldRent,
i.RevenueGenerated, ca.CalendarKey, i.tid, NOW(), FALSE, 'Weekly Rental', 'Duration In Weeks'
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.fulldate
AND i.RevenueType LIKE "Weekly%";

INSERT INTO ko_ZAGIMORE_DW.RevenueFact(CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource)

SELECT CustomerKey, ProductKey, StoreKey, UnitSoldRent, DollarSold, CalendarKey, TransactionID, MeasureUnits, RevenueSource

FROM RevenueFact

WHERE loaded = 0;

UPDATE RevenueFact

SET loaded = 1;

END

--Create Rental trans
INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T33543', '3-4-555', 'S10', '2023-04-02');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T33543', 'D', '3');


INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T33878', '3-4-555', 'S10', '2024-04-02');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T33878', 'D', '3');

INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T11878', '3-4-555', 'S10', '2024-04-03');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T11878', 'D', '3');

INSERT INTO ko_ZAGIMORE.salestransaction (tid, customerid, storeid, tdate) VALUES ('T28383', '3-4-555', 'S10', '2024-04-03');
INSERT INTO ko_ZAGIMORE.soldvia (productid, tid, noofitems) VALUES ('1X3', 'T28383', '5'), ('6X6', 'T28383', '10');

INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T57278', '1-2-333', 'S10', '2024-04-02');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T57278', 'W', '5');

INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T12355', '5-6-777', 'S10', '2021-04-02');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T12355', 'W', '2');

INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T16978', '2-3-444', 'S10', '2024-04-03');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('5X5', 'T16978', 'W', '3');

INSERT INTO ko_ZAGIMORE.rentaltransaction (`tid`, `customerid`, `storeid`, `tdate`) VALUES ('T13145', '4-5-666', 'S3', '2024-04-03');
INSERT INTO `ko_ZAGIMORE`.`rentvia` (`productid`, `tid`, `rentaltype`, `duration`) VALUES ('3X3', 'T13145', 'D', '2');


--Daily Refresh rental
INSERT INTO intermediateRevenueFactTable(UnitSoldRent, RevenueGenerated, CustomerID, StoreID, ProductID, tdate, tid, RevenueType, MeasureUnits)
SELECT rv.duration as UnitSoldRent, rv.duration*r.productpricedaily as RevenueGenerated, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, rt.tid,'Daily Rental' as RevenueType, 'Duration In Days' as MeasureUnits
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE r.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rt.tdate > (SELECT DATE((SELECT MAX(f_timestamp) FROM RevenueFact)));


-- DAILY REFRESHING OF DIMENSION TABLES: ProductDimension example

--in ZAGIMORE_DataStaging, add colmuns "timestamp" and "load status" to the ProductDimension table

ALTER TABLE ProductDimension ADD loaded BOOLEAN NOT NULL ,

ADD ExtractionTimeStamp TIMESTAMP NOT NULL ;

--set extraction time of all current product dimension values to current time - 10 days for all timestamp values for all instances of ProductDimension so far

--- updating ProductDimension Current Status
UPDATE ProductDimension
SET Current_Status='C', DateValidUntil='2030-01-01'

--setting "loaded" values to 1 for all instances of ProductDimension so far

UPDATE ProductDimension

SET loaded = 1,

ExtractionTimeStamp = NOW()- INTERVAL 10 day;

-- setting up an example of changes in the product dimension by creating a new product
-- creating a new product
insert into ko_ZAGIMORE.product(productid,productname,productprice,vendorid,categoryid)
values ('9X1','Fancy Bike',800,'MK','CY')

--creating intermediate product dimension, containing all current slaes products,

create table ipd as
select p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
from ko_ZAGIMORE.product p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
where p.categoryid = c.categoryid
and p.vendorid = v.vendorid
AND p.productid NOT IN
(SELECT ProductID FROM ProductDimension);

insert into ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID, DateValidFrom,DateValidUntil,Status, CategoryName,ProductType,loaded, ExtractionTimeStamp)
SELECT i.productid,i.productname,i.vendorid,i.vendorname,i.categoryid, date(now()),'2030-01-01', 'C', i.categoryname,'Sales',0,now()
FROM ipd i;

insert into ko_ZAGIMORE_DW.ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType)
select r.ProductID,r.ProductName,r.VendorID,r.VendorName,r.CategoryID,r.ProductKey,r.DateValidFrom,r.DateValidUntil,r.Status,r.CategoryName,r.ProductType
from ProductDimension r
where r.loaded = 0;

--
CREATE PROCEDURE Product_Dimension_Refresh()
BEGIN
DROP TABLE ipd;
create table ipd as
select p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
from ko_ZAGIMORE.product p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
where p.categoryid = c.categoryid
and p.vendorid = v.vendorid
AND p.productid NOT IN
(SELECT ProductID FROM ProductDimension);

insert into ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID, DateValidFrom,DateValidUntil,Status, CategoryName,ProductType,loaded, ExtractionTimeStamp)
SELECT i.productid,i.productname,i.vendorid,i.vendorname,i.categoryid, date(now()),'2030-01-01', 'C', i.categoryname,'Sales',0,now()
FROM ipd i;

insert into ko_ZAGIMORE_DW.ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType)
select r.ProductID,r.ProductName,r.VendorID,r.VendorName,r.CategoryID,r.ProductKey,r.DateValidFrom,r.DateValidUntil,r.Status,r.CategoryName,r.ProductType
from ProductDimension r
where r.loaded = 0;

UPDATE ProductDimension

SET loaded = 1;

END


CREATE PROCEDURE ELT_ProductDimension_Sales_Type2Changes()
BEGIN

TRUNCATE ipd;

INSERT INTO ipd(categoryid, productid, productname, vendorid, categoryname, vendorname)
SELECT p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
WHERE p.categoryid = c.categoryid
AND p.vendorid = v.vendorid
AND CONCAT(p.productname, v.vendorname, c.categoryname) NOT IN (SELECT ProductName, VendorName, CategoryName FROM ProductDimension);;

INSERT INTO ProductDimension(CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName, DateValidFrom, DateValidUntil, loaded, ExtractionTimeStamp, ProductType, Status)
SELECT i.categoryid, i.productid, i.productname, i.vendorid, i.categoryname, i.vendorname, DATE(NOW()), '2030-01-01', 0, NOW(), 'Sales', 'C'
FROM ipd i;

Create View m1 AS
SELECT ProductID FROM ProductDimension
WHERE ProductType LIKE 'S%'
GROUP By ProductID
Having COUNT(*) > 1;

UPDATE ProductDimension
SET DateValidUntil = Date(NOW()) - Interval 1 day,
Status = 'N'
WHERE loaded = 1
AND ProductID IN (SELECT * from m1)
AND ProductType LIKE 'S%'
AND DateValidUntil > DATE(NOW());

DROP VIEW m1;

INSERT INTO ko_ZAGIMORE_DW.ProductDimension(ProductKey, CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName, DateValidFrom, DateValidUntil, ProductType, Status)
SELECT p.ProductKey, p.CategoryID, p.ProductID, p.ProductName, p.VendorID, p.CategoryName, p.VendorName, p.DateValidFrom, p.DateValidUntil, p.ProductType, p.Status
FROM ProductDimension p
WHERE p.loaded = 0;

UPDATE ko_ZAGIMORE_DW.ProductDimension dwp1, ProductDimension dwp2
SET dwp1.DateValidUntil = Date(NOW()) - Interval 1 day, dwp1.Status = 'N'
WHERE dwp1.ProductID = dwp2.ProductID
AND dwp2.DateValidFrom > dwp1.DateValidFrom
AND dwp1.Status = 'C';

UPDATE ProductDimension
SET loaded = 1
WHERE loaded = 0;

END


--Rental Product refresh
CREATE PROCEDURE Product_Dimension_Rental_Refresh()
BEGIN
DROP TABLE ipd;
create table ipd as
select p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
from ko_ZAGIMORE.rentaProducts p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
where p.categoryid = c.categoryid
and p.vendorid = v.vendorid
AND p.productid NOT IN
(SELECT ProductID FROM ProductDimension);

insert into ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID, DateValidFrom,DateValidUntil,Status, CategoryName,ProductType,loaded, ExtractionTimeStamp)
SELECT i.productid,i.productname,i.vendorid,i.vendorname,i.categoryid, date(now()),'2030-01-01', 'C', i.categoryname,'Rental',0,now()
FROM ipd i;

insert into ko_ZAGIMORE_DW.ProductDimension(ProductID,ProductName,VendorID,VendorName,CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType)
select r.ProductID,r.ProductName,r.VendorID,r.VendorName,r.CategoryID,r.ProductKey,r.DateValidFrom,r.DateValidUntil,r.Status,r.CategoryName,r.ProductType
from ProductDimension r
where r.loaded = 0;

UPDATE ProductDimension
SET loaded = 1;

END

--Rental Product typeII change
--- test each part of the procedure to be created ----
CREATE PROCEDURE ELT_ProductDimension_Rental_Type2Changes()
BEGIN

TRUNCATE ipd;

INSERT INTO ipd(categoryid, productid, productname, vendorid, categoryname, vendorname)
SELECT p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
FROM ko_ZAGIMORE.rentalProducts p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
WHERE p.categoryid = c.categoryid
AND p.vendorid = v.vendorid
AND CONCAT(p.productname, v.vendorname, c.categoryname) NOT IN (SELECT ProductName, VendorName, CategoryName FROM ProductDimension);

INSERT INTO ProductDimension(CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName, DateValidFrom, DateValidUntil, loaded, ExtractionTimeStamp, ProductType, Status)
SELECT i.categoryid, i.productid, i.productname, i.vendorid, i.categoryname, i.vendorname, DATE(NOW()), '2030-01-01', 0, NOW(), 'Rental', 'C'
FROM ipd i;

Create View m2 AS
SELECT ProductID FROM ProductDimension
WHERE ProductType LIKE 'R%'
GROUP By ProductID
Having COUNT(*) > 1;

UPDATE ProductDimension
SET DateValidUntil = Date(NOW()) - Interval 1 day,
Status = 'N'
WHERE loaded = 1
AND ProductID IN (SELECT * from m2)
AND ProductType LIKE 'R%'
AND DateValidUntil > DATE(NOW());

DROP VIEW m2;

INSERT INTO ko_ZAGIMORE_DW.ProductDimension(ProductKey, CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName, DateValidFrom, DateValidUntil, ProductType, Status)
SELECT p.ProductKey, p.CategoryID, p.ProductID, p.ProductName, p.VendorID, p.CategoryName, p.VendorName, p.DateValidFrom, p.DateValidUntil, p.ProductType, p.Status
FROM ProductDimension p
WHERE p.loaded = 0;

UPDATE ko_ZAGIMORE_DW.ProductDimension dwp1, ProductDimension dwp2
SET dwp1.DateValidUntil = Date(NOW()) - Interval 1 day, dwp1.Status = 'N'
WHERE dwp1.ProductID = dwp2.ProductID
AND dwp2.DateValidFrom > dwp1.DateValidFrom
AND dwp1.Status = 'C';

UPDATE ProductDimension
SET loaded = 1
WHERE loaded = 0;

END

-- Update Customer Dimension
INSERT INTO ko_ZAGIMORE.customer(customerid, customername, customerzip) VALUES ('1-1-111', 'Haha', '77889');
--creating intermediate customer dimension, containing all current customer,

CREATE PROCEDURE Customer_Dimension_Refresh()
BEGIN
DROP TABLE icd;
create table icd as
SELECT c.customerid, c.customername, c.customerzip
FROM ko_ZAGIMORE.customer c
WHERE c.customerid NOT IN
(SELECT CustomerID FROM CustomerDimension);

insert into CustomerDimension(CustomerID, CustomerName, CustomerZip, DateValidFrom,DateValidUntil,Status, loaded, ExtractionTimeStamp)
SELECT i.customerid,i.customername,i.customerzip, date(now()),'2030-01-01', 'C', 0,now()
FROM icd i;

insert into ko_ZAGIMORE_DW.CustomerDimension(CustomerKey, CustomerID, CustomerName, CustomerZip, DateValidFrom,DateValidUntil,Status, loaded, ExtractionTimeStamp)
select CustomerKey, CustomerID, CustomerName, CustomerZip, date(now()),'2030-01-01', 'C', 1,now()
from CustomerDimension
where loaded = 0;

UPDATE CustomerDimension
SET loaded = 1;

TRUNCATE icd;
END


CREATE PROCEDURE Customer_Dimension_TypeII()
BEGIN
DROP TABLE IF EXISTS icd;
create table icd as
SELECT c.customerid, c.customername, c.customerzip
FROM ko_ZAGIMORE.customer c
WHERE CONCAT(c.customername, c.customerid, c.customerzip) NOT IN
(SELECT CONCAT(CustomerName, CustomerID, CustomerZip) FROM ko_ZAGIMORE_DataStaging.CustomerDimension);

insert into CustomerDimension(CustomerID, CustomerName, CustomerZip, DateValidFrom,DateValidUntil,Status, loaded, ExtractionTimeStamp)
SELECT i.customerid,i.customername,i.customerzip, date(now()),'2030-01-01', 'C', 0,now()
FROM icd i;

UPDATE CustomerDimension
SET Status = "N", DateValidUntil = DATE(NOW()) - INTERVAL 1 DAY
WHERE CustomerID IN (SELECT customerid FROM icd)
AND loaded = 1;

insert into ko_ZAGIMORE_DW.CustomerDimension(CustomerID, CustomerName, CustomerZip, DateValidFrom,DateValidUntil,Status, loaded, ExtractionTimeStamp)
select CustomerID, CustomerName, CustomerZip, date(now()),'2030-01-01', 'C', 1,now()
from CustomerDimension
where loaded = 0;

UPDATE CustomerDimension
SET loaded = 1;

TRUNCATE icd;
END

--, auto scheduler for all ETL events, (not supprted by our version of MYSQL)
CREATE EVENT dailyETL
ON SCHEDULE AT '23:59:59'
EVERY 1 DAY
DO
BEGIN
CALL ETLRevenueFactAppend();
CALL ETLProductDimensionAppendNewProducts();
END