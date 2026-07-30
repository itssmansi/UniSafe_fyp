-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- CITIZENS Table
CREATE TABLE public.citizens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    password_hash TEXT,
    role TEXT DEFAULT 'citizen',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- AUTHORITIES Table
CREATE TABLE public.authorities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    password_hash TEXT,
    department TEXT,
    jurisdiction TEXT,
    role TEXT DEFAULT 'authority',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- COMPLAINTS Table
CREATE TABLE public.complaints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    assigned_authority_id UUID REFERENCES public.authorities(id) ON DELETE SET NULL,
    jurisdiction TEXT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    address TEXT,
    image_url TEXT,
    status TEXT DEFAULT 'pending',
    upvote_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- COMPLAINT_VERIFICATIONS Table
CREATE TABLE public.complaint_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    complaint_id UUID REFERENCES public.complaints(id) ON DELETE CASCADE,
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(complaint_id, citizen_id)
);

-- COMPLAINT_LOGS Table
CREATE TABLE public.complaint_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    complaint_id UUID REFERENCES public.complaints(id) ON DELETE CASCADE,
    authority_id UUID REFERENCES public.authorities(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- MISSING_PERSONS Table
CREATE TABLE public.missing_persons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    age INTEGER,
    gender TEXT,
    last_seen_date TIMESTAMP WITH TIME ZONE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    description TEXT,
    image_url TEXT,
    face_encoding JSONB,
    status TEXT DEFAULT 'reported',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- MISSING_PERSON_SIGHTINGS Table
CREATE TABLE public.missing_person_sightings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    missing_person_id UUID REFERENCES public.missing_persons(id) ON DELETE CASCADE,
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    image_url TEXT,
    ai_match_score DOUBLE PRECISION,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- TRUSTED_CONTACTS Table
CREATE TABLE public.trusted_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    contact_name TEXT NOT NULL,
    contact_phone TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- EMERGENCY_ALERTS Table
CREATE TABLE public.emergency_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    alert_type TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- HEATMAP_ZONES Table
CREATE TABLE public.heatmap_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_type TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    radius_meters INTEGER,
    severity TEXT
);

-- NOTIFICATIONS Table
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    citizen_id UUID REFERENCES public.citizens(id) ON DELETE CASCADE,
    authority_id UUID REFERENCES public.authorities(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
