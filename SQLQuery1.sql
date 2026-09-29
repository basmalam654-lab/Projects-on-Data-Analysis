use ContosoRetailDW
go 

select top(100) ProductKey
from dbo.FactOnlineSales;
-------
select top(100) fos.ProductKey,dp.ProductName,fos.StoreKey,ds.StoreName,fos.CustomerKey,dc.FirstName
from dbo.FactOnlineSales as fos
left join dbo.DimProduct as dp
on fos.ProductKey=dp.ProductKey
left join dbo.DimStore as ds
on fos.StoreKey=ds.StoreKey
left join dbo.DimCustomer as dc
on fos.CustomerKey=dc.CustomerKey;
-------
select dp.ProductName,ds.StoreName,sum(fos.SalesAmount) as totalsales ,sum(fos.SalesQuantity) as sold,avg(fos.UnitCost) as avg
from dbo.FactOnlineSales as fos
left join dbo.DimProduct as dp
on fos.ProductKey=dp.ProductKey
left join dbo.DimStore as ds
on fos.StoreKey=ds.StoreKey
where fos.DateKey >= '2009-01-01' and fos.DateKey <= '2009-12-31'
--- where year(fos.DateKey)=2009
group by ds.StoreName,dp.ProductName
having sum(fos.SalesQuantity)>=7500
order by ds.StoreName asc , sold desc;
----
--highest  10 customers -sales amount @ 2008(customer first name  , total sales)
select top(10) dc.FirstName,sum(fos.SalesAmount) as totalsales
from dbo.FactOnlineSales as fos
left join dbo.DimCustomer as dc
on fos.CustomerKey=dc.CustomerKey
where year(fos.DateKey)=2008
group by dc.FirstName
having dc.FirstName is not null
order by totalsales desc;
