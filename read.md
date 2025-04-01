# Building dataware house and analytica table

## Introduction
Data is retrieved from the raw database(ko_ZAGIMORE) and stored in a staging area(ko_ZAGIMORE_datastaging) using SQL queries. Once the raw data has been extracted, the transformation phase begins. Data transformation in this project includes aggregation, and daily snapshot. 
Finally, during the loading phase, the transformed data is loaded into the target data warehouse(ko_ZAGIMORE_DW).

## Relational Schema
Database (ko_ZAGIMORE)
- ![Database](/img/ko_ZAGIMORE.png)

Data warehouse (ko_ZAGIMORE_DW)
- ![Data_warehouse](/img/ko_ZAGIMORE_DW.png)