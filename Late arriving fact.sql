--Late arriving fact
--Create procedure
CREATE PROCEDURE Late_Arriving_corefact_refresh()
BEGIN
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT sv.noofitems AS UnitsSoldRent, sv.noofitems * p.productprice AS RevenueGenerated, s.tid, s.customerid, s.storeid, sv.productid, s.tdate, 'Sales' AS RevenueSource
FROM ko_ZAGI.salestransaction s, ko_ZAGI.soldvia sv, ko_ZAGI.product p
WHERE s.tid = sv.tid AND p.productid = sv.productid
AND s.tid NOT IN (SELECT tid FROM CoreFact);

INSERT INTO CoreFact(UnitsSoldRent, RevenueGenerated, RevenueSource, tid, CustomerKey, StoreKey, ProductKey, CalendarKey, loaded, f_timestamp)
SELECT i.UnitsSoldRent, i.RevenueGenerated, i.RevenueSource, i.tid, c.CustomerKey, s.StoreKey, p.ProductKey, ca.CalendarKey, FALSE, NOW()
FROM icf i, Customer_Dimension c, Store_Dimension s, Product_Dimension p, Calendar_Dimension ca 
WHERE c.CustomerID = i.customerid AND s.StoreID = i.storeid
AND ca.FullDate = i.tdate AND p.ProductID = i.productid
AND p.ProductType = 'Sales';

--Weekly rental products
DROP TABLE IF EXISTS icf;
CREATE TABLE icf AS
SELECT rv.duration AS UnitsSoldRent, rp.productpricedaily * rv.duration AS RevenueGenerated, r.tid, r.customerid, r.storeid, rv.productid, r.tdate, "Rental Weekly" AS RevenueSource
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid AND rv.rentaltype = "W"
AND r.tid NOT IN (SELECT tid FROM CoreFact);

--Daily rental products
INSERT INTO icf (UnitsSoldRent, RevenueGenerated, tid, customerid, storeid, productid, tdate, RevenueSource)
SELECT rv.duration, rp.productpricedaily * rv.duration, r.tid, r.customerid, r.storeid, rv.productid, r.tdate, "Rental Daily"
FROM ko_ZAGI.rentaltransaction r, ko_ZAGI.rentvia rv, ko_ZAGI.rentalProducts rp
WHERE r.tid = rv.tid AND rp.productid = rv.productid AND rv.rentaltype = "D"
AND r.tid NOT IN (SELECT tid FROM CoreFact);

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