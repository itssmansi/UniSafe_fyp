import React, { useState, useRef } from "react";
import { motion, type Variants, AnimatePresence } from "motion/react";
import { User, ShieldCheck, ArrowLeft, Building2, MapPin, Briefcase } from "lucide-react";
import { supabase } from "../../services/supabase";

// Arrow Icon matching Hugeicons ArrowLeft01Icon
const ArrowLeft01Icon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg
    viewBox="0 0 24 24"
    width="1em"
    height="1em"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    {...props}
  >
    <path d="M19 12H5M12 19l-7-7 7-7" />
  </svg>
);

const HugeiconsIcon = ({
  icon: Icon = ArrowLeft01Icon,
  className = "size-4",
}: {
  icon?: any;
  className?: string;
}) => {
  if (typeof Icon === "function") {
    const Component = Icon;
    return <Component className={className} />;
  }
  return <ArrowLeft01Icon className={className} />;
};

// Simple Google SVG Icon
const GoogleIcon = (props: React.SVGProps<SVGSVGElement>) => (
  <svg viewBox="0 0 24 24" width="1em" height="1em" {...props}>
    <path
      d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
      fill="#4285F4"
    />
    <path
      d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.16v2.84C3.99 20.53 7.7 23 12 23z"
      fill="#34A853"
    />
    <path
      d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.16C1.43 8.55 1 10.22 1 12s.43 3.45 1.16 4.93l3.68-2.84z"
      fill="#FBBC05"
    />
    <path
      d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.16 7.07l3.68 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
      fill="#EA4335"
    />
  </svg>
);

type AccountType = "citizen" | "authority" | null;

const containerVariants: Variants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.1,
      delayChildren: 0.2,
    },
  },
  exit: { opacity: 0, transition: { duration: 0.2 } }
};

const itemVariants: Variants = {
  hidden: { opacity: 0, y: 15 },
  visible: {
    opacity: 1,
    y: 0,
    transition: {
      type: "spring",
      stiffness: 300,
      damping: 24,
    },
  },
};

export default function Auth9() {
  const [accountType, setAccountType] = useState<AccountType>(() => {
    const params = new URLSearchParams(typeof window !== 'undefined' ? window.location.search : "");
    return (params.get("role") as AccountType) || null;
  });
  const [isLogin, setIsLogin] = useState(() => {
    const params = new URLSearchParams(typeof window !== 'undefined' ? window.location.search : "");
    return params.get("mode") !== "register";
  });
  
  // Authority Form State
  const [department, setDepartment] = useState("");
  const [jurisdiction, setJurisdiction] = useState("");
  const [role, setRole] = useState("");

  // Form Refs for uncontrolled inputs (prevents focus loss on typing!)
  const emailRef = useRef<HTMLInputElement>(null);
  const passwordRef = useRef<HTMLInputElement>(null);
  const nameRef = useRef<HTMLInputElement>(null);
  const phoneRef = useRef<HTMLInputElement>(null);

  const handleGoogleLogin = async () => {
    if (accountType === 'authority') {
      // Basic validation for authority
      if (!department || !jurisdiction || !role) {
        alert("Please fill in all Authority details before proceeding.");
        return;
      }
      localStorage.setItem('pending_auth_role', 'authority');
      localStorage.setItem('pending_auth_dept', department);
      localStorage.setItem('pending_auth_jurisdiction', jurisdiction);
      localStorage.setItem('pending_auth_job', role);
    } else {
      localStorage.setItem('pending_auth_role', 'citizen');
    }
    
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: `${window.location.origin}/home`
        }
      });
      if (error) throw error;
    } catch (error: any) {
      console.error('Error logging in with Google:', error.message);
      alert('Error logging in with Google: ' + error.message);
    }
  };

  const handleEmailSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    const email = emailRef.current?.value || "";
    const password = passwordRef.current?.value || "";
    const name = nameRef.current?.value || "";
    const phone = phoneRef.current?.value || "";

    if (!email || !password) {
      alert("Please enter email and password.");
      return;
    }

    if (accountType === 'authority' && !isLogin) {
      if (!department || !jurisdiction || !role) {
        alert("Please fill in all Authority details before proceeding.");
        return;
      }
      localStorage.setItem('pending_auth_role', 'authority');
      localStorage.setItem('pending_auth_dept', department);
      localStorage.setItem('pending_auth_jurisdiction', jurisdiction);
      localStorage.setItem('pending_auth_job', role);
    } else if (!isLogin) {
      localStorage.setItem('pending_auth_role', 'citizen');
    }

    try {
      if (isLogin) {
        const { error } = await supabase.auth.signInWithPassword({
          email,
          password,
        });
        if (error) throw error;
        window.location.href = accountType === 'authority' ? '/authority' : '/home';
      } else {
        if (!name || !phone) {
          alert("Please enter Name and Phone Number.");
          return;
        }
        const { error } = await supabase.auth.signUp({
          email,
          password,
          options: {
            data: {
              full_name: name,
              phone: phone,
              role_type: accountType
            }
          }
        });
        if (error) throw error;
        alert("Registration successful! You can now log in.");
        setIsLogin(true);
      }
    } catch (error: any) {
      console.error('Auth error:', error.message);
      alert('Authentication Error: ' + error.message);
    }
  };

  return (
    <div className="flex min-h-screen w-full flex-col bg-unisafe-smoke-white font-sans text-unisafe-midnight-blue antialiased selection:bg-unisafe-teal/30 selection:text-unisafe-midnight-blue lg:flex-row">
      {/* Left Image Panel */}
      <div className="relative flex w-full flex-col justify-between overflow-hidden p-8 md:p-12 lg:w-1/2 min-h-[420px] lg:min-h-screen shrink-0">
        {/* Background Image with Dark Gradient for crisp text readability */}
        <img
          src="https://images.unsplash.com/photo-1518005020951-eccb494ad742?q=80&w=2930&auto=format&fit=crop"
          alt="City map background"
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-unisafe-dark-midnight-blue/90 via-unisafe-midnight-blue/60 to-transparent pointer-events-none" />

        {/* Top Header */}
        <div className="relative z-10 flex items-center justify-between">
          <span className="text-xl lg:text-2xl font-bold tracking-tight text-white drop-shadow-sm flex items-center gap-2">
            <ShieldCheck className="w-6 h-6 text-unisafe-teal" />
            UniSafe
          </span>

          <a
            href="/"
            className="flex items-center gap-2 text-xs md:text-sm font-medium text-white/95 transition-all hover:text-white bg-white/15 hover:bg-white/25 backdrop-blur-md px-4 py-2 rounded-full border border-white/20 shadow-sm"
          >
            <HugeiconsIcon icon={ArrowLeft01Icon} className="size-4" />
            Back to Home
          </a>
        </div>

        {/* Bottom Content */}
        <div className="relative z-10 mt-12 lg:mt-0 pb-4">
          <h1 className="mb-4 max-w-xl text-3xl font-semibold leading-[1.15] tracking-tight text-white sm:text-4xl lg:text-5xl drop-shadow-md">
            Securing Our
            <br />
            Community Together.
          </h1>
          <p className="max-w-md text-sm md:text-base leading-relaxed text-unisafe-smoke-white drop-shadow-sm">
            Join UniSafe to report issues, track resolutions, and empower authorities to build a safer neighborhood for everyone.
          </p>
        </div>
      </div>

      {/* Right Form Panel */}
      <div className="flex w-full flex-1 flex-col items-center justify-center p-6 sm:p-12 lg:p-16 lg:w-1/2 min-h-screen relative overflow-x-hidden">
        <AnimatePresence mode="wait">
          {!accountType ? (
            // ================= STEP 1: ACCOUNT SELECTION =================
            <motion.div
              key="selection"
              variants={containerVariants}
              initial="hidden"
              animate="visible"
              exit="exit"
              className="w-full max-w-md md:max-w-lg xl:max-w-xl my-auto"
            >
              <motion.div variants={itemVariants} className="mb-8">
                <h2 className="mb-2 text-3xl md:text-4xl font-semibold tracking-tight text-neutral-900">
                  Welcome to UniSafe
                </h2>
                <p className="text-sm md:text-base text-neutral-500">
                  Please select your account type to continue
                </p>
              </motion.div>

              <motion.div variants={itemVariants} className="flex flex-col gap-4">
                <button
                  onClick={() => setAccountType("citizen")}
                  className="group relative flex w-full items-center gap-5 rounded-2xl border border-neutral-200 bg-white p-5 text-left transition-all hover:border-unisafe-teal hover:shadow-lg hover:shadow-unisafe-teal/10 active:scale-[0.99]"
                >
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-unisafe-teal/10 text-unisafe-midnight-blue group-hover:bg-unisafe-midnight-blue group-hover:text-white transition-colors">
                    <User className="h-6 w-6" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-neutral-900">Citizen</h3>
                    <p className="mt-1 text-sm text-neutral-500">Report issues, track community progress, and vote on local matters.</p>
                  </div>
                </button>

                <button
                  onClick={() => setAccountType("authority")}
                  className="group relative flex w-full items-center gap-5 rounded-2xl border border-neutral-200 bg-white p-5 text-left transition-all hover:border-unisafe-teal hover:shadow-lg hover:shadow-unisafe-teal/10 active:scale-[0.99]"
                >
                  <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-slate-50 text-slate-700 group-hover:bg-slate-900 group-hover:text-white transition-colors">
                    <ShieldCheck className="h-6 w-6" />
                  </div>
                  <div>
                    <h3 className="text-lg font-semibold text-neutral-900">Authority</h3>
                    <p className="mt-1 text-sm text-neutral-500">Manage tasks, verify reports, and update resolution statuses.</p>
                  </div>
                </button>
              </motion.div>
            </motion.div>
          ) : (
            // ================= STEP 2: AUTH FORM =================
            <motion.div
              key="auth-form"
              variants={containerVariants}
              initial="hidden"
              animate="visible"
              exit="exit"
              className="w-full max-w-md md:max-w-lg xl:max-w-xl my-auto"
            >
              <motion.div variants={itemVariants} className="mb-6">
                <button 
                  onClick={() => setAccountType(null)}
                  className="mb-6 flex items-center text-sm font-medium text-neutral-500 hover:text-neutral-900 transition-colors"
                >
                  <ArrowLeft className="mr-2 h-4 w-4" /> Back to account type
                </button>

                <div className="flex bg-neutral-100 p-1 rounded-xl mb-6">
                  <button
                    onClick={() => setIsLogin(true)}
                    className={`flex-1 text-sm font-medium py-2 rounded-lg transition-all ${isLogin ? 'bg-white text-neutral-900 shadow-sm' : 'text-neutral-500 hover:text-neutral-900'}`}
                  >
                    Login
                  </button>
                  <button
                    onClick={() => setIsLogin(false)}
                    className={`flex-1 text-sm font-medium py-2 rounded-lg transition-all ${!isLogin ? 'bg-white text-neutral-900 shadow-sm' : 'text-neutral-500 hover:text-neutral-900'}`}
                  >
                    Register
                  </button>
                </div>

                <h2 className="mb-2 text-3xl md:text-4xl font-semibold tracking-tight text-neutral-900 capitalize">
                  {accountType} {isLogin ? "Login" : "Registration"}
                </h2>
                <p className="text-sm md:text-base text-neutral-500">
                  {isLogin 
                    ? "Welcome back! Please enter your credentials to continue." 
                    : (accountType === "citizen" 
                        ? "Create your account to start improving your community" 
                        : "Enter your official credentials to request dashboard access")}
                </p>
              </motion.div>

              {/* Authority Specific Fields */}
              {accountType === "authority" && !isLogin && (
                <motion.div variants={itemVariants} className="mb-6 rounded-2xl border border-unisafe-teal/30 bg-unisafe-smoke-white p-5 space-y-4">
                  <h3 className="text-sm font-semibold text-unisafe-midnight-blue flex items-center gap-2">
                    <ShieldCheck className="w-4 h-4" /> Authority Details
                  </h3>
                  
                  <div className="space-y-4">
                    <div className="flex flex-col gap-1.5">
                      <label className="text-xs font-medium text-neutral-700 flex items-center gap-1.5">
                        <Building2 className="w-3.5 h-3.5 text-neutral-400" /> Department
                      </label>
                      <select 
                        value={department}
                        onChange={(e) => setDepartment(e.target.value)}
                        className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-2.5 text-sm text-neutral-900 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all appearance-none"
                      >
                        <option value="" disabled>Select Department</option>
                        <option value="sanitation">Sanitation & Waste</option>
                        <option value="traffic">Traffic & Roads</option>
                        <option value="infrastructure">Infrastructure</option>
                        <option value="water">Water & Utilities</option>
                        <option value="police">Police & Safety</option>
                      </select>
                    </div>

                    <div className="flex flex-col gap-1.5">
                      <label className="text-xs font-medium text-neutral-700 flex items-center gap-1.5">
                        <MapPin className="w-3.5 h-3.5 text-neutral-400" /> Jurisdiction
                      </label>
                      <select 
                        value={jurisdiction}
                        onChange={(e) => setJurisdiction(e.target.value)}
                        className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-2.5 text-sm text-neutral-900 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all appearance-none"
                      >
                        <option value="" disabled>Select Jurisdiction</option>
                        <option value="north_zone">North Zone</option>
                        <option value="south_zone">South Zone</option>
                        <option value="east_zone">East Zone</option>
                        <option value="west_zone">West Zone</option>
                        <option value="city_wide">City-wide</option>
                      </select>
                    </div>

                    <div className="flex flex-col gap-1.5">
                      <label className="text-xs font-medium text-neutral-700 flex items-center gap-1.5">
                        <Briefcase className="w-3.5 h-3.5 text-neutral-400" /> Role
                      </label>
                      <select 
                        value={role}
                        onChange={(e) => setRole(e.target.value)}
                        className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-2.5 text-sm text-neutral-900 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all appearance-none"
                      >
                        <option value="" disabled>Select Role</option>
                        <option value="field_worker">Field Worker</option>
                        <option value="inspector">Inspector</option>
                        <option value="manager">Manager / Supervisor</option>
                        <option value="admin">System Admin</option>
                      </select>
                    </div>
                  </div>
                </motion.div>
              )}

              {/* Google Login Button */}
              <motion.div variants={itemVariants} className="mb-6">
                <button
                  type="button"
                  onClick={handleGoogleLogin}
                  className="flex w-full items-center justify-center gap-3 rounded-xl border border-neutral-200 bg-white py-3.5 px-4 text-sm font-medium text-neutral-700 transition-all hover:bg-neutral-50 hover:border-neutral-300 active:bg-neutral-100 shadow-xs"
                >
                  <GoogleIcon className="text-xl" />
                  Continue with Google
                </button>
              </motion.div>

              {/* Divider */}
              <motion.div
                variants={itemVariants}
                className="relative mb-6 flex items-center"
              >
                <div className="grow border-t border-neutral-200"></div>
                <span className="px-4 text-sm text-neutral-400">or use email</span>
                <div className="grow border-t border-neutral-200"></div>
              </motion.div>

              {/* Form */}
              <form className="flex flex-col gap-4" onSubmit={handleEmailSubmit}>
                {!isLogin && (
                  <>
                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="name" className="text-sm font-medium text-neutral-900">
                        Full Name
                      </label>
                      <input
                        id="name"
                        type="text"
                        ref={nameRef}
                        defaultValue=""
                        placeholder="Enter your full name"
                        className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all"
                      />
                    </div>

                    <div className="flex flex-col gap-1.5">
                      <label htmlFor="phone" className="text-sm font-medium text-neutral-900">
                        Phone Number
                      </label>
                      <input
                        id="phone"
                        type="tel"
                        ref={phoneRef}
                        defaultValue=""
                        placeholder="Enter your phone number"
                        className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all"
                      />
                    </div>
                  </>
                )}

                <div className="flex flex-col gap-1.5">
                  <label
                    htmlFor="email"
                    className="text-sm font-medium text-neutral-900"
                  >
                    {isLogin ? "Email or Username" : "Email Address"}
                  </label>
                  <input
                    id="email"
                    type={isLogin ? "text" : "email"}
                    ref={emailRef}
                    defaultValue=""
                    placeholder={isLogin ? "Enter your email or username" : "Enter your email address"}
                    className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all"
                  />
                </div>

                <div className="flex flex-col gap-1.5">
                  <label
                    htmlFor="password"
                    className="text-sm font-medium text-neutral-900"
                  >
                    Password
                  </label>
                  <input
                    id="password"
                    type="password"
                    ref={passwordRef}
                    defaultValue=""
                    placeholder="Enter your password"
                    className="w-full rounded-xl border border-neutral-200 bg-white px-4 py-3 text-sm text-neutral-900 placeholder:text-neutral-400 focus:border-unisafe-midnight-blue focus:outline-none focus:ring-4 focus:ring-unisafe-midnight-blue/10 transition-all"
                  />
                </div>

                {/* Submit Button */}
                <motion.div variants={itemVariants} className="mt-2">
                  <button
                    type="submit"
                    className="w-full rounded-xl bg-unisafe-midnight-blue py-3.5 text-sm font-semibold text-white shadow-md shadow-unisafe-midnight-blue/20 transition-all hover:bg-unisafe-dark-midnight-blue active:scale-[0.99] cursor-pointer"
                  >
                    {isLogin ? "Sign In securely" : "Create Account"}
                  </button>
                </motion.div>
              </form>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
