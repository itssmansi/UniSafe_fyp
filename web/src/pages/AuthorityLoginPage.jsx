import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { supabase } from '../services/supabase';
import { Eye, EyeOff, ArrowLeft, ArrowRight, ShieldCheck, Building2, Shield } from 'lucide-react';

const DEPARTMENTS = [
  {
    id: 'POLICE',
    label: 'Mumbai Police',
    desc: 'Law enforcement & dispatch',
    icon: Shield,
    placeholder: 'e.g. Officer Sharma',
  },
  {
    id: 'BMC',
    label: 'BMC Corporation',
    desc: 'Civic infra & municipal services',
    icon: Building2,
    placeholder: 'e.g. Ward Officer Patil',
  },
];

export default function AuthorityLoginPage() {
  const navigate = useNavigate();

  const [department, setDepartment] = useState('BMC');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const activeDept = DEPARTMENTS.find((d) => d.id === department) || DEPARTMENTS[0];

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    if (!name.trim()) {
      setErrorMsg('Please enter your official name or identifier.');
      return;
    }
    if (!password) {
      setErrorMsg('Please enter your password.');
      return;
    }

    setLoading(true);

    try {
      const { data, error } = await supabase.functions.invoke('authority-login', {
        body: { name: name.trim(), department, password },
      });

      if (error) {
        let details;
        try {
          details = await error.context?.clone?.().json();
        } catch {
          /* fallback */
        }
        throw new Error(
          details?.message || error.message || 'Authentication failed. Please verify credentials.'
        );
      }

      if (!data?.success || !data.authority || !data.access_token || !data.refresh_token) {
        throw new Error(data?.message || 'Authentication failed. Invalid authority response.');
      }

      const { error: sessionError } = await supabase.auth.setSession({
        access_token: data.access_token,
        refresh_token: data.refresh_token,
      });
      if (sessionError) throw new Error(`Session error: ${sessionError.message}`);

      localStorage.setItem(
        'unisafe_authority',
        JSON.stringify({
          ...data.authority,
          auth_user_id: data.authority.auth_user_id || data.user_id,
          role: 'authority',
          user_type: 'authority',
        })
      );
      localStorage.setItem(
        'user',
        JSON.stringify({
          id: data.user_id,
          role: 'authority',
          name: data.authority.name,
          department: data.authority.department,
        })
      );

      setSuccessMsg('Signed in. Opening dashboard...');

      setTimeout(() => {
        navigate('/', { replace: true });
      }, 350);
    } catch (err) {
      console.error('Authority login failed:', err);
      setErrorMsg(err.message || 'Unable to sign in. Please verify your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="h-screen w-full flex flex-col lg:flex-row bg-white font-sans text-neutral-900 antialiased selection:bg-neutral-900 selection:text-white overflow-hidden">
      {/* ================= LEFT VISUAL HERO PANEL (Strictly 100% height, No scroll) ================= */}
      <div className="relative w-full lg:w-1/2 h-full flex flex-col justify-between p-6 sm:p-8 lg:p-10 xl:p-12 overflow-hidden bg-neutral-900 text-white shrink-0">
        {/* Background Image */}
        <img
          src="https://images.unsplash.com/photo-1518005020951-eccb494ad742?q=80&w=2930&auto=format&fit=crop"
          alt="Urban landscape"
          className="absolute inset-0 h-full w-full object-cover opacity-60 mix-blend-luminosity scale-105"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-neutral-950 via-neutral-950/70 to-neutral-900/40 pointer-events-none" />

        {/* Top Header */}
        <div className="relative z-10 flex items-center justify-between">
          <Link to="/" className="flex items-center gap-2 text-white hover:opacity-90 transition-opacity">
            <div className="w-7 h-7 rounded-lg bg-white text-neutral-950 flex items-center justify-center font-bold text-xs tracking-tight shadow-sm">
              <ShieldCheck className="w-4 h-4 text-neutral-950 stroke-[2.3]" />
            </div>
            <div className="flex flex-col">
              <span className="font-semibold text-sm tracking-tight text-white leading-tight">UniSafe</span>
              <span className="text-[10px] text-neutral-400 font-normal">Authority Operations</span>
            </div>
          </Link>

          <span className="text-[11px] font-medium text-neutral-300 bg-white/10 backdrop-blur-md px-2.5 py-1 rounded-full border border-white/15">
            Govt. of Maharashtra
          </span>
        </div>

        {/* Bottom Headline & Metadata */}
        <div className="relative z-10 max-w-lg mt-auto">
          <div className="w-6 h-0.5 bg-white mb-3 rounded-full opacity-80" />
          <h2 className="text-2xl sm:text-3xl lg:text-[32px] font-semibold tracking-tight text-white leading-tight">
            Incident Command & Civic Operations.
          </h2>
          <p className="mt-2 text-xs sm:text-sm text-neutral-300 leading-relaxed max-w-md line-clamp-3">
            Unified incident management system coordinating Mumbai Police and Brihanmumbai Municipal
            Corporation for city-wide safety, rapid response, and public infrastructure resolution.
          </p>

          <div className="mt-5 pt-4 border-t border-white/15 flex items-center gap-5 text-[11px] text-neutral-400">
            <div>
              <span className="block text-white font-medium text-xs">Police Control</span>
              <span>112 Emergency Dispatch</span>
            </div>
            <div className="w-px h-6 bg-white/15" />
            <div>
              <span className="block text-white font-medium text-xs">BMC Disaster Cell</span>
              <span>1916 Civic Helpline</span>
            </div>
          </div>
        </div>
      </div>

      {/* ================= RIGHT FORM PANEL (Strictly fits in 100vh, zero scrolling) ================= */}
      <div className="w-full lg:w-1/2 h-full flex flex-col justify-between p-6 sm:p-8 lg:p-10 xl:p-12 overflow-hidden bg-white">
        {/* Top Header Row */}
        <div className="w-full max-w-md mx-auto flex items-center justify-between">
          <Link
            to="/"
            className="inline-flex items-center gap-1.5 text-xs font-medium text-neutral-500 hover:text-neutral-900 transition-colors"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span>Back to home</span>
          </Link>

          <span className="text-[10px] text-neutral-400 font-mono tracking-wider">SECURE CONSOLE</span>
        </div>

        {/* Form Container (compact, perfectly proportioned) */}
        <div className="w-full max-w-md mx-auto my-auto py-2">
          <div className="mb-5">
            <h1 className="text-2xl sm:text-[26px] font-semibold tracking-tight text-neutral-900">
              Sign in
            </h1>
            <p className="text-neutral-500 text-xs sm:text-sm mt-1 leading-relaxed">
              Enter your official credentials to access the incident management console.
            </p>
          </div>

          {/* Department Selection */}
          <div className="mb-4">
            <label className="block text-xs font-medium text-neutral-700 mb-1.5">
              Department Desk
            </label>
            <div className="grid grid-cols-2 gap-2">
              {DEPARTMENTS.map((d) => {
                const active = department === d.id;
                const Icon = d.icon;
                return (
                  <button
                    key={d.id}
                    type="button"
                    onClick={() => {
                      setDepartment(d.id);
                      setErrorMsg('');
                    }}
                    className={`p-2.5 sm:p-3 rounded-xl border text-left transition-all cursor-pointer flex flex-col justify-between gap-1.5 ${
                      active
                        ? 'border-neutral-900 bg-neutral-900 text-white shadow-xs'
                        : 'border-neutral-200 bg-white text-neutral-700 hover:border-neutral-300 hover:bg-neutral-50/50'
                    }`}
                  >
                    <Icon className={`w-4 h-4 ${active ? 'text-white' : 'text-neutral-500'}`} />
                    <div>
                      <p className={`text-xs font-semibold ${active ? 'text-white' : 'text-neutral-900'}`}>
                        {d.label}
                      </p>
                      <p className={`text-[10px] line-clamp-1 ${active ? 'text-neutral-300' : 'text-neutral-400'}`}>
                        {d.desc}
                      </p>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Alerts */}
          {errorMsg && (
            <div className="mb-3.5 p-2.5 rounded-lg bg-red-50 border border-red-200 text-red-700 text-xs leading-relaxed">
              {errorMsg}
            </div>
          )}

          {successMsg && (
            <div className="mb-3.5 p-2.5 rounded-lg bg-neutral-900 text-white text-xs leading-relaxed text-center font-medium">
              {successMsg}
            </div>
          )}

          {/* Form Fields */}
          <form onSubmit={handleSubmit} className="space-y-3">
            <div>
              <label htmlFor="official-name" className="block text-xs font-medium text-neutral-700 mb-1">
                Official Name or ID
              </label>
              <input
                id="official-name"
                name="officialName"
                type="text"
                placeholder={activeDept.placeholder}
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                autoComplete="username"
                className="w-full h-10 bg-white border border-neutral-200 hover:border-neutral-300 focus:border-neutral-900 focus:ring-1 focus:ring-neutral-900 rounded-lg px-3 text-sm text-neutral-900 placeholder:text-neutral-400 outline-none transition-all shadow-xs"
              />
            </div>

            <div>
              <label htmlFor="official-password" className="block text-xs font-medium text-neutral-700 mb-1">
                Password
              </label>
              <div className="relative">
                <input
                  id="official-password"
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  autoComplete="current-password"
                  className="w-full h-10 bg-white border border-neutral-200 hover:border-neutral-300 focus:border-neutral-900 focus:ring-1 focus:ring-neutral-900 rounded-lg px-3 pr-10 text-sm text-neutral-900 placeholder:text-neutral-400 outline-none transition-all shadow-xs"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-2.5 top-1/2 -translate-y-1/2 text-neutral-400 hover:text-neutral-700 transition-colors p-1 cursor-pointer"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full h-10 mt-1 bg-neutral-900 hover:bg-neutral-800 active:bg-neutral-950 text-white rounded-lg text-sm font-medium transition-all shadow-xs flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loading ? (
                <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
              ) : (
                <>
                  <span>Sign in to console</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </>
              )}
            </button>
          </form>

          <p className="mt-4 pt-3 border-t border-neutral-100 text-[11px] text-neutral-400">
            Having trouble accessing your account? Contact your control room IT administrator.
          </p>
        </div>

        {/* Footer */}
        <div className="w-full max-w-md mx-auto pt-3 text-[11px] text-neutral-400 flex items-center justify-between border-t border-neutral-100">
          <span>© 2026 UniSafe • Govt. of Maharashtra</span>
          <span>Authorized Personnel Only</span>
        </div>
      </div>
    </div>
  );
}
