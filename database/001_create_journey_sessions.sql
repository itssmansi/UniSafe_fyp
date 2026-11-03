-- ============================================================================
-- Safe Journey - journey_sessions Table & Policies Migration
-- UniSafe FYP
-- ============================================================================

-- 1. Create journey_sessions table
CREATE TABLE IF NOT EXISTS public.journey_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID NOT NULL REFERENCES public.citizens(id) ON DELETE CASCADE,
    start_latitude DOUBLE PRECISION NOT NULL,
    start_longitude DOUBLE PRECISION NOT NULL,
    destination_latitude DOUBLE PRECISION NOT NULL,
    destination_longitude DOUBLE PRECISION NOT NULL,
    destination_name TEXT NOT NULL,
    latest_latitude DOUBLE PRECISION NOT NULL,
    latest_longitude DOUBLE PRECISION NOT NULL,
    last_location_update TIMESTAMPTZ NOT NULL DEFAULT now(),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    tracking_token TEXT NOT NULL UNIQUE,
    token_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Indexes for efficient lookup
CREATE INDEX IF NOT EXISTS idx_journey_sessions_citizen_id 
    ON public.journey_sessions(citizen_id);

CREATE INDEX IF NOT EXISTS idx_journey_sessions_status 
    ON public.journey_sessions(status);

CREATE INDEX IF NOT EXISTS idx_journey_sessions_tracking_token 
    ON public.journey_sessions(tracking_token);

CREATE INDEX IF NOT EXISTS idx_journey_sessions_citizen_status 
    ON public.journey_sessions(citizen_id, status);

-- 3. Automatic updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_journey_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_journey_sessions_updated_at ON public.journey_sessions;
CREATE TRIGGER trg_journey_sessions_updated_at
    BEFORE UPDATE ON public.journey_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_journey_sessions_updated_at();

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.journey_sessions ENABLE ROW LEVEL SECURITY;

-- 4.1 Policy: Citizens can view only their own journey sessions
DROP POLICY IF EXISTS "Citizens can view own journey sessions" ON public.journey_sessions;
CREATE POLICY "Citizens can view own journey sessions"
ON public.journey_sessions
FOR SELECT
TO authenticated
USING (
    citizen_id IN (
        SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
    )
);

-- 4.2 Policy: Citizens can create a journey session only for their own profile
DROP POLICY IF EXISTS "Citizens can create own journey sessions" ON public.journey_sessions;
CREATE POLICY "Citizens can create own journey sessions"
ON public.journey_sessions
FOR INSERT
TO authenticated
WITH CHECK (
    citizen_id IN (
        SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
    )
);

-- 4.3 Policy: Citizens can update only their own journey sessions
DROP POLICY IF EXISTS "Citizens can update own journey sessions" ON public.journey_sessions;
CREATE POLICY "Citizens can update own journey sessions"
ON public.journey_sessions
FOR UPDATE
TO authenticated
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

-- 5. Enable Supabase Realtime for journey_sessions
ALTER TABLE public.journey_sessions REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'journey_sessions'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.journey_sessions;
    END IF;
END $$;

-- 6. Secure Public Tracking Function (SECURITY DEFINER)
-- Allows external tracking page to retrieve live location using tracking_token
-- without exposing full table access or sensitive citizen profile fields.
CREATE OR REPLACE FUNCTION public.get_public_journey_tracking(token_input TEXT)
RETURNS TABLE (
    journey_id UUID,
    status VARCHAR(20),
    destination_name TEXT,
    start_latitude DOUBLE PRECISION,
    start_longitude DOUBLE PRECISION,
    destination_latitude DOUBLE PRECISION,
    destination_longitude DOUBLE PRECISION,
    latest_latitude DOUBLE PRECISION,
    latest_longitude DOUBLE PRECISION,
    last_location_update TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    is_active BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        js.id,
        js.status,
        js.destination_name,
        js.start_latitude,
        js.start_longitude,
        js.destination_latitude,
        js.destination_longitude,
        js.latest_latitude,
        js.latest_longitude,
        js.last_location_update,
        js.started_at,
        js.ended_at,
        (js.status = 'active' AND js.token_expires_at > now()) AS is_active
    FROM public.journey_sessions js
    WHERE js.tracking_token = token_input
      AND js.status = 'active'
      AND js.token_expires_at > now();
END;
$$;

-- Grant execution to anon (public with token) and authenticated users
REVOKE ALL ON FUNCTION public.get_public_journey_tracking(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_journey_tracking(TEXT) TO anon, authenticated;
