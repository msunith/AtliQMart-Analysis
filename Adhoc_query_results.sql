-- Business Requests
-- 1.List of all products with base price >500 featured in proo type BOGOF
select distinct p.product_name,base_price from fact_events f
	inner join dim_products p using (product_code) 
	where base_price > 500 and promo_type ="BOGOF"; 

-- 2. Number of stores in each city
select city,count(store_id) as store_count from dim_stores 
	group by city order by store_count desc;
    
-- 3. Campaign name along with total revenue before and after the campaign 
-- campaign_name,total_revenue_before_promo,total_revenue_before_promo
with cte1 as
	( select campaign_id,promo_type,base_price,
		CASE
            WHEN promo_type = "50% off" THEN base_price * (1 - 0.50)
            WHEN promo_type = "25% off" THEN base_price * (1 - 0.25)
            WHEN promo_type = "bogof" THEN base_price * (1 - 0.50)
            WHEN promo_type = "500 cashback" THEN (base_price - 500)
            WHEN promo_type = "33% off" THEN base_price * (1 - 0.33)
            ELSE base_price
        END AS new_promo_price, 
        CASE
			WHEN promo_type = "bogof" THEN  `quantity_sold(after_promo)`* 2
            ELSE `quantity_sold(after_promo)`
		END AS qty_after_promo,
        `quantity_sold(before_promo)` as qty_before_promo
        from fact_events)
	select c.campaign_name, round(sum(base_price*qty_before_promo)/1000000,2) as revenue_before_promo_mln, 
		round(sum(new_promo_price * qty_after_promo)/1000000,2) as revenue_after_promo_mln from cte1 ct
        inner join dim_campaigns c using (campaign_id)
        group by ct.campaign_id;
        
-- 4.Incremental Sold Quantity(ISU) for each category during the diwali campaign
-- category, ISU%,rank order
with cte1 as
	( select p.category,c.campaign_name, sum(`quantity_sold(before_promo)`) as qty_before_promo,
		sum(CASE
			WHEN promo_type = "bogof" THEN  `quantity_sold(after_promo)`* 2
            ELSE `quantity_sold(after_promo)`
		END) AS qty_after_promo
        from fact_events f 
		inner join dim_products p using (product_code)
        inner join dim_campaigns c using (campaign_id)
        where campaign_name ="Diwali" group by category),
cte2 as 
(select category, qty_before_promo, qty_after_promo , qty_after_promo - qty_before_promo as ISU,
(qty_after_promo - qty_before_promo)/qty_before_promo*100 as ISU_Percent from  cte1)
 select *,dense_rank() over (order by ISU_percent desc) as Rank_order from cte2;

-- 5.Top 5 products ranked by IR% across all campaigns
-- product_name,category,IR%

with cte1 as
	( select f.product_code,p.category,p.product_name,base_price,
		CASE
            WHEN promo_type = "50% off" THEN base_price * (1 - 0.50)
            WHEN promo_type = "25% off" THEN base_price * (1 - 0.25)
            WHEN promo_type = "bogof" THEN base_price * (1 - 0.50)
            WHEN promo_type = "500 cashback" THEN (base_price - 500)
            WHEN promo_type = "33% off" THEN base_price * (1 - 0.33)
            ELSE base_price
        END AS new_promo_price, 
        CASE
			WHEN promo_type = "bogof" THEN  `quantity_sold(after_promo)`* 2
            ELSE `quantity_sold(after_promo)`
		END AS qty_after_promo,
        `quantity_sold(before_promo)` as qty_before_promo
        from fact_events f inner join dim_products p using (product_code)),
		cte2 as
		(select product_name, category,round((sum(new_promo_price * qty_after_promo)-sum(base_price *qty_before_promo))/sum(base_price *qty_before_promo)*100,2) as `IR%` from cte1 group by product_name )
    select *,dense_rank() over( order by `IR%` desc) as `rank` from  cte2 limit 5;
