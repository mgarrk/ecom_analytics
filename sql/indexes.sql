CREATE INDEX IF NOT exists idx_events_user_id ON events_stage(user_id);
CREATE INDEX IF NOT EXISTS idx_events_time ON events_stage(event_time);
CREATE INDEX IF NOT EXISTS idx_events_type ON events_stage(event_type);