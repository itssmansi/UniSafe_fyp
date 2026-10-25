import React, { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';

// Assuming Flask runs on standard 5000
const API_URL = 'http://localhost:5000/api/auth';

export default function AuthPage() {
  const [role, setRole] = useState('citizen'); // 'citizen' or 'authority'
  const [mode, setMode] = useState('login'); // 'login' or 'register'
  const [step, setStep] = useState('form'); // 'form', 'otp', 'success'
  
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // OTP State
  const [otp, setOtp] = useState('');
  const [resendTimer, setResendTimer] = useState(0);

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    confirmPassword: '',
    department: '',
    jurisdiction: '',
  });

  useEffect(() => {
    let interval = null;
    if (resendTimer > 0) {
      interval = setInterval(() => setResendTimer((t) => t - 1), 1000);
    } else if (interval) {
      clearInterval(interval);
    }
    return () => clearInterval(interval);
  }, [resendTimer]);

  const handleInputChange = (e) => {
    const { id, value } = e.target;
    setFormData((prev) => ({ ...prev, [id]: value }));
  };

  const normalizePhone = (phone) => {
    if (!phone) return null;
    let formatted = phone.trim();
    if (formatted.length === 10 && !formatted.startsWith('+')) {
      return `+91${formatted}`;
    }
    if (!formatted.startsWith('+')) {
      return `+${formatted}`;
    }
    return formatted;
  };

  const maskPhone = (phone) => {
    if (!phone) return '';
    const norm = normalizePhone(phone);
    if (norm.length < 8) return norm;
    const last4 = norm.slice(-4);
    const country = norm.slice(0, 3); 
    return `${country} ••••••${last4}`;
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    
    if (formData.password !== formData.confirmPassword) {
      return setErrorMsg("Passwords do not match.");
    }
    if (!formData.phone) {
      return setErrorMsg("Phone number is required for SMS verification.");
    }
    
    setLoading(true);

    try {
      const normalizedPhone = normalizePhone(formData.phone);
      
      // 1. Send OTP Request to our Flask Backend (Bird API integration)
      const response = await fetch(`${API_URL}/register/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: normalizedPhone })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || "Failed to send verification code.");
      }

      // 2. Wait for OTP. Do NOT call Supabase Auth or create profile yet!
      setStep('otp');
      setResendTimer(60);
      setSuccessMsg("Verification code sent to your phone.");
      
    } catch (err) {
      setErrorMsg(err.message || "An error occurred during registration.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    if (!otp || otp.length !== 6) {
      return setErrorMsg("Please enter a valid 6-digit OTP.");
    }

    setErrorMsg('');
    setLoading(true);

    try {
      const normalizedPhone = normalizePhone(formData.phone);

      // 3. Verify OTP Hash against Flask Backend
      const response = await fetch(`${API_URL}/register/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: normalizedPhone, otp })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || "Incorrect verification code. Please try again.");
      }

      // 4. OTP Valid! Now safely proceed with Supabase Auth Signup
      // Note: Supabase Dashboard must have "Confirm Phone" turned OFF
      // so this creates a verified user immediately without sending a Supabase SMS.
      const { data: authData, error: authError } = await supabase.auth.signUp({
        phone: normalizedPhone,
        password: formData.password,
        options: {
          data: {
            email: formData.email,
            name: formData.name
          }
        }
      });

      if (authError) throw authError;
      
      const userId = authData.user?.id || authData.session?.user?.id;
      if (!userId) throw new Error("Auth succeeded but no user ID was returned.");

      // 5. Insert Database Profile strictly AFTER successful verification
      if (role === 'citizen') {
        const { error: dbError } = await supabase.from('citizens').insert([{
          id: userId,
          name: formData.name,
          phone: normalizedPhone,
          role: 'citizen'
        }]);
        if (dbError) throw dbError;
      } else {
        const { error: dbError } = await supabase.from('authorities').insert([{
          id: userId,
          name: formData.name,
          phone: normalizedPhone,
          department: formData.department,
          jurisdiction: formData.jurisdiction,
          role: 'authority'
        }]);
        if (dbError) throw dbError;
      }

      setStep('success');
      setSuccessMsg(''); 

    } catch (err) {
      setErrorMsg(err.message || "An error occurred finalizing registration.");
    } finally {
      setLoading(false);
    }
  };

  const handleResendOtp = async () => {
    if (resendTimer > 0) return;
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);

    try {
      const normalizedPhone = normalizePhone(formData.phone);
      const response = await fetch(`${API_URL}/resend-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: normalizedPhone })
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || "Unable to send verification code. Please try again.");
      }

      setSuccessMsg("A new verification code has been sent.");
      setResendTimer(60);
    } catch (err) {
      setErrorMsg(err.message || "Unable to send verification code. Please try again.");
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');
    setLoading(true);

    try {
      const identifier = formData.email.trim();
      const isEmail = identifier.includes('@');
      
      let credentials = { password: formData.password };
      if (isEmail) {
        credentials.email = identifier;
      } else {
        credentials.phone = normalizePhone(identifier);
      }

      const { data: authData, error: authError } = await supabase.auth.signInWithPassword(credentials);

      if (authError) throw authError;

      const table = role === 'citizen' ? 'citizens' : 'authorities';
      const { data: profile, error: profileError } = await supabase
        .from(table)
        .select('*')
        .eq('id', authData.user?.id)
        .single();
        
      if (profileError || !profile) {
        await supabase.auth.signOut();
        throw new Error(`Profile not found for ${role} role. Please ensure you select the correct role.`);
      }

      setSuccessMsg("Login successful!");
    } catch (err) {
      setErrorMsg(err.message || "Invalid login credentials.");
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = (e) => {
    if (mode === 'login') {
      handleLogin(e);
    } else {
      handleRegister(e);
    }
  };

  const toggleMode = (newMode) => {
    setMode(newMode);
    setStep('form');
    setErrorMsg('');
    setSuccessMsg('');
  };

  const toggleRole = (newRole) => {
    setRole(newRole);
    setErrorMsg('');
    setSuccessMsg('');
  };

  return (
    <div className="flex min-h-screen w-full flex-col bg-unisafe-smoke-white font-sans text-unisafe-dark-midnight-blue antialiased lg:flex-row">
      {/* Left Branding Panel */}
      <div className="relative flex w-full flex-col justify-between overflow-hidden bg-unisafe-midnight-blue p-8 md:p-12 lg:w-1/2 min-h-[40vh] lg:min-h-screen">
        <div className="absolute inset-0 opacity-10 bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-unisafe-teal via-unisafe-midnight-blue to-unisafe-dark-midnight-blue"></div>

        {/* Top Header */}
        <div className="relative z-10 flex items-center justify-between">
          <span className="text-2xl font-bold tracking-tight text-unisafe-white flex items-center gap-2">
            <svg className="w-8 h-8 text-unisafe-teal" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm0 10.99h7c-.53 4.12-3.28 7.79-7 8.94V12H5V6.3l7-3.11v8.8z"/>
            </svg>
            UniSafe
          </span>
        </div>

        {/* Middle Content */}
        <div className="relative z-10 mt-12 lg:mt-0 flex-grow flex flex-col justify-center">
          <h1 className="mb-4 max-w-xl text-4xl font-semibold leading-[1.1] tracking-tight text-unisafe-white sm:text-5xl lg:text-6xl">
            Report it in a minute.<br />
            <span className="text-unisafe-teal">See it move.</span>
          </h1>
          <p className="max-w-md text-base leading-relaxed text-unisafe-smoke-white sm:text-lg mb-8">
            UniSafe connects citizens with trusted authorities to report incidents, track progress, and build safer communities.
          </p>

          <div className="flex flex-col gap-4">
            {['Live Status Tracking', 'Verified Responder Routing', 'Neighborhood Safety Map'].map((feature, idx) => (
              <div key={idx} className="flex items-center gap-3 text-unisafe-white bg-unisafe-dark-midnight-blue/40 p-3 rounded-lg border border-unisafe-teal/20 w-fit">
                <svg className="w-5 h-5 text-unisafe-teal" fill="none" stroke="currentColor" viewBox="0 0 24 24" strokeWidth="2">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                <span className="font-medium text-sm sm:text-base">{feature}</span>
              </div>
            ))}
          </div>
        </div>
        
        {/* Bottom Content */}
        <div className="relative z-10 mt-12">
          <p className="text-sm text-unisafe-smoke-white/70 italic border-l-2 border-unisafe-teal pl-4">
            "Trusted by communities working toward safer neighborhoods."
          </p>
        </div>
      </div>

      {/* Right Form Panel */}
      <div className="flex w-full flex-col items-center justify-center p-6 sm:p-12 lg:w-1/2">
        <div className="w-full max-w-md xl:max-w-lg bg-unisafe-white p-8 rounded-2xl shadow-sm border border-unisafe-smoke-white/50">
          
          {step === 'form' && (
            <>
              {/* Role Selector */}
              <div className="flex w-full bg-unisafe-smoke-white rounded-lg p-1 mb-8 border border-unisafe-midnight-blue/5">
                <button
                  onClick={() => toggleRole('citizen')}
                  className={`flex-1 py-2 text-sm font-medium rounded-md transition-all ${role === 'citizen' ? 'bg-unisafe-white text-unisafe-midnight-blue shadow-sm border border-unisafe-midnight-blue/10' : 'text-unisafe-midnight-blue/60 hover:text-unisafe-midnight-blue'}`}
                >
                  CITIZEN
                </button>
                <button
                  onClick={() => toggleRole('authority')}
                  className={`flex-1 py-2 text-sm font-medium rounded-md transition-all ${role === 'authority' ? 'bg-unisafe-midnight-blue text-unisafe-white shadow-sm' : 'text-unisafe-midnight-blue/60 hover:text-unisafe-midnight-blue'}`}
                >
                  AUTHORITY
                </button>
              </div>

              {/* Titles & Mode Toggle */}
              <div className="mb-6 flex justify-between items-end">
                <div>
                  <h2 className="mb-1 text-2xl sm:text-3xl font-semibold tracking-tight text-unisafe-midnight-blue">
                    {role === 'citizen' ? (mode === 'login' ? 'Welcome back, Citizen' : 'Create your UniSafe account') : (mode === 'login' ? 'Authority Portal' : 'Register as an Authority')}
                  </h2>
                  <p className="text-[15px] text-unisafe-dark-midnight-blue/60">
                    {mode === 'login' ? 'Enter your credentials to access your account' : 'Fill in the details below to get started'}
                  </p>
                </div>
                
                <div className="flex bg-unisafe-smoke-white rounded-md border border-unisafe-midnight-blue/5 p-0.5 ml-4">
                  <button
                    onClick={() => toggleMode('login')}
                    className={`px-3 py-1 text-xs font-medium rounded transition-all ${mode === 'login' ? 'bg-unisafe-white text-unisafe-midnight-blue shadow-sm' : 'text-unisafe-midnight-blue/60'}`}
                  >
                    Sign In
                  </button>
                  <button
                    onClick={() => toggleMode('register')}
                    className={`px-3 py-1 text-xs font-medium rounded transition-all ${mode === 'register' ? 'bg-unisafe-white text-unisafe-midnight-blue shadow-sm' : 'text-unisafe-midnight-blue/60'}`}
                  >
                    Register
                  </button>
                </div>
              </div>

              {/* Alerts */}
              {errorMsg && (
                <div className="mb-6 p-3 rounded-md bg-unisafe-crimson/10 border border-unisafe-crimson/20 text-unisafe-crimson text-sm">
                  {errorMsg}
                </div>
              )}
              {successMsg && (
                <div className="mb-6 p-3 rounded-md bg-unisafe-teal/10 border border-unisafe-teal/20 text-unisafe-teal text-sm">
                  {successMsg}
                </div>
              )}

              {/* Form */}
              <form className="flex flex-col gap-4" onSubmit={handleSubmit}>
                
                <div className="flex flex-col gap-1.5">
                  <label htmlFor="email" className="text-sm font-medium text-unisafe-midnight-blue">
                    {mode === 'login' ? 'Email or Phone' : 'Email'}
                  </label>
                  <input id="email" type={mode === 'login' ? 'text' : 'email'} required placeholder={mode === 'login' ? 'name@example.com or +91...' : 'name@example.com'} value={formData.email} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-2.5 text-sm text-unisafe-dark-midnight-blue placeholder:text-unisafe-midnight-blue/40 focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors" />
                </div>

                {/* Registration specific fields */}
                {mode === 'register' && (
                  <>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="name" className="text-sm font-medium text-unisafe-midnight-blue">Name</label>
                      <input id="name" type="text" required placeholder="Enter your full name" value={formData.name} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-2.5 text-sm text-unisafe-dark-midnight-blue placeholder:text-unisafe-midnight-blue/40 focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors" />
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="phone" className="text-sm font-medium text-unisafe-midnight-blue">Phone (for OTP verification)</label>
                      <input id="phone" type="tel" required placeholder="e.g. 9876543210" value={formData.phone} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-2.5 text-sm text-unisafe-dark-midnight-blue placeholder:text-unisafe-midnight-blue/40 focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors" />
                    </div>
                  </>
                )}

                <div className="flex flex-col gap-1.5">
                  <label htmlFor="password" className="text-sm font-medium text-unisafe-midnight-blue">Password</label>
                  <div className="relative">
                    <input id="password" required type={showPassword ? "text" : "password"} placeholder="Enter your password" value={formData.password} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-2.5 pr-10 text-sm text-unisafe-dark-midnight-blue placeholder:text-unisafe-midnight-blue/40 focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors" />
                    <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute inset-y-0 right-0 flex items-center pr-3 text-unisafe-midnight-blue/50 hover:text-unisafe-midnight-blue">
                      {showPassword ? (
                        <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                      ) : (
                        <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                      )}
                    </button>
                  </div>
                </div>
                
                {mode === 'register' && (
                  <div className="flex flex-col gap-1.5">
                    <label htmlFor="confirmPassword" className="text-sm font-medium text-unisafe-midnight-blue">Confirm Password</label>
                    <div className="relative">
                      <input id="confirmPassword" required type={showConfirmPassword ? "text" : "password"} placeholder="Confirm your password" value={formData.confirmPassword} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-2.5 pr-10 text-sm text-unisafe-dark-midnight-blue placeholder:text-unisafe-midnight-blue/40 focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors" />
                      <button type="button" onClick={() => setShowConfirmPassword(!showConfirmPassword)} className="absolute inset-y-0 right-0 flex items-center pr-3 text-unisafe-midnight-blue/50 hover:text-unisafe-midnight-blue">
                        {showConfirmPassword ? (
                          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                        ) : (
                          <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                        )}
                      </button>
                    </div>
                  </div>
                )}

                {/* Authority Registration specific fields */}
                {mode === 'register' && role === 'authority' && (
                  <>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="department" className="text-sm font-medium text-unisafe-midnight-blue">Department <span className="text-unisafe-amber">*</span></label>
                      <select id="department" required value={formData.department} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-amber/30 bg-unisafe-amber/5 px-4 py-2.5 text-sm text-unisafe-dark-midnight-blue focus:border-unisafe-amber focus:outline-none focus:ring-1 focus:ring-unisafe-amber focus:bg-unisafe-white transition-colors">
                        <option value="" disabled>Select Department</option>
                        <option value="police">Police</option>
                        <option value="municipal">Municipal Corporation</option>
                        <option value="fire">Fire & Emergency Services</option>
                        <option value="health">Health Department</option>
                        <option value="other">Other</option>
                      </select>
                    </div>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="jurisdiction" className="text-sm font-medium text-unisafe-midnight-blue">Jurisdiction <span className="text-unisafe-amber">*</span></label>
                      <input id="jurisdiction" type="text" required placeholder="e.g. City Central, District 9" value={formData.jurisdiction} onChange={handleInputChange} className="w-full rounded-lg border border-unisafe-amber/30 bg-unisafe-amber/5 px-4 py-2.5 text-sm text-unisafe-dark-midnight-blue focus:border-unisafe-amber focus:outline-none focus:ring-1 focus:ring-unisafe-amber focus:bg-unisafe-white transition-colors" />
                    </div>
                  </>
                )}

                {mode === 'login' && (
                  <div className="flex items-center justify-between mt-1">
                    <div className="flex items-center gap-2">
                      <input id="remember" type="checkbox" className="h-4 w-4 rounded border-unisafe-midnight-blue/30 text-unisafe-teal focus:ring-unisafe-teal" />
                      <label htmlFor="remember" className="text-sm text-unisafe-midnight-blue/80">Remember me</label>
                    </div>
                    <a href="#" className="text-sm font-medium text-unisafe-teal hover:underline hover:text-unisafe-teal/80">
                      Forgot password?
                    </a>
                  </div>
                )}

                <div className="mt-4">
                  <button
                    type="submit"
                    disabled={loading}
                    className={`w-full rounded-lg py-3 text-sm font-semibold text-unisafe-white shadow-sm transition-all active:scale-[0.98] flex justify-center items-center gap-2 ${
                      loading ? 'opacity-70 cursor-not-allowed' : ''
                    } ${role === 'authority' ? 'bg-unisafe-midnight-blue hover:bg-unisafe-dark-midnight-blue' : 'bg-unisafe-teal hover:bg-unisafe-teal/90'}`}
                  >
                    {loading && (
                      <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                        <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    )}
                    {mode === 'login' ? `Sign in as ${role === 'citizen' ? 'Citizen' : 'Authority'} →` : `Register as ${role === 'citizen' ? 'Citizen' : 'Authority'} →`}
                  </button>
                </div>
              </form>
            </>
          )}

          {step === 'otp' && (
            <div className="flex flex-col animate-in fade-in zoom-in duration-300">
              <div className="flex justify-center mb-6">
                <div className={`p-4 rounded-full ${role === 'authority' ? 'bg-unisafe-midnight-blue/10 text-unisafe-midnight-blue' : 'bg-unisafe-teal/10 text-unisafe-teal'}`}>
                  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                  </svg>
                </div>
              </div>

              <h2 className="mb-2 text-2xl font-semibold text-center tracking-tight text-unisafe-midnight-blue">
                Verify your phone number
              </h2>
              <p className="text-center text-[15px] text-unisafe-dark-midnight-blue/70 mb-8">
                We've sent a 6-digit verification code to<br/>
                <span className="font-semibold text-unisafe-midnight-blue">{maskPhone(formData.phone)}</span>
              </p>

              {errorMsg && (
                <div className="mb-6 p-3 rounded-md bg-unisafe-crimson/10 border border-unisafe-crimson/20 text-unisafe-crimson text-sm text-center">
                  {errorMsg}
                </div>
              )}
              {successMsg && (
                <div className="mb-6 p-3 rounded-md bg-unisafe-teal/10 border border-unisafe-teal/20 text-unisafe-teal text-sm text-center">
                  {successMsg}
                </div>
              )}

              <form onSubmit={handleVerifyOtp} className="flex flex-col items-center">
                <div className="w-full mb-8">
                  <input 
                    type="text" 
                    maxLength={6} 
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/[^0-9]/g, ''))}
                    placeholder="• • • • • •" 
                    className="w-full text-center text-3xl tracking-[1em] font-mono rounded-lg border border-unisafe-midnight-blue/20 bg-unisafe-smoke-white/50 px-4 py-4 text-unisafe-dark-midnight-blue focus:border-unisafe-teal focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:bg-unisafe-white transition-colors"
                  />
                </div>

                <button
                  type="submit"
                  disabled={loading || otp.length !== 6}
                  className={`w-full rounded-lg py-3 text-sm font-semibold text-unisafe-white shadow-sm transition-all active:scale-[0.98] flex justify-center items-center gap-2 mb-6 ${
                    (loading || otp.length !== 6) ? 'opacity-70 cursor-not-allowed' : ''
                  } ${role === 'authority' ? 'bg-unisafe-midnight-blue' : 'bg-unisafe-teal'}`}
                >
                  {loading ? 'Verifying...' : 'Verify OTP'}
                </button>

                <div className="flex flex-col items-center gap-4 text-sm w-full pt-4 border-t border-unisafe-smoke-white">
                  <div className="flex items-center gap-2">
                    <span className="text-unisafe-dark-midnight-blue/60">Didn't receive the code?</span>
                    <button 
                      type="button" 
                      disabled={resendTimer > 0 || loading}
                      onClick={handleResendOtp}
                      className={`font-semibold ${resendTimer > 0 ? 'text-unisafe-dark-midnight-blue/40 cursor-not-allowed' : (role === 'authority' ? 'text-unisafe-amber hover:text-unisafe-amber/80' : 'text-unisafe-teal hover:text-unisafe-teal/80')}`}
                    >
                      {resendTimer > 0 ? `Resend available in ${resendTimer}s` : 'Resend OTP'}
                    </button>
                  </div>
                  
                  <button 
                    type="button" 
                    onClick={() => {
                      setStep('form');
                      setErrorMsg('');
                      setSuccessMsg('');
                      setOtp('');
                    }}
                    className="text-unisafe-midnight-blue/70 hover:text-unisafe-midnight-blue underline underline-offset-4"
                  >
                    Change phone number
                  </button>
                </div>
              </form>
            </div>
          )}

          {step === 'success' && (
            <div className="flex flex-col items-center justify-center animate-in fade-in zoom-in duration-500 py-8">
              <div className="mb-6 rounded-full bg-unisafe-teal/10 p-6">
                <div className="rounded-full bg-unisafe-teal p-3 text-unisafe-white shadow-lg">
                  <svg className="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M5 13l4 4L19 7" />
                  </svg>
                </div>
              </div>
              
              <h2 className="mb-2 text-2xl sm:text-3xl font-semibold text-center tracking-tight text-unisafe-midnight-blue">
                {role === 'citizen' ? 'Your UniSafe account is verified' : 'Your authority account is verified'}
              </h2>
              
              <p className="text-center text-[15px] text-unisafe-dark-midnight-blue/70 mb-8 max-w-sm">
                Your phone number has been successfully verified and your profile is now active.
                {role === 'authority' && (
                  <span className="block mt-2 text-unisafe-amber font-medium">Note: Your authority privileges are pending administrative approval.</span>
                )}
              </p>
              
              <button
                onClick={() => {
                  setStep('form');
                  setMode('login');
                  setSuccessMsg('You are verified. Please sign in to continue.');
                }}
                className={`w-full max-w-xs rounded-lg py-3 text-sm font-semibold text-unisafe-white shadow-sm transition-all active:scale-[0.98] ${
                  role === 'authority' ? 'bg-unisafe-midnight-blue hover:bg-unisafe-dark-midnight-blue' : 'bg-unisafe-teal hover:bg-unisafe-teal/90'
                }`}
              >
                Continue to UniSafe →
              </button>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}
