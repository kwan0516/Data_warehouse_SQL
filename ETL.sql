--Data Staging
INSERT INTO CustomerDimension(CustomerID, CustomerName, CustomerZip)
SELECT c.CustomerID, c.CustomerName, c.CustomerZip
FROM ko_ZAGIMORE.customer c

--inserting data into location dimension
INSERT INTO StoreDimension(RegionID, RegionName, StoreID, StoreZip)
SELECT r.regionid, r.regionname, s.storeid, s.storezip
FROM ko_ZAGIMORE.region r, ko_ZAGIMORE.store s
WHERE r.regionid = s.regionid

--adding few columns in location dimension
ALTER TABLE Location_Dimension
ADD (DateValidFrom DATE, DateValidUntil DATE)

ALTER TABLE Location_Dimension
ADD (Status CHAR(1))

--updating status for location dimension data
UPDATE Location_Dimension
SET DateValidFrom = '2013-01-01', DateValidUntil = '2030-01-01', Status = 'C'

--inserting sales product data into product dimension
INSERT INTO ProductDimension(CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName)
SELECT p.categoryid, p.productid, p.productname, p.vendorid, c.categoryname, v.vendorname
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
WHERE p.categoryid = c.categoryid
AND p.vendorid = v.vendorid

--updating product type to sales
UPDATE ProductDimension
SET ProductType = 'Sales'

--adding few columns in product dimension
ALTER TABLE ProductDimension
ADD (DateValidFrom DATE, DateValidUntil DATE, Status CHAR(1))

--updating status for product dimension data
UPDATE ProductDimension
SET DateValidFrom = '2013-01-01', DateValidUntil = '2030-01-01', Status = 'C'

--inserting rental product data into product dimension
INSERT INTO ProductDimension(CategoryID, ProductID, ProductName, VendorID, CategoryName, VendorName)
SELECT r.categoryid, r.productid, r.productname, r.vendorid, c.categoryname, v.vendorname
FROM ko_ZAGIMORE.rentalProducts r, ko_ZAGIMORE.category c, ko_ZAGIMORE.vendor v
WHERE r.categoryid = c.categoryid
AND r.vendorid = v.vendorid

UPDATE ProductDimension
SET ProductType = 'Rental'
WHERE ProductType = ''

UPDATE ProductDimension
SET DateValidFrom = '2013-01-01', DateValidUntil = '2030-01-01', Status = 'C'
WHERE ProductType = 'Rental'

--inserting sales product price data into product price table
INSERT INTO ProductPrice(ProductKey, ProductPrice, ProductType)
SELECT pd.ProductKey, p.productprice, 'Unit Sales Price'
FROM ko_ZAGIMORE.product p, ProductDimension pd
WHERE pd.ProductID = p.productid
AND pd.ProductType = 'Sales'

--inserting daily rental product price data into product price table
INSERT INTO ProductPrice(ProductKey, ProductPrice, ProductType)
SELECT pd.ProductKey, r.productpricedaily, 'Daily Rental Price'
FROM ko_ZAGIMORE.rentalProducts r, ProductDimension pd
WHERE pd.ProductID = r.productid
AND pd.ProductType = 'Rental'

--inserting daily rental product price data into product price table
INSERT INTO ProductPrice(ProductKey, ProductPrice, ProductType)
SELECT pd.ProductKey, r.productpriceweekly, 'Weekly Rental Price'
FROM ko_ZAGIMORE.rentalProducts r, ProductDimension pd
WHERE pd.ProductID = r.productid
AND pd.ProductType = 'Rental'

--adding few columns in product price table
ALTER TABLE ProductPrice
ADD (DateValidFrom DATE, DateValidUntil DATE, Status CHAR(1))

--updating status in product price table
UPDATE ProductPrice
SET DateValidFrom = '2013-01-01', DateValidUntil = '2030-01-01', Status = 'C'


-- creating an intermediate core fact table and extracting revenue and unit sold facts, --and tid from ZAGIMORE, as well as corresponding operational key attributes for all --the dimensions

CREATE TABLE intermediateRevenueFactTable as
SELECT  sv.noofitems*p.productprice as revenueGenerated, st.CustomerID, st.StoreID, sv.ProductID, st.tdate, st.tid, 
        sv.noofitems AS UnitSold, "NoofUnitSold" AS Unitofmeasure
FROM ko_ZAGIMORE.product p, ko_ZAGIMORE.soldvia sv, ko_ZAGIMORE.salestransaction st
WHERE p.ProductID = sv.ProductID
AND sv.tid = st.tid

--add RevenueType column to the intermediateRevenueFactTable

ALTER TABLE intermediateRevenueFactTable
ADD RevenueType VARCHAR(10);

UPDATE intermediateRevenueFactTable
SET RevenueType ='Sales'

--adding revenue fact rows from daily rentals

INSERT INTO intermediateRevenueFactTable(revenueGenerated, CustomerID, StoreID, ProductID, tdate, RevenueType, tid, UnitSold, Unitofmeasure)
SELECT rp.productpricedaily*rv.duration, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, 'Daily Rental', rt.tid, rv.duration, "Duration In Days"
FROM ko_ZAGIMORE.rentalProducts rp, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE rp.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rv.rentaltype = 'D'

--adding revenue fact rows from weekly rentals
INSERT INTO intermediateRevenueFactTable(revenueGenerated, CustomerID, StoreID, ProductID, tdate, RevenueType, tid, UnitSold, Unitofmeasure)
SELECT rp.productpriceweekly*rv.duration, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, 'Weekly Rental', rt.tid, rv.duration, "Duration In Weeks"
FROM ko_ZAGIMORE.rentalProducts rp, ko_ZAGIMORE.rentvia rv, ko_ZAGIMORE.rentaltransaction rt
WHERE rp.ProductID = rv.ProductID
AND rv.Tid = rt.Tid
AND rv.rentaltype = 'W'

--Populating the Core Fact table (in data staging) from the Intermediate Revenue Fact table--

INSERT INTO RevenueFact(UnitSoldRent, DollarSold, TransactionID, CustomerKey, StoreKey,
                    ProductKey, CalendarKey, RevenueSource, MeasureUnits)
SELECT i.UnitSold, i.RevenueGenerated, i.tid, c.CustomerKey, s.StoreKey, 
        p.ProductKey,ca.CalendarKey, i.RevenueType, i.Unitofmeasure
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.FullDate
AND UPPER(i.RevenueType) LIKE CONCAT("%" ,UPPER(p.ProductType), "%")

INSERT INTO RevenueFact(UnitSoldRent, DollarSold, TransactionID, CustomerKey, StoreKey,
                    ProductKey, CalendarKey, RevenueSource, MeasureUnits)
SELECT i.UnitSold, i.RevenueGenerated, i.tid, c.CustomerKey, s.StoreKey, 
        p.ProductKey,ca.CalendarKey, i.RevenueType, i.Unitofmeasure
FROM intermediateRevenueFactTable i, CustomerDimension c,
StoreDimension s, ProductDimension p, CalendarDimension ca
WHERE i.CustomerID = c.CustomerID
AND i.StoreID = s.StoreID
AND i.ProductID = p.ProductID
AND i.tdate = ca.FullDate
AND i.RevenueType = "Weekly Rental"
AND p.ProductType = "Rental"

SELECT *
FROM CalendarDimension
WHERE FullDate = "2013-01-07"


SELECT DISTINCT ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, Status 
FROM ProductDimension

--- Loading  the Calendar Dimension in Data Warehouse from Data Staging ---

INSERT INTO ko_ZAGIMORE_DW.CalendarDimension (CalendarKey,FullDate,CalendarMonth,CalendarYear)
SELECT c.CalendarKey,c.FullDate, c.CalendarMonth, c.CalendarYear
FROM CalendarDimension AS c

-- loading other dimensions from Data Staging to Data Warehouse --

INSERT INTO ko_ZAGIMORE_DW.StoreDimension (StoreKey, StoreID, StoreZip, RegionID,
RegionName, DateValidFrom, DateValidUntil, Status)
SELECT StoreKey, StoreID, StoreZip, RegionID,
RegionName, DateValidFrom, DateValidUntil, Status
FROM StoreDimension

INSERT INTO ko_ZAGIMORE_DW.ProductDimension(ProductID,ProductName,VendorID,VendorName,
CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType)
SELECT ProductID,ProductName,VendorID,VendorName,
CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType
FROM ProductDimension

INSERT INTO ko_ZAGIMORE_DW.Product_Price(DateValidFrom, DateValidUntil, ProductKey, 
                                        ProductPrice, PriceType, Status)
SELECT DateValidFrom, DateValidUntil, ProductKey, ProductPrice, PriceType, Status
FROM ProductPrice

INSERT INTO ko_ZAGIMORE_DW.CustomerDimension(CustomerID,CustomerName,CustomerZIP,
CustomerKey,DateValidFrom,DateValidUntil,Status)
SELECT CustomerID,CustomerName,CustomerZIP,
CustomerKey,DateValidFrom,DateValidUntil,Status
FROM CustomerDimension

-- loading the core fact data from Data Staging to Data Warehouse --

INSERT INTO ko_ZAGIMORE_DW.RevenueFact(DollarSold,TransactionID,CustomerKey,MeasureUnits,
StoreKey,ProductKey,CalendarKey,RevenueSource, UnitSoldRent)
SELECT DollarSold,TransactionID,CustomerKey,MeasureUnits,
StoreKey,ProductKey,CalendarKey,RevenueSource, UnitSoldRent
FROM RevenueFact

--- Loading  the Calendar Dimension in Data Warehouse from Data Staging ---

INSERT INTO ko_ZAGIMORE_DW.CalendarDimension (CalendarKey,FullDate,CalendarMonth,CalendarYear)
SELECT c.CalendarKey,c.FullDate, c.CalendarMonth, c.CalendarYear
FROM CalendarDimension AS c

-- loading other dimensions from Data Staging to Data Warehouse --

INSERT INTO ko_ZAGIMORE_DW.StoreDimension (StoreKey, StoreID, StoreZip, RegionID,
RegionName, DateValidFrom, DateValidUntil, Status)
SELECT StoreKey, StoreID, StoreZip, RegionID,
RegionName, DateValidFrom, DateValidUntil, Status
FROM StoreDimension

INSERT INTO ko_ZAGIMORE_DW.ProductDimension(ProductID,ProductName,VendorID,VendorName,
CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType)
SELECT ProductID,ProductName,VendorID,VendorName,
CategoryID,ProductKey,DateValidFrom,DateValidUntil,Status,CategoryName,ProductType
FROM ProductDimension

INSERT INTO ko_ZAGIMORE_DW.Product_Price(DateValidFrom, DateValidUntil, ProductKey, 
                                        ProductPrice, PriceType, Status)
SELECT DateValidFrom, DateValidUntil, ProductKey, ProductPrice, PriceType, Status
FROM ProductPrice

INSERT INTO ko_ZAGIMORE_DW.CustomerDimension(CustomerID,CustomerName,CustomerZIP,
CustomerKey,DateValidFrom,DateValidUntil,Status)
SELECT CustomerID,CustomerName,CustomerZIP,
CustomerKey,DateValidFrom,DateValidUntil,Status
FROM CustomerDimension

-- loading the core fact data from Data Staging to Data Warehouse --

INSERT INTO ko_ZAGIMORE_DW.RevenueFact(DollarSold,TransactionID,CustomerKey,MeasureUnits,
StoreKey,ProductKey,CalendarKey,RevenueSource, UnitSoldRent)
SELECT DollarSold,TransactionID,CustomerKey,MeasureUnits,
StoreKey,ProductKey,CalendarKey,RevenueSource, UnitSoldRent
FROM RevenueFact

UPDATE RevenueFact
SET DollarSold = p.ProductPrice
FROM
(
SELECT pp.ProductPrice, pp.ProductKey
FROM ProductPrice pp
WHERE PriceType = 'Weekly Rental Price'
) as p
WHERE p.ProductKey = ProductKey

-- Part 4 Creating ProductCategoryDimension, ProductCategoryAggregateFact and DailyStoreSnapshot
CREATE TABLE ProductCategoryDimension AS
SELECT DISTINCT CategoryID, CategoryName FROM ProductDimension

ALTER TABLE ProductCategoryDimension ADD CategoryKey INT NOT NULL AUTO_INCREMENT,
ADD PRIMARY KEY (CategoryKey)

CREATE TABLE ProductCategoryAggregateFact AS
Select SUM(cf.UnitSoldRent) as UnitsSold,SUM(cf.DollarSold) as RevenueGenerated, cf.CalendarKey,
cf.CustomerKey, cf.StoreKey, pcd.CategoryKey, cf.RevenueSource as RevenueType, cf.MeasureUnits
from RevenueFact cf, ProductDimension pd, ProductCategoryDimension pcd
Where cf.ProductKey = pd.ProductKey and pd.CategoryID = pcd.CategoryID
group by cf.CalendarKey, cf.CustomerKey, cf.StoreKey, pd.CategoryID, pcd.CategoryKey, cf.MeasureUnits, cf.RevenueSource

CREATE TABLE ko_ZAGIMORE_DW.ProductCategoryDimension AS
SELECT * FROM ProductCategoryDimension;

CREATE TABLE ko_ZAGIMORE_DW.ProductCategoryAggregateFact AS
SELECT * FROM ProductCategoryAggregateFact

ALTER TABLE ko_ZAGIMORE_DW.ProductCategoryAggregateFact
ADD Foreign Key (CalendarKey) REFERENCES ko_ZAGIMORE_DW.CalendarDimension(CalendarKey),
ADD FOREIGN KEY (CustomerKey) REFERENCES ko_ZAGIMORE_DW.CustomerDimension(CustomerKey),
ADD FOREIGN KEY (StoreKey) REFERENCES ko_ZAGIMORE_DW.StoreDimension(StoreKey),
ADD FOREIGN KEY (CategoryKey) REFERENCES ko_ZAGIMORE_DW.ProductCategoryDimension(CategoryKey)


--Daily snapshot
CREATE TABLE DailyStoreSnapShot AS
SELECT SUM(DollarSold) AS TotalRevenue, COUNT(DISTINCT TransactionID)
AS NumTransactions, SUM(DollarSold)/COUNT(DISTINCT TransactionID)
AS AvgRevenuePerTransaction, cf.StoreKey, cf.CalendarKey
FROM RevenueFact cf
GROUP BY StoreKey, CalendarKey

CREATE TABLE FootwearDailySnapshot AS
SELECT SUM(cf.UnitSoldRent) AS FootwearUnitsSold, cf.StoreKey, cf.CalendarKey 
FROM RevenueFact cf, ProductDimension pd
WHERE pd.CategoryName="Footwear" AND cf.ProductKey=pd.ProductKey
AND cf.RevenueSource = "Sales"
GROUP BY cf.StoreKey, cf.CalendarKey


--extracting transaction count over $100 into the daily snapshot
CREATE TABLE ExpensiveTemp as
SELECT COUNT(t.TransactionID) as ExpensiveTransationCount, t.StoreKey, t.CalendarKey
FROM
(
SELECT cf.StoreKey, cf.CalendarKey, cf.TransactionID, SUM(cf.DollarSold) as TotalRevenueGenerated
FROM RevenueFact cf
GROUP BY cf.CalendarKey, cf.StoreKey, cf.TransactionID
) as t
WHERE t.TotalRevenueGenerated > 100
GROUP BY t.CalendarKey, t.StoreKey

SELECT cf.StoreKey, cf.CalendarKey, cf.TransactionID, SUM(cf.DollarSold) as TotalRevenueGenerated
FROM RevenueFact cf
GROUP BY cf.CalendarKey, cf.StoreKey, cf.TransactionID

-- adding revenue by local customers to our daily snapshot
CREATE TABLE LocalRevenueTemp AS
SELECT SUM(cf.DollarSold) AS TotalLocalRevenue, cf.StoreKey, cf.CalendarKey
FROM RevenueFact cf, StoreDimension sd, CustomerDimension cd
WHERE cf.StoreKey = sd.StoreKey
AND cf.CustomerKey = cd.CustomerKey
AND LEFT(cd.CustomerZip,2)=LEFT(sd.StoreZIP,2)
GROUP BY cf.StoreKey, cf.CalendarKey


-- merging daily snapshot w/ footwear and local transaction temp table
CREATE TABLE DailySnapshotWithFootwearAndLocal AS
SELECT ds.AvgRevenuePerTransaction, ds.CalendarKey, ds.NumTransactions, ds.StoreKey, ds.TotalRevenue, fs.FootwearUnitsSold, lt.TotalLocalRevenue
FROM DailyStoreSnapShot ds LEFT JOIN LocalRevenueTemp lt
ON(ds.CalendarKey = lt.CalendarKey) AND (ds.StoreKey = lt.StoreKey)
LEFT JOIN FootwearDailySnapshot fs 
ON(ds.CalendarKey = fs.CalendarKey) AND (ds.StoreKey = fs.StoreKey)
LEFT JOIN LocalRevenueTemp l 
ON(ds.CalendarKey = l.CalendarKey) AND (ds.StoreKey = l.StoreKey)

UPDATE DailySnapshotWithFootwearAndLocal
SET FootwearUnitsSold = 0 
WHERE FootwearUnitsSold IS NULL

UPDATE DailySnapshotWithFootwearAndLocal
SET TotalLocalRevenue = 0 
WHERE TotalLocalRevenue IS NULL

CREATE TABLE DailySnapshotWithFootwearAndLocal AS
SELECT AvgRevenuePerTransaction, CalendarKey NumTransactions, StoreKey, TotalRevenue, FootwearUnitsSold, TotalLocalRevenue 
FROM ko_ZAGIMORE_DataStaging.DailySnapshotWithFootwearAndLocal

CREATE TABLE ProductCategoryAggregateFact AS
SELECT UnitsSold, RevenueGenerated, CalendarKey, CustomerKey, StoreKey, CategoryKey, RevenueType, MeasureUnits
FROM ko_ZAGIMORE_DataStaging.ProductCategoryAggregateFact