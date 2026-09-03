-- ============================================================================
-- Zero Count V2 — V2: auth refresh tokens (E2.3).
--
-- Refresh tokens are never stored in plaintext: only the SHA-256 hash is
-- persisted (standards §3.3 — tokens are secrets; a DB leak must not leak
-- usable credentials). Rotation: every refresh revokes the old token.
-- ============================================================================

CREATE TABLE refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,        -- SHA-256 hex of the opaque token
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,                        -- set on rotation/logout; NULL = active
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);
-- Lookup path on refresh: hash → row, only when still valid.
CREATE INDEX idx_refresh_tokens_active ON refresh_tokens (token_hash)
    WHERE revoked_at IS NULL;
