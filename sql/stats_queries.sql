-- ЗАПРОСЫ ДЛЯ ДИАГРАММ / СТАТИСТИКИ

-- Топ-10 категорий по выручке
WITH category_revenue AS (
    SELECT
        p.category_code,
        SUM(e.price) AS revenue
    FROM events e
    JOIN products p
        ON e.product_id = p.product_id
    WHERE e.event_type = 'purchase'
      AND p.category_code IS NOT NULL
    GROUP BY p.category_code
),

ranked AS (
    SELECT
        category_code,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC) AS rn
    FROM category_revenue
)

SELECT
    CASE 
        WHEN rn <= 10 THEN category_code
        ELSE 'Другие'
    END AS category_group,
    SUM(revenue) AS total_rev
FROM ranked
GROUP BY category_group
ORDER BY total_rev DESC;
	

-- Топ-10 категория по CR
WITH category_funnel AS (
    SELECT
        p.category_code,
        e.user_id,

        MAX(CASE WHEN e.event_type = 'view' THEN 1 ELSE 0 END) AS has_view,
        MAX(CASE WHEN e.event_type = 'purchase' THEN 1 ELSE 0 END) AS has_purchase

    FROM events e
    JOIN products p
        ON e.product_id = p.product_id
    WHERE p.category_code IS NOT NULL
    GROUP BY p.category_code, e.user_id
),

category_cr AS (
    SELECT
        category_code,

        COUNT(*) FILTER (WHERE has_view = 1) AS users_view,

        ROUND(
            100.0 * COUNT(*) FILTER (WHERE has_purchase = 1)
            / COUNT(*) FILTER (WHERE has_view = 1),
        2) AS view_to_purchase_cr

    FROM category_funnel
    GROUP BY category_code
    HAVING COUNT(*) FILTER (WHERE has_view = 1) >= 100
)

SELECT
    category_code,
    view_to_purchase_cr,
    users_view
FROM category_cr
ORDER BY view_to_purchase_cr DESC
LIMIT 10;


-- доля быстрых покупок (до 10 минут)
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
    COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (first_purchase_time - first_view_time)) / 60 <= 10) * 100.0 / COUNT(*) AS fast_prch_share
FROM first_view_prch;