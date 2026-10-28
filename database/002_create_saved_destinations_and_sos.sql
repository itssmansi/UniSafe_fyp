-- ============================================================================
-- Migration: 002_create_saved_destinations_and_sos.sql
-- Description: Creates saved_destinations table and configures RLS for saved_destinations and sos_events
-- Project: UniSafe FYP
-- ============================================================================

-- 1. Create saved_destinations table
CREATE TABLE IF NOT EXISTS public.saved_destinations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID NOT NULL REFERENCES public.citizens(id) ON DELETE CASCADE,
    destination_name TEXT NOT NULL,
    address TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_citizen_destination_name UNIQUE (citizen_id, destination_name)
);

-- Indexes for saved_destinations
CREATE INDEX IF NOT EXISTS idx_saved_destinations_citizen_id 
    ON public.saved_destinations(citizen_id);

-- Automatic updated_at trigger for saved_destinations
CREATE OR REPLACE FUNCTION public.handle_saved_destinations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_saved_destinations_updated_at ON public.saved_destinations;
CREATE TRIGGER trg_saved_destinations_updated_at
    BEFORE UPDATE ON public.saved_destinations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_saved_destinations_updated_at();

-- Enable RLS on saved_destinations
ALTER TABLE public.saved_destinations ENABLE ROW LEVEL SECURITY;

-- RLS Policies for saved_destinations
DROP POLICY IF EXISTS "Citizens can view own saved destinations" ON public.saved_destinations;
CREATE POLICY "Citizens can view own saved destinations"
    ON public.saved_destinations FOR SELECT
    USING (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Citizens can create own saved destinations" ON public.saved_destinations;
CREATE POLICY "Citizens can create own saved destinations"
    ON public.saved_destinations FOR INSERT
    WITH CHECK (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Citizens can update own saved destinations" ON public.saved_destinations;
CREATE POLICY "Citizens can update own saved destinations"
    ON public.saved_destinations FOR UPDATE
    USING (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    )
    WITH CHECK (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Citizens can delete own saved destinations" ON public.saved_destinations;
CREATE POLICY "Citizens can delete own saved destinations"
    ON public.saved_destinations FOR DELETE
    USING (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

-- 2. Enhance sos_events table
ALTER TABLE public.sos_events 
    ADD COLUMN IF NOT EXISTS triggered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

-- Indexes for sos_events
CREATE INDEX IF NOT EXISTS idx_sos_events_citizen_id 
    ON public.sos_events(citizen_id);

CREATE INDEX IF NOT EXISTS idx_sos_events_status 
    ON public.sos_events(status);

-- Enable RLS on sos_events
ALTER TABLE public.sos_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for sos_events
DROP POLICY IF EXISTS "Citizens can view own sos events" ON public.sos_events;
CREATE POLICY "Citizens can view own sos events"
    ON public.sos_events FOR SELECT
    USING (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Citizens can create own sos events" ON public.saved_destinations;
DROP POLICY IF EXISTS "Citizens can create own sos events" ON public.sos_events;
CREATE POLICY "Citizens can create own sos events"
    ON public.sos_events FOR INSERT
    WITH CHECK (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Citizens can update own sos events" ON public.sos_events;
CREATE POLICY "Citizens can update own sos events"
    ON public.sos_events FOR UPDATE
    USING (
        citizen_id IN (
            SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
        )
    );

-- Add saved_destinations and sos_events to realtime publication
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'saved_destinations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.saved_destinations;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'sos_events'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.sos_events;
    END IF;
END $$;
