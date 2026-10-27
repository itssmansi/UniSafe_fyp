-- ============================================================================
-- Migration: 007_fix_sos_events_journey_fkey.sql
-- Description: Fixes foreign key constraint on sos_events.journey_id to reference
--              public.journey_sessions(id) instead of obsolete safe_journeys.
-- Project: UniSafe FYP
-- ============================================================================

ALTER TABLE public.sos_events 
    DROP CONSTRAINT IF EXISTS sos_events_journey_id_fkey;

ALTER TABLE public.sos_events
    ADD CONSTRAINT sos_events_journey_id_fkey 
    FOREIGN KEY (journey_id) 
    REFERENCES public.journey_sessions(id) 
    ON DELETE SET NULL;
