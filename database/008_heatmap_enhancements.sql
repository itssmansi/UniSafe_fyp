-- ====================================================================
-- 008_heatmap_enhancements.sql
-- Heatmap Enhancements: Indices, Role-Based Views, and RLS Policies
-- ====================================================================

-- 1. Ensure PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Add extra classification columns to heatmap_zones if missing
ALTER TABLE public.heatmap_zones
  ADD COLUMN IF NOT EXISTS department TEXT,
  ADD COLUMN IF NOT EXISTS jurisdiction TEXT,
  ADD COLUMN IF NOT EXISTS risk_score DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS complaint_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- 3. Add indices for fast spatial and departmental heatmap queries
CREATE INDEX IF NOT EXISTS idx_heatmap_zones_coords
  ON public.heatmap_zones (latitude, longitude);

CREATE INDEX IF NOT EXISTS idx_heatmap_zones_department
  ON public.heatmap_zones (department);

CREATE INDEX IF NOT EXISTS idx_heatmap_zones_zone_type
  ON public.heatmap_zones (zone_type);

CREATE INDEX IF NOT EXISTS idx_complaints_coords_category
  ON public.complaints (latitude, longitude, category);

CREATE INDEX IF NOT EXISTS idx_missing_persons_coords
  ON public.missing_persons (latitude, longitude)
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- 4. Enable RLS on heatmap tables
ALTER TABLE public.heatmap_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.heatmap_data_points ENABLE ROW LEVEL SECURITY;

-- 5. Public / Authenticated read policies for heatmap_zones
-- Heatmap zones aggregate anonymous spatial clusters, never exposing citizen PII.
DROP POLICY IF EXISTS "Public and authenticated can view heatmap zones" ON public.heatmap_zones;
CREATE POLICY "Public and authenticated can view heatmap zones"
ON public.heatmap_zones
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "Public and authenticated can view heatmap data points" ON public.heatmap_data_points;
CREATE POLICY "Public and authenticated can view heatmap data points"
ON public.heatmap_data_points
FOR SELECT
TO anon, authenticated
USING (true);

-- 6. RPC Function: get_role_heatmap_zones
-- Returns role-scoped zones and metadata directly from the database
CREATE OR REPLACE FUNCTION public.get_role_heatmap_zones(
  p_role TEXT DEFAULT 'citizen',
  p_department TEXT DEFAULT NULL,
  p_jurisdiction TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  zone_type TEXT,
  department TEXT,
  jurisdiction TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  radius_meters INTEGER,
  severity TEXT,
  risk_score DOUBLE PRECISION,
  complaint_count INTEGER,
  assigned_authority_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF LOWER(p_department) LIKE '%bmc%' OR LOWER(p_department) LIKE '%municipal%' THEN
    -- BMC sees only civic issues: Greenery, Infrastructure, Sanitation
    RETURN QUERY
    SELECT 
      hz.id, hz.zone_type, hz.department, hz.jurisdiction,
      hz.latitude, hz.longitude, hz.radius_meters, hz.severity,
      hz.risk_score, hz.complaint_count, hz.assigned_authority_id
    FROM public.heatmap_zones hz
    WHERE LOWER(hz.zone_type) NOT IN ('safety', 'theft', 'assault', 'harassment', 'violence', 'women safety', 'missing_person')
      AND (hz.department IS NULL OR LOWER(hz.department) LIKE '%bmc%' OR LOWER(hz.department) LIKE '%municipal%')
      AND (p_jurisdiction IS NULL OR hz.jurisdiction IS NULL OR hz.jurisdiction = p_jurisdiction);

  ELSIF LOWER(p_department) LIKE '%police%' THEN
    -- Police sees only public safety and missing persons
    RETURN QUERY
    SELECT 
      hz.id, hz.zone_type, hz.department, hz.jurisdiction,
      hz.latitude, hz.longitude, hz.radius_meters, hz.severity,
      hz.risk_score, hz.complaint_count, hz.assigned_authority_id
    FROM public.heatmap_zones hz
    WHERE (LOWER(hz.zone_type) IN ('safety', 'theft', 'assault', 'harassment', 'violence', 'women safety', 'missing_person')
           OR hz.department = 'Police')
      AND (p_jurisdiction IS NULL OR hz.jurisdiction IS NULL OR hz.jurisdiction = p_jurisdiction);

  ELSE
    -- Citizen sees combined public civic and public safety heatmap
    RETURN QUERY
    SELECT 
      hz.id, hz.zone_type, hz.department, hz.jurisdiction,
      hz.latitude, hz.longitude, hz.radius_meters, hz.severity,
      hz.risk_score, hz.complaint_count, hz.assigned_authority_id
    FROM public.heatmap_zones hz;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_role_heatmap_zones(TEXT, TEXT, TEXT) TO anon, authenticated, service_role;
