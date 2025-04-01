--Daily store snapshot
CREATE TABLE DailyStoreSnapShot AS
SELECT SUM(RevenueGenerated) AS TotalRevenue, COUNT(DISTINCT tid) AS NumTransactions,
ROUND(SUM(RevenueGenerated)/COUNT(DISTINCT tid),2) AS AvgRevenuePerTransaction, StoreKey, CalendarKey 
FROM CoreFact 
GROUP BY StoreKey, CalendarKey;

--Insert into data warehouse
CREATE TABLE ko_ZAGI_Datawarehouse.DailyStoreSnapShot AS 
SELECT * 
FROM DailyStoreSnapShot

--In data warehouse
ALTER TABLE DailyStoreSnapShot 
ADD FOREIGN KEY (StoreKey) REFERENCES Store_Dimension(StoreKey),
ADD FOREIGN KEY (CalendarKey) REFERENCES Calendar_Dimension(CalendarKey)

--Daily snapshot with Local sold and footwear sold
--Local revenue temp table
CREATE TABLE LocalRevenueTemp AS
SELECT SUM(cf.RevenueGenerated) AS TotalLocalRevenue, COUNT(DISTINCT tid) AS NumLocalTranscations,
cf.StoreKey, cf.CalendarKey 
FROM CoreFact cf, Store_Dimension sd, Customer_Dimension cd 
WHERE cf.StoreKey = sd.StoreKey AND cf.CustomerKey = cd.CustomerKey
AND LEFT(cd.CustomerZip,2)=LEFT(sd.StoreZIP,2)
GROUP BY cf.StoreKey, cf.CalendarKey;

--Footwear sold temp table
CREATE TABLE FootwearRevenueTemp AS 
SELECT SUM(cf.RevenueGenerated) AS FootwearRevenue, SUM(cf.UnitsSoldRent) AS FootwearSold, 
cf.StoreKey, cf.CalendarKey 
FROM CoreFact cf, Product_Dimension pd
WHERE cf.ProductKey = pd.ProductKey 
AND pd.CategoryName = "Footwear"
GROUP BY cf.StoreKey, cf.CalendarKey;

--Combine 
CREATE TABLE DailyLocalAndFootwearSnapshot AS
SELECT lr.TotalLocalRevenue, lr.NumLocalTranscations, fr.FootwearRevenue, fr.FootwearSold, 
lr.StoreKey, lr.CalendarKey
FROM LocalRevenueTemp lr FULL OUTER JOIN FootwearRevenueTemp fr 
ON lr.CalendarKey = fr.CalendarKey;

--Insert into data warehouse
CREATE TABLE ko_ZAGI_Datawarehouse.DailyLocalAndFootwearSnapshot AS
SELECT *
FROM DailyLocalAndFootwearSnapshot

ALTER TABLE ko_ZAGI_Datawarehouse.DailyLocalAndFootwearSnapshot
ADD FOREIGN KEY (StoreKey) REFERENCES Store_Dimension(StoreKey),
ADD FOREIGN KEY (CalendarKey) REFERENCES Calendar_Dimension(CalendarKey)

--One way aggregate 
--Product category aggregate 
CREATE TABLE ProductCategory_Dimension AS 
SELECT DISTINCT CategoryID, CategoryName 
FROM Product_Dimension

ALTER TABLE ProductCategory_Dimension ADD CategoryKey INT NOT NULL AUTO_INCREMENT,
ADD PRIMARY KEY (CategoryKey)

CREATE TABLE ProductCategoryAggregateFact AS
SELECT SUM(cf.RevenueGenerated) AS RevenueGenerated, SUM(cf.UnitsSoldRent) AS UnitsSoldRent, cf.RevenueSource, cf.CustomerKey, cf.StoreKey, pcd.CategoryKey, cf.CalendarKey
FROM CoreFact cf, ProductCategory_Dimension pcd, Product_Dimension pd
WHERE pd.CategoryID = pcd.CategoryID AND cf.ProductKey = pd.ProductKey
GROUP BY cf.RevenueSource, pd.CategoryID, pcd.CategoryKey, cf.CustomerKey, cf.StoreKey, cf.CalendarKey;

--Insert into data warehouse
CREATE TABLE ko_ZAGI_Datawarehouse.ProductCategory_Dimension AS
SELECT *
FROM ProductCategory_Dimension
ALTER TABLE ko_ZAGI_Datawarehouse.ProductCategory_Dimension
ADD PRIMARY KEY (CategoryKey);

CREATE TABLE ko_ZAGI_Datawarehouse.ProductCategoryAggregateFact AS
SELECT *
FROM ProductCategoryAggregateFact;

ALTER TABLE ko_ZAGI_Datawarehouse.ProductCategoryAggregateFact
ADD FOREIGN KEY (StoreKey) REFERENCES Store_Dimension(StoreKey),
ADD FOREIGN KEY (CalendarKey) REFERENCES Calendar_Dimension(CalendarKey),
ADD FOREIGN KEY (CustomerKey) REFERENCES Customer_Dimension(CustomerKey),
ADD FOREIGN KEY (CategoryKey) REFERENCES ProductCategory_Dimension(CategoryKey);


--Two way aggregate
--Category and region aggregate
CREATE TABLE Region_Dimension AS
SELECT DISTINCT RegionID, RegionName 
FROM Store_Dimension;

ALTER TABLE Region_Dimension
ADD RegionKey INT NOT NULL AUTO_INCREMENT,
ADD PRIMARY KEY (RegionKey);

CREATE TABLE CategoryAndRegionTwowayAgg AS 
SELECT SUM(cf.RevenueGenerated) AS RevenueGenerated, SUM(cf.UnitsSoldRent) AS UnitsSoldRent, cf.RevenueSource, cf.CustomerKey, rd.RegionKey, pcd.CategoryKey, cf.CalendarKey
FROM CoreFact cf, Region_Dimension rd, Store_Dimension sd, ProductCategory_Dimension pcd, Product_Dimension pd
WHERE rd.RegionID = sd.RegionID AND cf.StoreKey = sd.StoreKey
AND pd.CategoryID = pcd.CategoryID AND cf.ProductKey = pd.ProductKey
GROUP BY cf.RevenueSource, cf.CustomerKey, rd.RegionKey, pcd.CategoryKey, cf.CalendarKey

--Insert into data warehouse
CREATE TABLE ko_ZAGI_Datawarehouse.Region_Dimension AS
SELECT *
FROM Region_Dimension;

ALTER TABLE ko_ZAGI_Datawarehouse.Region_Dimension
ADD PRIMARY KEY (RegionKey);

CREATE TABLE ko_ZAGI_Datawarehouse.CategoryAndRegionTwowayAgg AS
SELECT *
FROM CategoryAndRegionTwowayAgg;

ALTER TABLE ko_ZAGI_Datawarehouse.CategoryAndRegionTwowayAgg
ADD FOREIGN KEY (CustomerKey) REFERENCES Customer_Dimension(CustomerKey),
ADD FOREIGN KEY (RegionKey) REFERENCES Region_Dimension(RegionKey),
ADD FOREIGN KEY (CategoryKey) REFERENCES ProductCategory_Dimension(CategoryKey),
ADD FOREIGN KEY (CalendarKey) REFERENCES Calendar_Dimension(CalendarKey)

