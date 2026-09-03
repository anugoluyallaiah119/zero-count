-- ============================================================================
-- Zero Count V2 — V3: analytics event pipeline (E4.4).
--
-- Client events (app start, login, game lifecycle, purchases later) arrive
-- in batches at POST /api/events and land here. Append-only like the other
-- ledgers (standards §3.2): analytics is a source of truth for funnels and
-- must never be rewritten by application code.
-- ============================================================================

CREATE TABLE analytics_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users (id),            -- NULL = pre-login event
    name        VARCHAR(64) NOT NULL,                  -- e.g. app_start, login_success
    props       JSONB NOT NULL DEFAULT '{}'::jsonb,    -- small flat payload
    client_ts   TIMESTAMPTZ NOT NULL,                  -- when the client saw it
    received_at TIMESTAMPTZ NOT NULL DEFAULT now()     -- server clock is authoritative
);

-- Funnel/retention queries slice by name + time; keep both indexed.
CREATE INDEX analytics_events_name_time ON analytics_events (name, received_at DESC);
CREATE INDEX analytics_events_time      ON analytics_events (received_at DESC);
CREATE INDEX analytics_events_user      ON analytics_events (user_id, received_at DESC);

CREATE OR REPLACE FUNCTION reject_analytics_mutation() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'analytics_events is append-only (standards §3.2)';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER analytics_events_no_mutation
    BEFORE UPDATE OR DELETE ON analytics_events
    FOR EACH ROW EXECUTE FUNCTION reject_analytics_mutation();
