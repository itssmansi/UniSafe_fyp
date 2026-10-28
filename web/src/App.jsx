import { useEffect, useState } from "react";
import { BrowserRouter, Routes, Route, Link, Navigate } from "react-router-dom";
import { supabase } from "./services/supabase";

import Hero2Demo from "./screens/home/demo";
import KanbanBoard from "./screens/kanban-board/KanbanBoard";
import InteractiveMap from "./screens/interactive-map/InteractiveMap";
import ResolutionVerification from "./screens/verification/ResolutionVerification";
import VerificationHub from "./screens/verification/VerificationHub";
import AuthorityDashboard from "./pages/AuthorityDashboard";
import AuthorityLoginPage from "./pages/AuthorityLoginPage";
import Heatmap from "./pages/Heatmap";
import LiveTrackingPage from "./pages/LiveTrackingPage";

function Home({ user }) {
  const [backendStatus, setBackendStatus] = useState("Checking...");

  useEffect(() => {
    fetch("http://127.0.0.1:5000/api/health")
      .then((response) => response.json())
      .then((data) => {
        setBackendStatus(data.message);
      })
      .catch(() => {
        setBackendStatus("Backend connection failed");
      });
  }, []);

  const handleLogout = async () => {
    localStorage.removeItem('unisafe_authority');
    localStorage.removeItem('user');
    await supabase.auth.signOut();
    window.location.href = '/authority/login';
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-b from-slate-50 to-slate-100/60 font-sans">
      <div className="max-w-md w-full bg-white p-8 rounded-3xl shadow-xl shadow-slate-200/50 border border-slate-100 text-center">
        
        {/* User Status Bar */}
        {user && (
          <div className="mb-6 p-3 bg-blue-50 rounded-xl border border-blue-100 flex items-center justify-between">
            <div className="text-left">
              <p className="text-xs text-blue-500 font-semibold uppercase tracking-wider">Logged In As</p>
              <p className="text-sm font-bold text-blue-900">{user.user_metadata?.role_type || user.user_metadata?.role || 'Authority'}</p>
            </div>
            <button onClick={handleLogout} className="text-xs bg-white text-slate-600 px-3 py-1.5 rounded-lg border border-slate-200 shadow-sm hover:bg-slate-50 cursor-pointer">
              Sign Out
            </button>
          </div>
        )}

        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-50 border border-blue-100 text-xs font-semibold text-blue-600 mb-4">
          <span className="w-2 h-2 rounded-full bg-blue-500 animate-pulse"></span>
          UniSafe FYP Official Web Portal
        </div>

        <h1 className="text-3xl font-extrabold text-slate-900 tracking-tight">
          UniSafe Authority Center
        </h1>

        <p className="mt-2 text-sm text-slate-500 flex items-center justify-center gap-2">
          <span>Backend Status:</span>
          <span className={`font-semibold px-2.5 py-0.5 rounded-full text-xs ${backendStatus === "Checking..." ? "bg-amber-50 text-amber-600" : backendStatus.includes("failed") ? "bg-rose-50 text-rose-600" : "bg-emerald-50 text-emerald-600"}`}>
            {backendStatus}
          </span>
        </p>

        <div className="mt-8 pt-6 border-t border-slate-100 flex flex-col gap-3">
          <p className="text-xs font-bold uppercase tracking-wider text-slate-400 text-left">Authority Modules</p>

          <Link
            to="/authority"
            className="group flex items-center justify-between p-3.5 rounded-2xl border border-purple-200 bg-purple-50/50 hover:border-purple-400 hover:shadow-md hover:shadow-purple-500/10 transition-all text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-purple-600 text-white flex items-center justify-center font-bold text-sm shadow-sm">
                🛡️
              </div>
              <div>
                <h3 className="text-sm font-semibold text-purple-950 group-hover:text-purple-700 transition-colors">Authority Dashboard</h3>
                <p className="text-xs text-purple-600/80">Command center for Police & BMC</p>
              </div>
            </div>
            <span className="text-purple-400 group-hover:text-purple-600 group-hover:translate-x-0.5 transition-all text-sm font-bold">→</span>
          </Link>

          <Link
            to="/kanban"
            className="group flex items-center justify-between p-3.5 rounded-2xl border border-slate-200/80 bg-white hover:border-slate-400 hover:shadow-md hover:shadow-slate-900/5 transition-all text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-slate-900 text-white flex items-center justify-center font-bold text-sm shadow-sm">
                📋
              </div>
              <div>
                <h3 className="text-sm font-semibold text-slate-900 group-hover:text-slate-700 transition-colors">Kanban Board</h3>
                <p className="text-xs text-slate-500">Incident status pipelines</p>
              </div>
            </div>
            <span className="text-slate-400 group-hover:text-slate-900 group-hover:translate-x-0.5 transition-all text-sm font-bold">→</span>
          </Link>

          <Link
            to="/heatmap"
            className="group flex items-center justify-between p-3.5 rounded-2xl border border-slate-200/80 bg-white hover:border-red-400 hover:shadow-md hover:shadow-red-500/5 transition-all text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-red-600 text-white flex items-center justify-center font-bold text-sm shadow-sm">
                🔥
              </div>
              <div>
                <h3 className="text-sm font-semibold text-slate-900 group-hover:text-red-600 transition-colors">Risk Heatmap</h3>
                <p className="text-xs text-slate-500">Civic hotspot clusters</p>
              </div>
            </div>
            <span className="text-slate-400 group-hover:text-red-600 group-hover:translate-x-0.5 transition-all text-sm font-bold">→</span>
          </Link>

          <Link
            to="/map"
            className="group flex items-center justify-between p-3.5 rounded-2xl border border-slate-200/80 bg-white hover:border-emerald-400 hover:shadow-md hover:shadow-emerald-500/5 transition-all text-left"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center font-bold text-sm shadow-sm">
                🗺️
              </div>
              <div>
                <h3 className="text-sm font-semibold text-slate-900 group-hover:text-emerald-600 transition-colors">Jurisdiction Map</h3>
                <p className="text-xs text-slate-500">Interactive GIS reports</p>
              </div>
            </div>
            <span className="text-slate-400 group-hover:text-emerald-600 group-hover:translate-x-0.5 transition-all text-sm font-bold">→</span>
          </Link>
        </div>
      </div>
    </div>
  );
}

export default function App() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAuthority, setIsAuthority] = useState(false);

  // Validate authority role against session metadata or authorities table
  const verifyAuthorityStatus = async (currentSession) => {
    if (!currentSession?.user) {
      setIsAuthority(false);
      return false;
    }

    const metadataRole = currentSession.user.user_metadata?.role_type || currentSession.user.user_metadata?.role;
    if (metadataRole === 'authority') {
      setIsAuthority(true);
      return true;
    }

    // Secondary check: verify in public.authorities
    try {
      const { data: authRecord } = await supabase
        .from('authorities')
        .select('*')
        .or(`id.eq.${currentSession.user.id},auth_user_id.eq.${currentSession.user.id}`)
        .maybeSingle();

      if (authRecord) {
        setIsAuthority(true);
        localStorage.setItem('unisafe_authority', JSON.stringify({
          ...authRecord,
          role: 'authority',
          user_type: 'authority'
        }));
        return true;
      }
    } catch (e) {
      console.warn("Authority verification check:", e);
    }

    // Check cached profile if previously set
    const cached = localStorage.getItem('unisafe_authority');
    if (cached) {
      setIsAuthority(true);
      return true;
    }

    setIsAuthority(false);
    return false;
  };

  useEffect(() => {
    // 1. Check active session on load
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      verifyAuthorityStatus(session).finally(() => setLoading(false));
    });

    // 2. Listen to login/logout events
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      setSession(newSession);
      if (newSession) {
        await verifyAuthorityStatus(newSession);
      } else {
        setIsAuthority(false);
        localStorage.removeItem('unisafe_authority');
        localStorage.removeItem('user');
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-900 text-slate-400 font-sans">
        <div className="flex flex-col items-center gap-3">
          <div className="w-10 h-10 border-4 border-purple-500 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-xs tracking-wider uppercase font-semibold">Initializing UniSafe Portal...</p>
        </div>
      </div>
    );
  }

  // Strict AuthorityRoute protecting authority functionality exclusively
  const AuthorityRoute = ({ children }) => {
    if (!session) {
      return <Navigate to="/authority/login" replace />;
    }
    if (!isAuthority) {
      return (
        <div className="min-h-screen bg-slate-900 flex items-center justify-center p-6 text-center font-sans">
          <div className="max-w-md w-full bg-slate-800 p-8 rounded-3xl border border-rose-500/30">
            <div className="w-16 h-16 rounded-2xl bg-rose-500/20 text-rose-400 flex items-center justify-center mx-auto mb-4 text-2xl font-bold">
              🚫
            </div>
            <h2 className="text-xl font-bold text-white mb-2">Unauthorized Personnel</h2>
            <p className="text-sm text-slate-400 mb-6">
              This portal is restricted exclusively to authorized municipal and police officials. Citizen accounts cannot access authority dashboards.
            </p>
            <div className="flex flex-col gap-2">
              <Link
                to="/authority/login"
                className="w-full py-2.5 px-4 bg-purple-600 hover:bg-purple-500 text-white font-semibold rounded-xl text-sm transition-colors"
              >
                Log In as Authority
              </Link>
              <button
                onClick={async () => {
                  await supabase.auth.signOut();
                  window.location.href = '/authority/login';
                }}
                className="w-full py-2.5 px-4 bg-slate-700 hover:bg-slate-600 text-slate-300 font-medium rounded-xl text-xs transition-colors cursor-pointer"
              >
                Sign Out Current Account
              </button>
            </div>
          </div>
        </div>
      );
    }
    return children;
  };

  return (
    <BrowserRouter>
      <Routes>
        {/* Root: Authority Login if unauthenticated, Operations Hub if authenticated */}
        <Route 
          path="/" 
          element={session && isAuthority ? <AuthorityDashboard /> : <AuthorityLoginPage />} 
        />
        <Route path="/home" element={<Navigate to="/" replace />} />
        <Route path="/status" element={<Home user={session?.user} />} />
        
        {/* Dedicated Authority Authentication Route */}
        <Route 
          path="/authority/login" 
          element={session && isAuthority ? <Navigate to="/" replace /> : <AuthorityLoginPage />} 
        />
        
        {/* Redirect generic /auth and /login to authority login on web */}
        <Route path="/auth" element={<Navigate to="/" replace />} />
        <Route path="/login" element={<Navigate to="/" replace />} />
        <Route path="/signup" element={<Navigate to="/" replace />} />

        {/* Protected Authority Routes */}
        <Route path="/authority" element={<AuthorityRoute><AuthorityDashboard /></AuthorityRoute>} />
        <Route path="/kanban" element={<AuthorityRoute><KanbanBoard /></AuthorityRoute>} />
        
        {/* Civic Tools & Public Verification */}
        <Route path="/map" element={<InteractiveMap />} />
        <Route path="/heatmap" element={<Heatmap />} />
        <Route path="/verify" element={<VerificationHub />} />
        <Route path="/verify/:id" element={<ResolutionVerification />} />
        
        {/* Public Live Journey Tracking (for trusted contacts) */}
        <Route path="/track" element={<LiveTrackingPage />} />
        
        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
