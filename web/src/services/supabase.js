import { createClient } from '@supabase/supabase-js';

const supabaseUrl =
  (typeof import.meta !== 'undefined' && import.meta.env?.VITE_SUPABASE_URL) ||
  'https://wcksscwgeoysnqiluxoh.supabase.co';
const supabaseKey =
  (typeof import.meta !== 'undefined' &&
    (import.meta.env?.VITE_SUPABASE_PUBLISHABLE_KEY ||
      import.meta.env?.VITE_SUPABASE_ANON_KEY)) ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indja3NzY3dnZW95c25xaWx1eG9oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUyMDQ3NzAsImV4cCI6MjEwMDc4MDc3MH0.pkS0lo2a4GGS-wDtwFzQwKMeVF-It6sPMrgooPyU-Do';

const storage = typeof window !== 'undefined' ? window.localStorage : undefined;

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: Boolean(storage),
    autoRefreshToken: true,
    detectSessionInUrl: typeof window !== 'undefined',
    ...(storage ? { storage } : {}),
  },
});
