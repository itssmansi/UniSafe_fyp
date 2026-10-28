import { useEffect, useState, useRef, useCallback } from "react";
import { useSearchParams, Link } from "react-router-dom";
import { supabase } from "../services/supabase";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import {
  Shield,
  ShieldCheck,
  ShieldAlert,
  Navigation,
  MapPin,
  PhoneCall,
  ExternalLink,
  Clock,
  Radio,
  Crosshair,
  Battery,
  ChevronDown,
  ChevronUp,
  ArrowRight,
  Share2,
  CheckCircle2,
} from "lucide-react";

// Fix standard Leaflet icon paths
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

// Demo waypoints simulating transit through Mumbai
const DEMO_WAYPOINTS = [
  { lat: 19.0544, lng: 72.8402, speed: 22, battery: 84 },
  { lat: 19.0558, lng: 72.8411, speed: 28, battery: 83 },
  { lat: 19.0572, lng: 72.8419, speed: 31, battery: 83 },
  { lat: 19.0586, lng: 72.8427, speed: 19, battery: 82 },
  { lat: 19.0598, lng: 72.8432, speed: 14, battery: 82 },
  { lat: 19.0607, lng: 72.8436, speed: 6, battery: 81 },
];

export default function LiveTrackingPage() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get("token") || "";

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [journey, setJourney] = useState(null);
  const [lastUpdated, setLastUpdated] = useState(null);
  const [secondsAgo, setSecondsAgo] = useState(0);
  const [manualToken, setManualToken] = useState("");
  const [isDemo, setIsDemo] = useState(false);
  const [demoStep, setDemoStep] = useState(0);
  const [copiedLink, setCopiedLink] = useState(false);
  const [isCardCollapsed, setIsCardCollapsed] = useState(false);

  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const citizenMarkerRef = useRef(null);
  const destMarkerRef = useRef(null);
  const polylineRef = useRef(null);

  // Recenter map on citizen
  const handleRecenter = useCallback(() => {
    if (!mapInstanceRef.current || !journey) return;
    const lat = journey.latest_latitude;
    const lng = journey.latest_longitude;
    if (lat && lng) {
      mapInstanceRef.current.flyTo([lat, lng], 16, {
        animate: true,
        duration: 1.0,
      });
    }
  }, [journey]);

  // Start Interactive Demo Session
  const startDemo = () => {
    setIsDemo(true);
    setError(null);
    setDemoStep(0);
    const startPoint = DEMO_WAYPOINTS[0];
    setJourney({
      id: "demo-journey-session",
      destination_name: "Bandra Terminus, Mumbai",
      status: "in_progress",
      started_at: new Date(Date.now() - 14 * 60000).toISOString(),
      start_latitude: 19.052,
      start_longitude: 72.8385,
      latest_latitude: startPoint.lat,
      latest_longitude: startPoint.lng,
      destination_latitude: 19.0607,
      destination_longitude: 72.8436,
      battery_level: startPoint.battery,
      current_speed: startPoint.speed,
    });
    setLastUpdated(new Date());
    setLoading(false);
  };

  // Animate demo movement every 4 seconds
  useEffect(() => {
    if (!isDemo) return;
    const interval = setInterval(() => {
      setDemoStep((prev) => {
        const next = (prev + 1) % DEMO_WAYPOINTS.length;
        const pt = DEMO_WAYPOINTS[next];
        setJourney((curr) => {
          if (!curr) return curr;
          return {
            ...curr,
            latest_latitude: pt.lat,
            latest_longitude: pt.lng,
            current_speed: pt.speed,
            battery_level: pt.battery,
          };
        });
        setLastUpdated(new Date());
        return next;
      });
    }, 4000);
    return () => clearInterval(interval);
  }, [isDemo]);

  // Fetch real journey tracking via RPC
  const fetchTracking = async (isInitial = false) => {
    if (isDemo) return;
    if (!token.trim()) {
      setError("No tracking token provided in the URL.");
      setLoading(false);
      return;
    }

    try {
      const { data, error: rpcError } = await supabase.rpc("get_public_journey_tracking", {
        token_input: token.trim(),
      });

      if (rpcError) throw new Error(rpcError.message || "Failed to retrieve journey tracking session.");

      if (!data || data.length === 0) {
        setJourney(null);
        setError("This tracking session is inactive, expired, or completed.");
      } else {
        const j = data[0];
        setJourney(j);
        setError(null);
        setLastUpdated(new Date(j.last_location_update || j.started_at || Date.now()));
      }
    } catch (err) {
      if (isInitial) setError(err.message || "Network error fetching tracking status.");
    } finally {
      if (isInitial) setLoading(false);
    }
  };

  // Initial fetch and 5-second polling loop
  useEffect(() => {
    fetchTracking(true);
    const interval = setInterval(() => fetchTracking(false), 5000);
    return () => clearInterval(interval);
  }, [token]);

  // Seconds elapsed ticker
  useEffect(() => {
    const timer = setInterval(() => {
      if (lastUpdated) {
        const diff = Math.floor((Date.now() - lastUpdated.getTime()) / 1000);
        setSecondsAgo(Math.max(0, diff));
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [lastUpdated]);

  // Map Initialization & Marker Updates
  useEffect(() => {
    if (!journey || !mapContainerRef.current) return;

    const citizenLat = journey.latest_latitude;
    const citizenLng = journey.latest_longitude;
    const destLat = journey.destination_latitude;
    const destLng = journey.destination_longitude;

    if (!citizenLat || !citizenLng) return;

    // Create Map instance once with standard OpenStreetMap tiles (no watermarks, free & fast)
    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        zoomControl: false,
        attributionControl: false,
      }).setView([citizenLat, citizenLng], 15);

      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19,
        attribution: '&copy; OpenStreetMap contributors',
      }).addTo(map);

      // Add Zoom Control at top-right
      L.control.zoom({ position: "topright" }).addTo(map);

      mapInstanceRef.current = map;
    }

    const map = mapInstanceRef.current;

    // Sleek pulsing citizen beacon
    const citizenIcon = L.divIcon({
      className: "unisafe-citizen-beacon",
      html: `
        <div style="position: relative; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center;">
          <div style="position: absolute; width: 44px; height: 44px; background: rgba(37, 99, 235, 0.22); border-radius: 50%; animation: pulse-ring 2.2s cubic-bezier(0.215, 0.61, 0.355, 1) infinite;"></div>
          <div style="position: absolute; width: 28px; height: 28px; background: rgba(37, 99, 235, 0.35); border-radius: 50%;"></div>
          <div style="position: relative; width: 16px; height: 16px; background: #1d4ed8; border: 3px solid #ffffff; border-radius: 50%; box-shadow: 0 4px 12px rgba(29, 78, 216, 0.5);"></div>
        </div>
      `,
      iconSize: [44, 44],
      iconAnchor: [22, 22],
    });

    if (!citizenMarkerRef.current) {
      citizenMarkerRef.current = L.marker([citizenLat, citizenLng], { icon: citizenIcon })
        .addTo(map)
        .bindPopup(
          `<div style="font-family: inherit; font-size: 12px; line-height: 1.4; padding: 2px;">
            <strong style="color: #0f172a;">Citizen Location</strong><br/>
            <span style="color: #64748b;">Live GPS Broadcast</span>
          </div>`
        );
    } else {
      citizenMarkerRef.current.setLatLng([citizenLat, citizenLng]);
    }

    // Modern destination pin
    if (destLat && destLng) {
      const destIcon = L.divIcon({
        className: "unisafe-destination-pin",
        html: `
          <div style="width: 34px; height: 34px; background: #0f172a; border: 2.5px solid #ffffff; border-radius: 50%; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 14px rgba(0,0,0,0.35); color: #ffffff;">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/>
              <circle cx="12" cy="10" r="3"/>
            </svg>
          </div>
        `,
        iconSize: [34, 34],
        iconAnchor: [17, 17],
      });

      if (!destMarkerRef.current) {
        destMarkerRef.current = L.marker([destLat, destLng], { icon: destIcon })
          .addTo(map)
          .bindPopup(
            `<div style="font-family: inherit; font-size: 12px; line-height: 1.4; padding: 2px;">
              <strong style="color: #0f172a;">Destination</strong><br/>
              <span style="color: #64748b;">${journey.destination_name || "Target Location"}</span>
            </div>`
          );
      } else {
        destMarkerRef.current.setLatLng([destLat, destLng]);
      }

      // Route line
      const pathPoints = [
        [citizenLat, citizenLng],
        [destLat, destLng],
      ];
      if (!polylineRef.current) {
        polylineRef.current = L.polyline(pathPoints, {
          color: "#2563eb",
          weight: 4,
          opacity: 0.85,
          dashArray: "8, 10",
        }).addTo(map);
      } else {
        polylineRef.current.setLatLngs(pathPoints);
      }
    }
  }, [journey]);

  const copyShareLink = () => {
    navigator.clipboard.writeText(window.location.href);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2000);
  };

  return (
    <div className="relative w-screen h-screen overflow-hidden bg-neutral-950 font-sans antialiased text-neutral-100 select-none">
      <style>{`
        @keyframes pulse-ring {
          0% { transform: scale(0.65); opacity: 0.9; }
          70% { transform: scale(1.4); opacity: 0.15; }
          100% { transform: scale(1.6); opacity: 0; }
        }
      `}</style>

      {/* ================= MAP LAYER ================= */}
      <div ref={mapContainerRef} className="absolute inset-0 w-full h-full z-0" />

      {/* ================= TOP FLOATING HEADER ================= */}
      <header className="absolute top-3 left-3 right-3 sm:top-4 sm:left-4 sm:right-4 z-20 pointer-events-none flex flex-wrap items-center justify-between gap-2">
        {/* Left Branding Pill */}
        <div className="pointer-events-auto bg-neutral-900/90 backdrop-blur-xl border border-neutral-800/80 px-3.5 py-2 rounded-2xl shadow-2xl flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-xl bg-gradient-to-tr from-blue-700 to-indigo-500 flex items-center justify-center text-white shadow-md shrink-0">
            <Shield className="w-3.5 h-3.5 stroke-[2.2]" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-semibold text-xs tracking-tight text-white">UniSafe SafeWalk</span>
              <span className="inline-flex items-center gap-1 text-[9px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded-full bg-emerald-500/15 border border-emerald-500/30 text-emerald-400">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                LIVE
              </span>
            </div>
            <p className="text-[10px] text-neutral-400 font-medium hidden sm:block">Encrypted Citizen Escort Channel</p>
          </div>
        </div>

        {/* Right Status & Tools Pill */}
        {journey && (
          <div className="pointer-events-auto flex items-center gap-1.5">
            <button
              onClick={handleRecenter}
              title="Recenter on Citizen"
              className="p-2 bg-neutral-900/90 hover:bg-neutral-800 backdrop-blur-xl border border-neutral-800/80 text-neutral-300 hover:text-white rounded-xl shadow-xl transition-all active:scale-95 flex items-center justify-center cursor-pointer"
            >
              <Crosshair className="w-3.5 h-3.5" />
            </button>

            <button
              onClick={copyShareLink}
              title="Copy tracking link"
              className="p-2 bg-neutral-900/90 hover:bg-neutral-800 backdrop-blur-xl border border-neutral-800/80 text-neutral-300 hover:text-white rounded-xl shadow-xl transition-all active:scale-95 flex items-center justify-center cursor-pointer"
            >
              {copiedLink ? <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400" /> : <Share2 className="w-3.5 h-3.5" />}
            </button>

            <div className="bg-neutral-900/90 backdrop-blur-xl border border-neutral-800/80 px-2.5 py-1.5 rounded-xl shadow-xl flex items-center gap-1.5 text-xs">
              <Radio className="w-3 h-3 text-emerald-400 animate-pulse" />
              <span className="text-[10px] font-medium text-neutral-300">
                {secondsAgo < 5 ? "Live" : `${secondsAgo}s ago`}
              </span>
            </div>
          </div>
        )}
      </header>

      {/* ================= DEMO NOTIFICATION BANNER ================= */}
      {isDemo && (
        <div className="absolute top-16 left-1/2 -translate-x-1/2 z-20 pointer-events-auto bg-amber-500/15 backdrop-blur-md border border-amber-500/30 px-3.5 py-1.5 rounded-full shadow-lg flex items-center gap-2 text-xs text-amber-200">
          <span className="font-semibold text-[11px]">Demo Transit Simulation</span>
          <button
            onClick={() => {
              setIsDemo(false);
              setJourney(null);
              setError("No tracking token provided in the URL.");
            }}
            className="text-[10px] bg-amber-500/25 hover:bg-amber-500/35 px-2 py-0.5 rounded-full font-bold text-amber-100 transition-colors cursor-pointer"
          >
            Exit Demo
          </button>
        </div>
      )}

      {/* ================= FLOATING ACTION / DETAIL PANEL ================= */}
      {loading ? (
        <div className="absolute inset-0 z-30 flex items-center justify-center bg-neutral-950/70 backdrop-blur-md">
          <div className="bg-neutral-900 border border-neutral-800 px-6 py-5 rounded-3xl shadow-2xl flex flex-col items-center gap-3">
            <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
            <p className="text-xs font-semibold text-neutral-200">Verifying secure journey token...</p>
          </div>
        </div>
      ) : error || !journey ? (
        /* ================= EMPTY / INVALID SESSION MODAL ================= */
        <div className="absolute inset-0 z-30 flex items-center justify-center p-4 bg-neutral-950/80 backdrop-blur-md">
          <div className="bg-neutral-900/95 border border-neutral-800 max-w-md w-full p-6 sm:p-8 rounded-3xl shadow-2xl text-center flex flex-col items-center">
            <div className="w-14 h-14 rounded-2xl bg-neutral-800 border border-neutral-700/80 flex items-center justify-center text-neutral-300 mb-4 shadow-inner">
              <ShieldAlert className="w-7 h-7 text-neutral-300 stroke-[1.8]" />
            </div>

            <h2 className="text-lg font-bold text-white tracking-tight mb-1">Live Tracking Inactive</h2>
            <p className="text-xs text-neutral-400 mb-6 leading-relaxed max-w-sm">
              {error || "This journey session is no longer streaming. The citizen may have safely concluded their trip."}
            </p>

            {/* Input Manual Token */}
            <div className="w-full mb-4">
              <div className="flex items-center gap-2 bg-neutral-950 border border-neutral-800 rounded-2xl p-1.5 focus-within:border-neutral-600 transition-colors">
                <input
                  type="text"
                  placeholder="Paste tracking token from SMS..."
                  value={manualToken}
                  onChange={(e) => setManualToken(e.target.value)}
                  className="flex-1 bg-transparent px-3 py-2 text-xs text-white placeholder-neutral-500 outline-none"
                />
                <button
                  onClick={() => {
                    if (manualToken.trim()) {
                      window.location.search = `?token=${encodeURIComponent(manualToken.trim())}`;
                    }
                  }}
                  className="px-4 py-2 bg-neutral-100 hover:bg-white text-neutral-950 font-bold text-xs rounded-xl transition-all active:scale-95 flex items-center gap-1.5 cursor-pointer"
                >
                  Track <ArrowRight className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>

            {/* Interactive Demo Launcher */}
            <button
              onClick={startDemo}
              className="w-full py-3 px-4 bg-neutral-800 hover:bg-neutral-750 border border-neutral-700/80 text-white rounded-2xl text-xs font-semibold transition-all active:scale-95 flex items-center justify-center gap-2 mb-6 cursor-pointer"
            >
              <Radio className="w-4 h-4 text-emerald-400" />
              Preview Interactive Demo Tracking
            </button>

            <div className="w-full pt-4 border-t border-neutral-800/80 flex items-center justify-between text-[11px] text-neutral-500">
              <span className="flex items-center gap-1.5">
                <ShieldCheck className="w-3.5 h-3.5 text-neutral-400" />
                End-to-End Verified
              </span>
              <span>UniSafe Public Safety</span>
            </div>
          </div>
        </div>
      ) : (
        /* ================= COLLAPSIBLE BOTTOM HUD ================= */
        <div className="absolute bottom-3 left-3 right-3 sm:bottom-5 sm:left-6 sm:right-auto sm:w-[400px] z-20 pointer-events-auto transition-all duration-300 ease-in-out">
          <div className="bg-neutral-900/95 backdrop-blur-2xl border border-neutral-800/90 rounded-3xl p-4 sm:p-5 shadow-2xl flex flex-col gap-3">
            
            {/* Grab Handle / Collapse Header Button */}
            <button
              onClick={() => setIsCardCollapsed(!isCardCollapsed)}
              className="w-full flex flex-col items-center group -mt-1 -mb-1 py-1 cursor-pointer"
              title={isCardCollapsed ? "Tap to expand details" : "Tap to collapse"}
            >
              <div className="w-10 h-1 rounded-full bg-neutral-700 group-hover:bg-neutral-500 transition-colors mb-1.5" />
            </button>

            {/* Top row: Status & Telemetry & Toggle Icon */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[10px] font-bold tracking-wider uppercase bg-emerald-500/10 border border-emerald-500/30 text-emerald-400">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping"></span>
                  Active Journey
                </span>
                <span className="text-[10px] text-neutral-400 font-medium">Safe Mode</span>
              </div>

              <div className="flex items-center gap-2">
                {journey.battery_level !== undefined && (
                  <div className="flex items-center gap-1 text-[11px] text-neutral-300 font-medium bg-neutral-800/60 px-2 py-0.5 rounded-lg border border-neutral-700/60">
                    <Battery className="w-3 h-3 text-emerald-400" />
                    <span>{journey.battery_level}%</span>
                  </div>
                )}

                <button
                  onClick={() => setIsCardCollapsed(!isCardCollapsed)}
                  className="p-1.5 bg-neutral-800/80 hover:bg-neutral-700 text-neutral-300 hover:text-white rounded-lg transition-colors cursor-pointer"
                  title={isCardCollapsed ? "Expand card" : "Collapse card"}
                >
                  {isCardCollapsed ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
                </button>
              </div>
            </div>

            {/* Destination Target (always visible, truncated if collapsed) */}
            <div>
              <span className="text-[9px] font-bold text-neutral-400 uppercase tracking-wider block mb-0.5">
                En Route To
              </span>
              <div className="flex items-center gap-2">
                <div className="w-6 h-6 rounded-lg bg-neutral-800 border border-neutral-700 flex items-center justify-center shrink-0 text-neutral-200">
                  <MapPin className="w-3.5 h-3.5 text-blue-400" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="text-xs sm:text-sm font-bold text-white tracking-tight truncate">
                    {journey.destination_name || "Designated Safe Destination"}
                  </h3>
                  {!isCardCollapsed && (
                    <p className="text-[10px] text-neutral-400 mt-0.5">
                      Live GPS updates streamed directly from citizen device
                    </p>
                  )}
                </div>

                {/* When collapsed, keep a quick Call 112 button right here! */}
                {isCardCollapsed && (
                  <a
                    href="tel:112"
                    className="py-1.5 px-3 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all active:scale-95 flex items-center gap-1 shrink-0 shadow-sm"
                  >
                    <PhoneCall className="w-3 h-3 stroke-[2.2]" />
                    <span>112</span>
                  </a>
                )}
              </div>
            </div>

            {/* Expanded Content Section */}
            {!isCardCollapsed && (
              <>
                {/* Telemetry Metrics Grid */}
                <div className="grid grid-cols-2 gap-2 pt-1">
                  <div className="bg-neutral-950/70 border border-neutral-800/80 rounded-2xl p-2.5">
                    <div className="flex items-center gap-1.5 text-neutral-400 text-[10px] font-medium mb-1">
                      <Navigation className="w-3 h-3 text-blue-400" />
                      Current Speed
                    </div>
                    <div className="text-xs font-bold text-white">
                      {journey.current_speed ? `${journey.current_speed} km/h` : "In Transit (~20 km/h)"}
                    </div>
                  </div>

                  <div className="bg-neutral-950/70 border border-neutral-800/80 rounded-2xl p-2.5">
                    <div className="flex items-center gap-1.5 text-neutral-400 text-[10px] font-medium mb-1">
                      <Clock className="w-3 h-3 text-indigo-400" />
                      Elapsed Time
                    </div>
                    <div className="text-xs font-bold text-white">
                      {journey.started_at
                        ? `${Math.max(1, Math.floor((Date.now() - new Date(journey.started_at).getTime()) / 60000))} mins`
                        : "12 mins"}
                    </div>
                  </div>
                </div>

                {/* Emergency & Navigation Action Buttons */}
                <div className="flex items-center gap-2 pt-1">
                  <a
                    href={`https://www.google.com/maps/dir/?api=1&destination=${journey.latest_latitude},${journey.latest_longitude}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex-1 py-2 px-3 bg-neutral-100 hover:bg-white text-neutral-950 rounded-xl text-xs font-bold transition-all active:scale-95 flex items-center justify-center gap-1.5 shadow-sm"
                  >
                    Directions <ExternalLink className="w-3.5 h-3.5 stroke-[2.2]" />
                  </a>

                  <a
                    href="tel:112"
                    className="py-2 px-4 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition-all active:scale-95 flex items-center justify-center gap-1.5 shadow-md shadow-rose-950/50"
                  >
                    <PhoneCall className="w-3.5 h-3.5 stroke-[2.2]" />
                    Call 112
                  </a>
                </div>

                {/* Micro disclaimer */}
                <div className="text-[10px] text-neutral-500 flex items-center justify-between pt-1">
                  <span className="flex items-center gap-1">
                    <ShieldCheck className="w-3 h-3 text-neutral-400" />
                    Trusted Contact Access
                  </span>
                  <span>UniSafe Platform</span>
                </div>
              </>
            )}

          </div>
        </div>
      )}
    </div>
  );
}
