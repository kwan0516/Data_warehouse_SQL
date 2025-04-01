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
Where cf.ProductKey = pd.ProductKey and
pd.CategoryID = pcd.CategoryID
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