CREATE TABLE IF NOT EXISTS events_stage AS
SELECT
    user_id,
    user_session,
    event_type,
    event_time::TIMESTAMP AS event_time,
    product_id,
    category_code,
    brand,
    price::NUMERIC
FROM raw_events
WHERE user_id IS NOT NULL;