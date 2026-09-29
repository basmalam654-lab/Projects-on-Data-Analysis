use ContosoRetailDW
go

select fos.SalesOrderNumber,CONCAT(dc.FirstName,' ',dc.LastName),dsc.ProductSubcategoryName,dp.productname,fos.SalesAmount
from factonlinesales as fos
inner join dimcustomer as dc
on fos.customerkey = dc.customerkey
inner join dimproduct as dp
on fos.ProductKey=dp.ProductKey
left join DimProductSubcategory as dsc
on dp.ProductSubcategoryKey=dsc.ProductSubcategoryKey
left join DimProductcategory as dpc
on dsc.ProductCategoryKey=dpc.ProductCategoryKey
where FirstName is null;

select * from DimCustomer
where FirstName is null;

--where distinct 