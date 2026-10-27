import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://wcksscwgeoysnqiluxoh.supabase.co';
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || 
                    import.meta.env.VITE_SUPABASE_ANON_KEY || 
                    'sb_publishable_fm-MbbqWBeDctqRdUflgCg_qQq5pmxt';

export const supabase = createClient(supabaseUrl, supabaseKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: window.localStorage
  }
});
