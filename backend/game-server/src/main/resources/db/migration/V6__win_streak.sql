-- ---------------------------------------------------------------------------
-- V6 (R1.6): consecutive-win streak tracking for the Rematch / retention loop.
--   win_streak       = current run of consecutive wins (reset to 0 on any loss)
--   best_win_streak  = personal all-time peak (monotonic, for profile badges)
-- ---------------------------------------------------------------------------
ALTER TABLE statistics
    ADD COLUMN win_streak      INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN best_win_streak INTEGER NOT NULL DEFAULT 0;
