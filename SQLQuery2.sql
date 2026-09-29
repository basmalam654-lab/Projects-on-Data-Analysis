--ALTER AUTHORIZATION ON DATABASE::ContosoRetailDw TO sa;
select top (1000)*
from dbo.FactOnlineSales;

select top (1000) SalesOrderNumber,SalesQuantity,SalesAmount
from dbo.FactOnlineSales;

select*
from dbo.FactOnlineSales
where StoreKey=306 ;

select StoreKey,sum(SalesQuantity) as totalsold
from dbo.FactOnlineSales
group by StoreKey;

select top(10) ProductKey,sum(SalesQuantity) as totalsold
from dbo.FactOnlineSales
where StoreKey=306
group by ProductKey
having sum(SalesQuantity)>=5000
order by totalsold desc;