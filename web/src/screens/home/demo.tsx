import { useState, useEffect } from "react";
import { Hero2 } from "./index";
import { supabase } from "../../services/supabase";

import CitizenNotificationBell from "../../components/citizen/CitizenNotificationBell";

export default function Hero2Demo() {
  const [session, setSession] = useState<any>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  const roleType = session?.user?.user_metadata?.role_type || session?.user?.user_metadata?.role;
  const isAuthority = roleType === 'authority' || Boolean(localStorage.getItem('unisafe_authority'));

  const customNavLinks = [
    { label: "Home", href: "/", active: true },
    { label: "Map", href: "/map" },
    { label: "Heatmap", href: "/heatmap" },
    { 
      label: "Authority Portal", 
      href: "/authority",
      hasDropdown: true,
      dropdownItems: [
        { label: "Authority Command Center", href: "/authority" },
        { label: "Police Console", href: "/authority?dept=police" },
        { label: "BMC Console", href: "/authority?dept=bmc" }
      ]
    } as any
  ];

  if (isAuthority) {
    customNavLinks.push({ label: "Kanban", href: "/kanban", active: false } as any);
  }
  
  const customSocialLinks = [
    { label: "Twitter", href: "#" },
    { label: "GitHub", href: "https://github.com/itssmansi/UniSafe_fyp" },
  ];

  return (
    <div className="bg-background flex min-h-screen w-full flex-col justify-center">
      <Hero2
        brand={
          <div className="flex items-center gap-2">
            <svg className="w-7 h-7 text-unisafe-teal" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z" />
            </svg>
            <span className="text-xl font-bold tracking-tight text-unisafe-dark-midnight-blue">UniSafe</span>
          </div>
        }
        navLinks={customNavLinks}
        headline={
          <>
            Official Authority &<br />
            Emergency <span className="italic font-medium font-serif text-unisafe-teal">Console.</span>
          </>
        }
        description={"Government of Maharashtra • Unified Civic Incident Command & Operations Platform for Police and BMC authorities."}
        primaryCtaLabel="Authority Portal"
        primaryCtaHref="/authority"
        secondaryCtaLabel={isAuthority ? "View Kanban Board" : "Official Authority Login"}
        secondaryCtaHref={isAuthority ? "/kanban" : "/authority/login"}
        socialLinks={customSocialLinks}
        headerActions={
          <div className="flex items-center gap-4">
            {session && <CitizenNotificationBell />}
            
            {session ? (
              <div className="flex items-center gap-3 border-l border-gray-300 pl-4">
                <span className="text-sm font-semibold text-unisafe-midnight-blue bg-purple-100 text-purple-900 border border-purple-200 px-3 py-1 rounded-full">
                  Verified Authority
                </span>
                <button 
                  onClick={async () => {
                    localStorage.removeItem('unisafe_authority');
                    localStorage.removeItem('user');
                    await supabase.auth.signOut();
                    window.location.href = '/authority/login';
                  }} 
                  className="text-sm font-medium text-red-600 hover:text-red-700 transition-colors cursor-pointer"
                >
                  Sign Out
                </button>
              </div>
            ) : (
              <div className="flex items-center gap-3">
                <div className="hidden sm:flex items-center gap-1.5 text-xs text-slate-500 bg-slate-100 px-2.5 py-1 rounded-lg border border-slate-200">
                  <span>Citizen Services:</span>
                  <span className="font-semibold text-slate-700">Mobile App Only</span>
                </div>
                <a 
                  href="/authority/login" 
                  className="text-xs sm:text-sm font-semibold text-white bg-purple-700 hover:bg-purple-800 px-4 py-2 rounded-xl shadow-sm transition-all flex items-center gap-1.5"
                >
                  <span>Authority Login</span>
                  <span>→</span>
                </a>
              </div>
            )}
          </div>
        }
      />
    </div>
  );
}
