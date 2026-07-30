-- 1. Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- 2. Create Bridge Table
CREATE TABLE IF NOT EXISTS public.heatmap_data_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    heatmap_zone_id UUID REFERENCES public.heatmap_zones(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL,
    source_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Modify Heatmap Zones
ALTER TABLE public.heatmap_zones 
ADD COLUMN IF NOT EXISTS assigned_authority_id UUID REFERENCES public.authorities(id);

-- 4. Create the Smart Trigger Function
CREATE OR REPLACE FUNCTION public.process_complaint_heatmap()
RETURNS TRIGGER AS $$
DECLARE
    nearby_zone_id UUID;
    nearby_complaints_count INT;
    SEARCH_RADIUS_METERS INT := 200;
    THRESHOLD INT := 5;
BEGIN
    -- Check if a zone already exists nearby
    SELECT id INTO nearby_zone_id
    FROM public.heatmap_zones
    WHERE zone_type = NEW.category
      AND ST_DWithin(
          ST_MakePoint(longitude, latitude)::geography, 
          ST_MakePoint(NEW.longitude, NEW.latitude)::geography, 
          SEARCH_RADIUS_METERS
      )
    LIMIT 1;

    IF nearby_zone_id IS NOT NULL THEN
        -- Add to existing zone
        INSERT INTO public.heatmap_data_points (heatmap_zone_id, source_type, source_id)
        VALUES (nearby_zone_id, 'complaint', NEW.id);
    ELSE
        -- Count if we reached the threshold to form a new zone
        SELECT count(*) INTO nearby_complaints_count
        FROM public.complaints
        WHERE category = NEW.category
          AND ST_DWithin(
              ST_MakePoint(longitude, latitude)::geography, 
              ST_MakePoint(NEW.longitude, NEW.latitude)::geography, 
              SEARCH_RADIUS_METERS
          );

        IF nearby_complaints_count >= THRESHOLD THEN
            -- Create the new zone
            INSERT INTO public.heatmap_zones (zone_type, latitude, longitude, radius_meters, severity)
            VALUES (NEW.category, NEW.latitude, NEW.longitude, SEARCH_RADIUS_METERS, 'high')
            RETURNING id INTO nearby_zone_id;

            -- Link this complaint
            INSERT INTO public.heatmap_data_points (heatmap_zone_id, source_type, source_id)
            VALUES (nearby_zone_id, 'complaint', NEW.id);
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Attach the trigger to the complaints table
DROP TRIGGER IF EXISTS on_complaint_created ON public.complaints;
CREATE TRIGGER on_complaint_created
AFTER INSERT ON public.complaints
FOR EACH ROW
EXECUTE FUNCTION public.process_complaint_heatmap();
