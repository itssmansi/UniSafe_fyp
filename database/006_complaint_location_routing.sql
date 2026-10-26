-- Complaint assignment metadata and authority-scoped access.
-- Apply after confirming the deployed schema includes citizens.auth_user_id and
-- authorities.auth_user_id, as used by the existing application.
ALTER TABLE public.complaints
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS assignment_status TEXT NOT NULL DEFAULT 'manual_review',
  ADD COLUMN IF NOT EXISTS assignment_reason TEXT;

-- Keep complaint creation and its assignment audit event in one transaction.
CREATE OR REPLACE FUNCTION public.record_routed_complaint(p_complaint JSONB, p_assignment_log JSONB)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  saved_complaint public.complaints;
BEGIN
  INSERT INTO public.complaints (
    id, citizen_id, title, description, category, latitude, longitude, address,
    image_url, status, department, jurisdiction, assigned_authority_id,
    assignment_status, assignment_reason
  ) VALUES (
    COALESCE(NULLIF(p_complaint->>'id', '')::UUID, uuid_generate_v4()),
    (p_complaint->>'citizen_id')::UUID,
    p_complaint->>'title', p_complaint->>'description', p_complaint->>'category',
    NULLIF(p_complaint->>'latitude', '')::DOUBLE PRECISION,
    NULLIF(p_complaint->>'longitude', '')::DOUBLE PRECISION,
    p_complaint->>'address', p_complaint->>'image_url',
    COALESCE(p_complaint->>'status', 'pending'),
    p_complaint->>'department', p_complaint->>'jurisdiction',
    NULLIF(p_complaint->>'assigned_authority_id', '')::UUID,
    COALESCE(p_complaint->>'assignment_status', 'manual_review'),
    p_complaint->>'assignment_reason'
  ) RETURNING * INTO saved_complaint;

  INSERT INTO public.complaint_logs (complaint_id, authority_id, action, message)
  VALUES (
    saved_complaint.id,
    NULLIF(p_assignment_log->>'authority_id', '')::UUID,
    p_assignment_log->>'action',
    p_assignment_log->>'message'
  );

  RETURN jsonb_build_object(
    'id', saved_complaint.id,
    'department', saved_complaint.department,
    'jurisdiction', saved_complaint.jurisdiction,
    'assigned_authority_id', saved_complaint.assigned_authority_id,
    'assignment_status', saved_complaint.assignment_status,
    'assignment_reason', saved_complaint.assignment_reason
  );
END;
$$;

REVOKE ALL ON FUNCTION public.record_routed_complaint(JSONB, JSONB) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_routed_complaint(JSONB, JSONB) TO service_role;

ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Citizens view own complaints" ON public.complaints;
CREATE POLICY "Citizens view own complaints"
ON public.complaints FOR SELECT TO authenticated
USING (citizen_id IN (SELECT id FROM public.citizens WHERE auth_user_id = auth.uid()));

DROP POLICY IF EXISTS "Assigned authorities view complaints" ON public.complaints;
CREATE POLICY "Assigned authorities view complaints"
ON public.complaints FOR SELECT TO authenticated
USING (assigned_authority_id IN (
  SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
));

DROP POLICY IF EXISTS "Assigned authorities update complaints" ON public.complaints;
CREATE POLICY "Assigned authorities update complaints"
ON public.complaints FOR UPDATE TO authenticated
USING (assigned_authority_id IN (
  SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
))
WITH CHECK (assigned_authority_id IN (
  SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
));

-- Restrictive policies also narrow any legacy permissive policies already
-- present in the hosted project, which are not represented in this repository.
DROP POLICY IF EXISTS "Restrict complaint reads to owner or assignee" ON public.complaints;
CREATE POLICY "Restrict complaint reads to owner or assignee"
ON public.complaints AS RESTRICTIVE FOR SELECT TO public
USING (
  citizen_id IN (SELECT id FROM public.citizens WHERE auth_user_id = auth.uid())
  OR assigned_authority_id IN (
    SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Restrict complaint updates to assignee" ON public.complaints;
CREATE POLICY "Restrict complaint updates to assignee"
ON public.complaints AS RESTRICTIVE FOR UPDATE TO public
USING (assigned_authority_id IN (
  SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
))
WITH CHECK (assigned_authority_id IN (
  SELECT id FROM public.authorities WHERE auth_user_id = auth.uid()
));

CREATE INDEX IF NOT EXISTS complaints_assigned_authority_id_idx
  ON public.complaints (assigned_authority_id);
CREATE INDEX IF NOT EXISTS complaints_assignment_status_idx
  ON public.complaints (assignment_status);
