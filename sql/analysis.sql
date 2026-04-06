-- АНАЛИТИКА ВОРОНОК

-- CR пользователей
WITH user_funnel AS (
	SELECT
	    user_id,
	    MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
	    MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
	    MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
	FROM events
	GROUP BY user_id
),
funnel_counts AS (
    SELECT
        COUNT(*) FILTER (WHERE has_view = 1) AS users_view,
        COUNT(*) FILTER (WHERE has_view = 1 AND has_cart = 1) AS users_cart,
        COUNT(*) FILTER (WHERE has_view = 1 AND has_cart = 1 AND has_purchase = 1) AS users_purchase
    FROM user_funnel
)
SELECT
    users_view,
    users_cart,
    users_purchase,

    ROUND(users_cart * 100.0 / users_view, 2) AS view_to_cart_CR,
    ROUND(users_purchase * 100.0 / users_cart, 2) AS cart_to_purchase_CR,
    ROUND(users_purchase * 100.0 / users_view, 2) AS view_to_purchase_CR
    
    
FROM funnel_counts;


-- CR сессий
WITH session_funnel AS (
    SELECT
        user_session,
        MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase
    FROM events
    GROUP BY user_session
)

SELECT
    COUNT(*) FILTER (WHERE has_view = 1) AS sessions_view,
    COUNT(*) FILTER (WHERE has_cart = 1) AS sessions_cart,
    COUNT(*) FILTER (WHERE has_purchase = 1) AS sessions_purchase,

    ROUND(100.0 * COUNT(*) FILTER (WHERE has_cart = 1)
        / COUNT(*) FILTER (WHERE has_view = 1), 2) AS view_to_cart_cr,

    ROUND(100.0 * COUNT(*) FILTER (WHERE has_purchase = 1)
        / COUNT(*) FILTER (WHERE has_cart = 1), 2) AS cart_to_purchase_cr

FROM session_funnel;

-- CR / выручка по категориям
WITH category_metrics AS (
    SELECT
        p.category_code,
        e.user_id,
        e.event_type,
        e.price
    FROM events e
    JOIN products p
        ON e.product_id = p.product_id
    WHERE p.category_code IS NOT NULL
),

category_funnel AS (
    SELECT
        category_code,
        user_id,

        MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase

    FROM category_metrics
    GROUP BY category_code, user_id
),

revenue AS (
    SELECT
        category_code,
        SUM(price) AS total_revenue,
        COUNT(*) AS purchases_count
    FROM category_metrics
    WHERE event_type = 'purchase'
    GROUP BY category_code
)

SELECT
    f.category_code,

    COUNT(*) FILTER (WHERE has_view = 1) AS users_view,
    COUNT(*) FILTER (WHERE has_cart = 1) AS users_cart,
    COUNT(*) FILTER (WHERE has_purchase = 1) AS users_purchase,

    ROUND(100.0 * COUNT(*) FILTER (WHERE has_cart = 1)
        / COUNT(*) FILTER (WHERE has_view = 1), 2) AS view_to_cart_cr,

    ROUND(100.0 * COUNT(*) FILTER (WHERE has_purchase = 1)
        / COUNT(*) FILTER (WHERE has_view = 1), 2) AS view_to_purchase_cr,

    r.total_revenue,
    r.purchases_count

FROM category_funnel f
LEFT JOIN revenue r
    ON f.category_code = r.category_code

GROUP BY f.category_code, r.total_revenue, r.purchases_count
ORDER BY r.total_revenue DESC NULLS LAST
LIMIT 20


-- Запрос сверху в CTE
WITH category_metrics AS (
    SELECT
        p.category_code,
        e.user_id,
        e.event_type,
        e.price
    FROM events e
    JOIN products p
        ON e.product_id = p.product_id
    WHERE p.category_code IS NOT NULL
),

category_funnel AS (
    SELECT
        category_code,
        user_id,

        MAX(CASE WHEN event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN event_type = 'cart' THEN 1 ELSE 0 END) AS has_cart,
        MAX(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase

    FROM category_metrics
    GROUP BY category_code, user_id
),

revenue AS (
    SELECT
        category_code,
        SUM(price) AS total_revenue,
        COUNT(*) AS purchases_count
    FROM category_metrics
    WHERE event_type = 'purchase'
    GROUP BY category_code
),

cr_rev_metrics AS (

	SELECT
	    f.category_code,
	
	    COUNT(*) FILTER (WHERE has_view = 1) AS users_view,
	    COUNT(*) FILTER (WHERE has_cart = 1) AS users_cart,
	    COUNT(*) FILTER (WHERE has_purchase = 1) AS users_purchase,
	
	    ROUND(100.0 * COUNT(*) FILTER (WHERE has_cart = 1)
	        / COUNT(*) FILTER (WHERE has_view = 1), 2) AS view_to_cart_cr,
	
	    ROUND(100.0 * COUNT(*) FILTER (WHERE has_purchase = 1)
	        / COUNT(*) FILTER (WHERE has_view = 1), 2) AS view_to_purchase_cr,
	
	    r.total_revenue,
	    r.purchases_count
	
	FROM category_funnel f
	LEFT JOIN revenue r
	    ON f.category_code = r.category_code
	
	GROUP BY f.category_code, r.total_revenue, r.purchases_count
	ORDER BY r.total_revenue DESC NULLS LAST
)

SELECT *
FROM cr_rev_metrics crm
WHERE crm.view_to_purchase_cr > 5
AND crm.total_revenue < (SELECT AVG(total_revenue) FROM cr_rev_metrics)
LIMIT 30



-- сред. t до покупки
WITH first_view AS (
    SELECT
        user_id,
        MIN(event_time) AS first_view_time
    FROM events
    WHERE event_type = 'view'
    GROUP BY user_id
),

purchases AS (
    SELECT
        user_id,
        event_time AS purchase_time
    FROM events
    WHERE event_type = 'purchase'
),

first_view_prch AS (
    SELECT
        v.user_id,
        v.first_view_time,
        MIN(p.purchase_time) AS first_purchase_time
    FROM first_view v
    JOIN purchases p
        ON v.user_id = p.user_id
        AND p.purchase_time >= v.first_view_time
    GROUP BY v.user_id, v.first_view_time
)

SELECT
    ROUND(AVG(EXTRACT(EPOCH FROM (first_purchase_time - first_view_time)) / 60), 2) AS avg_mins,
    PERCENTILE_CONT(0.5) WITHIN GROUP (
    	ORDER BY EXTRACT(EPOCH FROM (first_purchase_time - first_view_time)) / 60
    ) AS median_mins,
    ROUND(MIN(EXTRACT(EPOCH FROM (first_purchase_time - first_view_time)) / 60), 2) AS min_mins,
    ROUND(MAX(EXTRACT(EPOCH FROM (first_purchase_time - first_view_time)) / 60), 2) AS max_mins
FROM first_view_prch;






