-- НОРМАЛИЗАЦИЯ
-- из начальной ненормализованной таблицы строим новые - users, sessions, events и products

CREATE TABLE IF NOT EXISTS users AS
SELECT
    user_id,
    MIN(event_time) AS first_seen
FROM events_stage
GROUP BY user_id;


CREATE TABLE IF NOT EXISTS sessions AS
SELECT 
	DISTINCT user_session,
    user_id,
    MIN(event_time) AS session_start,
    MAX(event_time) AS session_end
FROM events_stage
GROUP BY user_session, user_id;


CREATE TABLE IF NOT EXISTS events AS
SELECT
    ROW_NUMBER() OVER () AS event_id,
    user_id,
    user_session,
    event_type,
    event_time,
    product_id
FROM events_stage;


CREATE TABLE IF NOT EXISTS products AS
SELECT 
	DISTINCT product_id,
    category_code,
    brand
FROM events_stage;


-- добавляем price в events для удобства...
ALTER TABLE events ADD COLUMN IF NOT EXISTS price NUMERIC;

UPDATE events e
SET price = es.price
FROM events_stage es
WHERE e.user_id = es.user_id
  AND e.event_time = es.event_time
  AND e.product_id = es.product_id
  AND e.event_type = es.event_type;
