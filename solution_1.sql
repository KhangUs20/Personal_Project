
/*Lấy ra các order_id bị hủy, 
có phương thức thanh toán là tiền mặt thuộc quận Gò Vấp trong khoảng thời gian từ tháng 2 năm 2022 đến tháng 4 năm 2022*/

    SELECT
        o.order_id
    FROM
        dbo.order_table o
    Join dbo.district_info d On o.district_id = d.district_id
    WHERE
        d.district_name = 'Go Vap'
        AND o.order_status = 'cancel'
        AND o.payment_method = 'Cash'
        AND o.create_date BETWEEN '2022-04-01' and '2022-07-31'
    ;

/*Đâu là thành phố và quân có tỉ lệ đơn hàng sử dụng phương thức thanh toán bằng wallet 
trên tổng số đơn cao nhất của quận và thành phố đó trong tháng 7 2022.*/

    WITH order_method AS(
        SELECT
            o.payment_method
            ,o.city_id
            ,o.district_id
            ,COUNT(o.order_id) as no_order
        FROM dbo.order_table AS o
        WHERE
            MONTH(o.create_date) = 7
            AND YEAR(o.create_date) = 2022
        GROUP BY o.payment_method, o.city_id, o.district_id
    ), city AS(
        SELECT
            city_id
            ,SUM(no_order) as total_order_city
        FROM 
            order_method
        GROUP BY city_id
    ), district AS (
        SELECT
            district_id
            ,SUM(no_order) as total_order_district
        FROM 
            order_method
        GROUP BY district_id
    ), per_wallet AS(
        SELECT
            payment_method
            ,no_order
            ,total_order_city
            ,total_order_district
            ,tb1.city_id
            ,tb1.district_id
            ,ROUND((CAST(no_order AS DECIMAL(10,1))/total_order_city)*100,2) as per_city
            ,ROUND((CAST(no_order AS DECIMAL(10,1))/total_order_district)*100,2) as per_district
        FROM order_method tb1
        JOIN city tb2 on tb1.city_id = tb2.city_id
        JOIN district tb3 on tb1.district_id = tb3.district_id
    WHERE payment_method = 'E-Wallet'
    ), per_wallet_city AS(
        SELECT
            city_id
            ,sum(per_city) as per_city
        FROM
            per_wallet 
        GROUP BY
            city_id    
    ), rank AS(
        SELECT
            a.city_id
            ,a.district_id
            ,b.per_city
            ,a.per_district
            ,DENSE_RANK() OVER (ORDER BY b.per_city DESC) AS city_rank
            ,DENSE_RANK() OVER(PARTITION BY a.city_id ORDER BY a.per_district DESC) AS district_rank
        FROM 
            per_wallet a
        JOIN 
            per_wallet_city b on a.city_id = b.city_id
    )

    SELECT
        city_name
        ,per_city
        ,district_name    
        ,per_district
    FROM
        rank r
    JOIN dbo.district_info d on r.city_id=d.city_id
    JOIN dbo.city_info c on r.city_id = c.city_id
    WHERE city_rank = 1
    AND district_rank = 1
    ORDER BY city_rank
    ;

/*Hãy thống kê số lượng đơn hàng và doanh số của các merchant có tên quán có chứa "bánh mì" hoặc "xôi" theo từng tháng.*/

    WITH merchant AS (
        SELECT
            merchant_id
            ,merchant_name
        FROM 
            dbo.merchant_info
        WHERE
            merchant_name LIKE '%Xôi%'
            OR merchant_name LIKE '%Bánh Mì%'
    )
    SELECT
        m.merchant_name
        ,MONTH(o.create_date) AS month
        ,count(o.order_id) AS total_volume
        ,sum(o.order_value_amount_usd) AS total_sales
    FROM 
        dbo.order_table o 
    JOIN merchant m on m.merchant_id = o.merchant_id
    GROUP BY m.merchant_name, MONTH(o.create_date) 
    ORDER BY month, total_sales DESC, total_volume DESC
    ;

/*Hãy so sánh tỉ lệ đơn hàng có 
order_distance dưới 3 km trên tổng số đơn hàng của quận Hoàng Kiếm Hà Nội và quận Bình Thạnh TPHCM*/
    WITH order_district AS (
        SELECT
            o.district_id
            ,o.city_id
            ,d.district_name
            ,count(order_id) as total_volume
        FROM 
            dbo.order_table o
        JOIN dbo.district_info d on o.district_id = d.district_id    
        WHERE 
            d.district_name IN ('Hoan Kiem','Binh Thanh')
        GROUP BY 
            o.district_id
            ,d.district_name
            ,o.city_id
    ), order_distance_under_3km AS (
        SELECT
                o.district_id
                ,o.city_id
                ,d.district_name
                ,count(order_id) as volume
            FROM 
                dbo.order_table o
            JOIN dbo.district_info d on o.district_id = d.district_id    
            WHERE 
                d.district_name IN ('Hoan Kiem','Binh Thanh')
                AND o.order_distance <= 3
            GROUP BY 
                o.district_id
                ,d.district_name
                ,o.city_id
    )
    SELECT
        tb1.district_name
        ,ROUND((CAST(tb2.volume AS DECIMAL(10,2))/ tb1.total_volume)*100,2) AS per_order
    FROM 
        order_district tb1
    JOIN order_distance_under_3km tb2 ON tb1.district_id = tb2.district_id 
    ;


/*Thành phố nào đang có trung bình service fee cao nhất trong 6 tháng cuối năm 2022 là bao nhiêu VND?*/
   
    WITH service_fee_quant_3_4 AS(
        SELECT
            district_id
            ,order_id
            ,service_fee_usd
            ,MONTH(create_date) as month
            ,YEAR(create_date) as year
        FROM
            dbo.order_table
        WHERE 
            MONTH(create_date) IN (6,7,8,9,10,11,12)
            AND YEAR(create_date) = 2022
    ), rank AS (
        SELECT
        tb2.district_name
        ,ROUND((avg(tb1.service_fee_usd)*23000),1) as avg_sercice_fee_vnd
        ,DENSE_RANK() OVER (ORDER BY avg(tb1.service_fee_usd) DESC) as rank
        FROM service_fee_quant_3_4 tb1
        JOIN district_info tb2 ON tb1.district_id = tb2.district_id
        GROUP BY tb2.district_name
    )
    SELECT
        district_name
        ,avg_sercice_fee_vnd
    FROM rank
    WHERE rank = 1  
    ;

/*Người mua thường có xu hướng mua hàng nhiều nhất và ít nhất vào ngày nào trong tuần? 
Người mua thường có xu hướng mua hàng nhiều nhất và ít nhất và buổi nào trong ngày?*/
WITH order_week AS (
    SELECT 
        DATEPART(WEEKDAY, create_date) AS day_of_week
        ,COUNT(*) as no_order
    FROM dbo.order_table
    GROUP BY DATEPART(WEEKDAY, create_date)
), rank AS ( 
    SELECT
        day_of_week
        ,no_order
        ,DENSE_RANK() OVER (ORDER BY no_order DESC) as rank
    FROM order_week
) 
SELECT day_of_week, no_order
FROM rank 
WHERE rank in (1,7)
;

WITH order_hour_day AS (
    SELECT 
        DATEPART(HOUR, create_time) AS hour_of_day
        ,COUNT(*) as no_order
    FROM dbo.order_table
    GROUP BY DATEPART(HOUR, create_time)
), rank AS ( 
    SELECT
        hour_of_day
        ,no_order
        ,DENSE_RANK() OVER (ORDER BY no_order DESC) as rank
    FROM order_hour_day
) 
SELECT hour_of_day, no_order
FROM rank 
WHERE rank in (1,24); 

/* Đâu là merchant có doanh số cao nhất (gmv) trong từng merchant_segment tại Hà Nội và Đà Nẵng?*/
WITH merchant_gmv AS (
    SELECT 
        tb3.city_name
        ,tb2.merchant_segment
        ,tb4.merchant_name
        ,sum(tb1.gmv_usd) as gmv
    FROM
        dbo.order_table tb1 
    JOIN dbo.merchant_segment tb2 ON tb1.merchant_id = tb2.merchant_id
    JOIN dbo.merchant_info tb4 ON tb1.merchant_id = tb4.merchant_id
    JOIN dbo.city_info tb3 ON tb1.city_id = tb3.city_id
    WHERE 
        tb3.city_name = 'Ha Noi City'
        OR tb3.city_name = 'Da Nang City'
    GROUP BY tb2.merchant_segment, tb3.city_name, tb4.merchant_name
), rank AS (
    SELECT
        *
        , DENSE_RANK() OVER (PARTITION BY city_name, merchant_segment ORDER BY gmv DESC) as rank
    FROM merchant_gmv
    WHERE merchant_segment IS NOT NULL
)
SELECT
    city_name
    ,merchant_segment
    ,merchant_name
    ,gmv
FROM 
    rank
WHERE rank = 1;

/*Merchant nào tại TPHCM có tỉ lệ người mua quay lại cao nhất trong tháng 7 2022?*/
WITH id_notreturn AS(
    SELECT
        tb1.user_id
        ,tb3.merchant_name
        ,count(*) as no_order
    FROM 
        dbo.order_table tb1
    JOIN  dbo.city_info tb2 ON tb1.city_id = tb2.city_id
    JOIN  dbo.merchant_info tb3 ON tb3.merchant_id = tb1.merchant_id
    WHERE
        tb2.city_name ='HCM City'
        AND YEAR(tb1.create_date) ='2022'
        AND MONTH (tb1.create_date) = '7'
    GROUP BY tb3.merchant_name, tb1.user_id
    HAVING count(*) < 2  
), no_user_merchant AS (
    SELECT
        merchant_name
        ,COUNT(DISTINCT user_id) as no_user
    FROM 
            dbo.order_table tb1
        JOIN  dbo.city_info tb2 ON tb1.city_id = tb2.city_id
        JOIN  dbo.merchant_info tb3 ON tb3.merchant_id = tb1.merchant_id
        WHERE
            tb2.city_name ='HCM City'
            AND YEAR(tb1.create_date) ='2022'
            AND MONTH (tb1.create_date) = '7'
        GROUP BY tb3.merchant_name
), no_user_not_return AS (
    SELECT
    merchant_name
    ,COUNT(*) as no_order
    FROM 
    id_notreturn
    GROUP BY merchant_name
), rank AS (
    SELECT
        tb1.merchant_name
        , (no_order*1.000/no_user)*100 as percen
        , DENSE_RANK() OVER (ORDER BY (no_order*1.000/no_user)*100) as rank
    FROM
        no_user_not_return tb1
    JOIN 
        no_user_merchant tb2 ON tb1.merchant_name = tb2.merchant_name
)
SELECT
    merchant_name
FROM 
    rank
WHERE rank = 1


/*Đâu là quận có tỉ lệ hủy đơn hàng cao nhất tại TPHCM trong tháng 5 2022*/
WITH cancel_order AS (
    SELECT
        d.district_name
        ,COUNT(*) as no_cancel_order
    FROM dbo.order_table o
    LEFT JOIN dbo.district_info d ON o.district_id = d.district_id
    WHERE 
        o.city_id IN ('217','222')
        AND o.create_date BETWEEN '2022-05-01' AND '2022-05-31'
        AND o.order_status = 'cancel'
    GROUP BY d.district_name 
), no_order AS (
    SELECT
        d.district_name
            ,COUNT(*) as no_order
    FROM dbo.order_table o
        LEFT JOIN dbo.district_info d ON o.district_id = d.district_id
        WHERE 
            o.city_id IN ('217','222')
            AND o.create_date BETWEEN '2022-05-01' AND '2022-05-31'
        GROUP BY d.district_name 
), rank AS (
    SELECT
        tb1.district_name
        ,((tb1.no_cancel_order*1.000)/tb2.no_order)*100 as cancel_rate
        ,DENSE_RANK() OVER (ORDER BY ((tb1.no_cancel_order*1.000)/tb2.no_order)*100 DESC) as rank
    FROM 
    cancel_order tb1 
    JOIN no_order tb2 ON tb1.district_name = tb2.district_name
)
SELECT
    district_name, cancel_rate
FROM rank WHERE rank = 1;

/*Hãy thống kê số lượng đơn hàng theo từng khoảng giá trị mua hàng theo từng city (order_value_amount, đơn vị: VND):
 0-50K, 50-100K, 100-200K, 200-400K, 400-600K, >600K và đưa ra nhận xét về sự phân bổ này.*/
WITH order_range AS (
    SELECT
        city_name
        ,order_id
        ,order_value_amount_usd 
    ,CASE
        WHEN order_value_amount_usd * exchange_rate < 50000 THEN '0-50K'
        WHEN order_value_amount_usd * exchange_rate BETWEEN 50000 AND 100000 THEN '50K-100K'
        WHEN order_value_amount_usd * exchange_rate BETWEEN 100000 AND 200000 THEN '100K-200K'
        WHEN order_value_amount_usd * exchange_rate BETWEEN 200000 AND 400000 THEN '200K-400K'
        WHEN order_value_amount_usd * exchange_rate BETWEEN 400000 AND 600000 THEN '400K-600K'
        ELSE '>600K'
    END AS order_range
    FROM dbo.order_table o 
    LEFT JOIN dbo.city_info c ON o.city_id = c.city_id
), no_order_range AS (
    SELECT
        city_name
        ,order_range
        ,count(*) as volume
    FROM order_range
    GROUP BY city_name, order_range
)
-- PIVOT TABLE TO VISUALIZE RESULT -- 
SELECT *
FROM no_order_range
PIVOT (
    SUM(volume)
    FOR order_range IN ([0-50K], [50K-100K], [100K-200K], [200K-400K], [400K-600K], [>600K])
) AS pivot_result
ORDER BY [0-50K] DESC, [50K-100K] DESC, [100K-200K] DESC, [200K-400K] DESC , [400K-600K] DESC, [>600K] DESC;

/*
-Các đơn hàng được nằm trong khoảng từ 0K-400K có số lượng đặt nhiều hơn các đơn hàng >400k, 
có thể xem khoảng 0-400 là khoảng chi tiêu mà khách hàng có thể chấp nhận được cho 1 đơn hàng.

-Thành phố HCM có số lượng đơn đặt hàng nhiều nhất.

- Thành phố Đà Nẵng có số lượng đơn đặt hàng chủ yếu nằm trong khoảng 0-100k, 
khác với Hà Nội, đơn đặt hàng chủ yếu nằm trong khoảng 50k-200k.
*/

SELECT t2.city_name
        , CASE WHEN gmv_usd*exchange_rate <= 50000 THEN '1. 0-50k' 
                WHEN gmv_usd*exchange_rate > 50000 AND gmv_usd*exchange_rate <= 100000 THEN '2. 50-100k' 
                WHEN gmv_usd*exchange_rate > 100000 AND gmv_usd*exchange_rate <= 200000 THEN '3. 100-200k' 
                WHEN gmv_usd*exchange_rate > 200000 AND gmv_usd*exchange_rate <= 400000 THEN '4. 200-400k' 
                WHEN gmv_usd*exchange_rate > 400000 AND gmv_usd*exchange_rate <= 600000 THEN '5. 400-600k'
                ELSE  '6. Above 600k' END AS gmv_range


        , COUNT(order_id) AS total_net_orders
        , COUNT(DISTINCT CASE WHEN order_status = 'cancel' THEN order_id ELSE NULL END) AS cancel_orders
        , COUNT(DISTINCT CASE WHEN order_status = 'cancel' THEN order_id ELSE NULL END)*1.000/COUNT(order_id) AS cancel_orders_ratio
FROM order_table t1 
LEFT JOIN city_info t2 ON t1.city_id = t2.city_id
LEFT JOIN district_info t3 ON t1.district_id = t3.district_id
WHERE --order_status = 'delivered' AND--
 city_name IS NOT NULL 
GROUP BY t2.city_name 
    , CASE WHEN gmv_usd*exchange_rate <= 50000 THEN '1. 0-50k' 
                WHEN gmv_usd*exchange_rate > 50000 AND gmv_usd*exchange_rate <= 100000 THEN '2. 50-100k' 
                WHEN gmv_usd*exchange_rate > 100000 AND gmv_usd*exchange_rate <= 200000 THEN '3. 100-200k' 
                WHEN gmv_usd*exchange_rate > 200000 AND gmv_usd*exchange_rate <= 400000 THEN '4. 200-400k' 
                WHEN gmv_usd*exchange_rate > 400000 AND gmv_usd*exchange_rate <= 600000 THEN '5. 400-600k'
                ELSE  '6. Above 600k' END
ORDER BY city_name,gmv_range;