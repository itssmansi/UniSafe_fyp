-- ============================================================
-- CITIZEN FCM TOKENS & NOTIFICATIONS RLS MIGRATION
-- ============================================================

-- 1. Create table for citizen FCM tokens
CREATE TABLE IF NOT EXISTS public.citizen_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    citizen_id UUID NOT NULL REFERENCES public.citizens(id) ON DELETE CASCADE,
    auth_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT citizen_fcm_tokens_unique_token UNIQUE (fcm_token)
);

-- 2. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS idx_citizen_fcm_tokens_citizen_id ON public.citizen_fcm_tokens(citizen_id);
CREATE INDEX IF NOT EXISTS idx_citizen_fcm_tokens_auth_user_id ON public.citizen_fcm_tokens(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_citizen_fcm_tokens_token ON public.citizen_fcm_tokens(fcm_token);

-- 3. Enable Row Level Security (RLS)
ALTER TABLE public.citizen_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies
DROP POLICY IF EXISTS "Citizens can view own tokens" ON public.citizen_fcm_tokens;
CREATE POLICY "Citizens can view own tokens"
ON public.citizen_fcm_tokens
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

DROP POLICY IF EXISTS "Citizens can insert own tokens" ON public.citizen_fcm_tokens;
CREATE POLICY "Citizens can insert own tokens"
ON public.citizen_fcm_tokens
FOR INSERT
TO authenticated
WITH CHECK (auth_user_id = auth.uid());

DROP POLICY IF EXISTS "Citizens can update own tokens" ON public.citizen_fcm_tokens;
CREATE POLICY "Citizens can update own tokens"
ON public.citizen_fcm_tokens
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid());

DROP POLICY IF EXISTS "Citizens can delete own tokens" ON public.citizen_fcm_tokens;
CREATE POLICY "Citizens can delete own tokens"
ON public.citizen_fcm_tokens
FOR DELETE
TO authenticated
USING (auth_user_id = auth.uid());

-- 5. Notifications table RLS policies
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Citizens can view own notifications" ON public.notifications;
CREATE POLICY "Citizens can view own notifications"
ON public.notifications
FOR SELECT
TO authenticated
USING (
    citizen_id IN (
        SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Citizens can insert notifications" ON public.notifications;
CREATE POLICY "Citizens can insert notifications"
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
    citizen_id IN (
        SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Citizens can update own notifications" ON public.notifications;
CREATE POLICY "Citizens can update own notifications"
ON public.notifications
FOR UPDATE
TO authenticated
USING (
    citizen_id IN (
        SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()
    )
);
