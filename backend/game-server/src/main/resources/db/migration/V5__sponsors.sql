-- V5: C1.2 sponsored events — sponsor registry; contests.sponsor_id gains
-- a real FK now that the table exists.
CREATE TABLE sponsors (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(80) NOT NULL UNIQUE,
    logo_url   VARCHAR(255),
    site_url   VARCHAR(255),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE contests
    ADD CONSTRAINT contests_sponsor_fk
    FOREIGN KEY (sponsor_id) REFERENCES sponsors(id);
