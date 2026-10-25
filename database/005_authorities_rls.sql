-- 005_authorities_rls.sql
-- Enforce Row Level Security on authorities table

ALTER TABLE public.authorities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated can view authorities" ON public.authorities;
DROP POLICY IF EXISTS "Authorities self update" ON public.authorities;

-- Authenticated users can view authority profiles (needed to display department and assigned authority)
CREATE POLICY "Authenticated can view authorities"
ON public.authorities
FOR SELECT
TO authenticated
USING (true);

-- Authorities can update only their own phone/details if needed
CREATE POLICY "Authorities self update"
ON public.authorities
FOR UPDATE
TO authenticated
USING (auth.uid() = auth_user_id OR auth.uid() = id)
WITH CHECK (auth.uid() = auth_user_id OR auth.uid() = id);

-- No INSERT or DELETE policies granted to public/authenticated.
-- Prevents unauthorized registration or deletion of authorities.
