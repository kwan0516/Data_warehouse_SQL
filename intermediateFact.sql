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
SELECT rp.productpricedaily*rv.duration, rt.CustomerID, rt.StoreID, rv.ProductID, rt.tdate, 'Weekly Rental', rt.tid, rv.duration, "Duration In Weeks"
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

SELECT *
FROM CalendarDimension
WHERE FullDate = "2013-01-07"


SELECT DISTINCT ProductID, ProductName, VendorID, VendorName, CategoryID, CategoryName, ProductType, DateValidFrom, DateValidUntil, Status 
FROM ProductDimension