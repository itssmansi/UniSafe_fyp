import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../services/supabase';
import { Shield, Lock, User, Building2, BadgeCheck, Eye, EyeOff, AlertCircle, ArrowRight } from 'lucide-react';

const DEPARTMENTS = [
  { id: 'POLICE', label: 'Mumbai Police' },
  { id: 'BMC', label: 'Brihanmumbai Municipal Corporation (BMC)' },
];

export default function AuthorityLoginPage() {
  const navigate = useNavigate();

  const [department, setDepartment] = useState('POLICE');
  const [name, setName] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    if (!name.trim()) {
      setErrorMsg('Please enter the official name stored on your authority record.');
      return;
    }
    if (!password) {
      setErrorMsg('Please enter your official authority password.');
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
        } catch { /* Keep the SDK error when no JSON response is available. */ }
        throw new Error(details?.message || error.message || 'Authority login failed.');
      }
      if (!data?.success || !data.authority || !data.access_token || !data.refresh_token) {
        throw new Error(data?.message || 'Authority login failed.');
      }

      const { error: sessionError } = await supabase.auth.setSession({
        access_token: data.access_token,
        refresh_token: data.refresh_token,
      });
      if (sessionError) throw new Error(`Could not open the authority session: ${sessionError.message}`);

      localStorage.setItem('unisafe_authority', JSON.stringify({
        ...data.authority,
        auth_user_id: data.authority.auth_user_id || data.user_id,
        role: 'authority',
        user_type: 'authority',
      }));
      localStorage.setItem('user', JSON.stringify({
        id: data.user_id,
        role: 'authority',
        name: data.authority.name,
        department: data.authority.department,
      }));

      setSuccessMsg('Authorization verified. Redirecting to Authority Command Center...');

      setTimeout(() => {
        navigate('/authority', { replace: true });
      }, 700);

    } catch (err) {
      console.error('Authority login failed:', err);
      setErrorMsg(err.message || 'Failed to authenticate authority.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col justify-center items-center p-4 sm:p-6 lg:p-8 font-sans selection:bg-purple-500 selection:text-white">
      {/* Background ambient lighting */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[600px] bg-purple-600/10 rounded-full blur-3xl"></div>
        <div className="absolute bottom-10 left-1/4 w-[400px] h-[400px] bg-blue-600/10 rounded-full blur-3xl"></div>
      </div>

      <div className="relative w-full max-w-lg bg-slate-800/90 border border-slate-700/80 rounded-3xl shadow-2xl backdrop-blur-xl p-6 sm:p-8">
        
        {/* Official Header */}
        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-tr from-purple-700 to-indigo-600 shadow-lg shadow-purple-900/40 border border-purple-400/30 mb-3">
            <Shield className="w-8 h-8 text-white" />
          </div>
          <div className="inline-block px-3 py-0.5 rounded-full bg-purple-950/60 border border-purple-500/30 text-[11px] font-semibold text-purple-300 tracking-wider uppercase mb-2">
            Restricted Government Access
          </div>
          <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
            UniSafe Authority Portal
          </h1>
          <p className="text-xs sm:text-sm text-slate-400 mt-1">
            Municipal & Police Official Incident Management
          </p>
        </div>

        {/* Notice on restricted public registration */}
        <div className="mb-6 p-3 rounded-xl bg-slate-900/70 border border-slate-700/60 text-xs text-slate-400 flex items-start gap-2.5">
          <AlertCircle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
          <span>
            Authority access is checked against your saved authority record. SMS confirmation is not required.
          </span>
        </div>

        {/* Status Alerts */}
        {errorMsg && (
          <div className="mb-5 p-3.5 rounded-xl bg-rose-950/60 border border-rose-500/40 text-xs text-rose-300 flex items-center gap-2.5">
            <AlertCircle className="w-4 h-4 text-rose-400 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        {successMsg && (
          <div className="mb-5 p-3.5 rounded-xl bg-emerald-950/60 border border-emerald-500/40 text-xs text-emerald-300 flex items-center gap-2.5">
            <BadgeCheck className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>{successMsg}</span>
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          
          {/* Department */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1.5">
              Department
            </label>
            <div className="relative">
              <Building2 className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <select
                value={department}
                onChange={(e) => setDepartment(e.target.value)}
                className="w-full bg-slate-900/90 border border-slate-700 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 text-white text-sm rounded-xl py-2.5 pl-10 pr-3 outline-none transition-all"
              >
                {DEPARTMENTS.map(d => (
                  <option key={d.id} value={d.id}>{d.label}</option>
                ))}
              </select>
            </div>
          </div>

          {/* Authority name */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1.5">
              Official Name
            </label>
            <div className="relative">
              <User className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="text"
                placeholder="Name as saved in the authorities table"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                className="w-full bg-slate-900/90 border border-slate-700 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 text-white text-sm rounded-xl py-2.5 pl-10 pr-3 placeholder:text-slate-600 outline-none transition-all"
              />
            </div>
          </div>

          {/* Password */}
          <div>
            <label className="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1.5">
              Official Password
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type={showPassword ? 'text' : 'password'}
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="w-full bg-slate-900/90 border border-slate-700 focus:border-purple-500 focus:ring-1 focus:ring-purple-500 text-white text-sm rounded-xl py-2.5 pl-10 pr-10 placeholder:text-slate-600 outline-none transition-all"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300 transition-colors"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-3 px-4 rounded-xl bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-semibold text-sm shadow-lg shadow-purple-900/30 border border-purple-400/20 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center justify-center gap-2 cursor-pointer"
          >
            {loading ? (
              <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
            ) : (
              <>
                <span>Sign In to Authority Console</span>
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>
        </form>

        {/* Footer */}
        <div className="mt-6 pt-4 border-t border-slate-700/60 text-center">
          <p className="text-[11px] text-slate-500">
            UniSafe FYP Emergency & Incident Management Core • Secure Authority Portal
          </p>
        </div>
      </div>
    </div>
  );
}
