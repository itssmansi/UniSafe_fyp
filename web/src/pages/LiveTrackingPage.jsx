import { useEffect, useState, useRef } from "react";
import { useSearchParams, Link } from "react-router-dom";
import { supabase } from "../services/supabase";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

// Fix standard Leaflet icon paths
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

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

  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const citizenMarkerRef = useRef(null);
  const destMarkerRef = useRef(null);
  const polylineRef = useRef(null);

  const startDemo = () => {
    setIsDemo(true);
    setError(null);
    setJourney({
      id: "demo-journey-session",
      destination_name: "Bandra Terminus, Mumbai",
      status: "in_progress",
      started_at: new Date(Date.now() - 12 * 60000).toISOString(),
      latest_latitude: 19.0544,
      latest_longitude: 72.8402,
      destination_latitude: 19.0607,
      destination_longitude: 72.8436,
      battery_level: 82,
      current_speed: 18,
    });
    setLastUpdated(new Date());
    setLoading(false);
  };

  // Fetch journey tracking via secure public RPC
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

      if (rpcError) {
        throw new Error(rpcError.message || "Failed to retrieve journey tracking session.");
      }

      if (!data || data.length === 0) {
        setJourney(null);
        setError("This tracking link is invalid, expired, or the journey has completed.");
      } else {
        const j = data[0];
        setJourney(j);
        setError(null);
        setLastUpdated(new Date(j.last_location_update || j.started_at || Date.now()));
      }
    } catch (err) {
      if (isInitial) {
        setError(err.message || "Network error fetching tracking status.");
      }
    } finally {
      if (isInitial) setLoading(false);
    }
  };

  // Initial fetch and 5-second polling loop
  useEffect(() => {
    fetchTracking(true);

    const interval = setInterval(() => {
      fetchTracking(false);
    }, 5000);

    return () => clearInterval(interval);
  }, [token]);

  // Track seconds elapsed since last update
  useEffect(() => {
    const timer = setInterval(() => {
      if (lastUpdated) {
        const diff = Math.floor((Date.now() - lastUpdated.getTime()) / 1000);
        setSecondsAgo(Math.max(0, diff));
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [lastUpdated]);

  // Leaflet Map Initialization and Pin Updates
  useEffect(() => {
    if (!journey || !mapContainerRef.current) return;

    const citizenLat = journey.latest_latitude;
    const citizenLng = journey.latest_longitude;
    const destLat = journey.destination_latitude;
    const destLng = journey.destination_longitude;

    if (!citizenLat || !citizenLng) return;

    // Create Map instance once
    if (!mapInstanceRef.current) {
      const map = L.map(mapContainerRef.current, {
        zoomControl: true,
        attributionControl: true,
      }).setView([citizenLat, citizenLng], 15);

      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
        maxZoom: 19,
      }).addTo(map);

      mapInstanceRef.current = map;
    }

    const map = mapInstanceRef.current;

    // Custom pulsing citizen icon
    const citizenIcon = L.divIcon({
      className: "unisafe-citizen-marker",
      html: `
        <div style="position: relative; width: 28px; height: 28px;">
          <div style="position: absolute; width: 28px; height: 28px; background: rgba(59, 130, 246, 0.35); border-radius: 50%; animation: pulse 2s infinite;"></div>
          <div style="position: absolute; top: 4px; left: 4px; width: 20px; height: 20px; background: #2563eb; border: 2.5px solid white; border-radius: 50%; box-shadow: 0 2px 6px rgba(0,0,0,0.3);"></div>
        </div>
      `,
      iconSize: [28, 28],
      iconAnchor: [14, 14],
    });

    // Update or create Citizen Marker
    if (!citizenMarkerRef.current) {
      citizenMarkerRef.current = L.marker([citizenLat, citizenLng], { icon: citizenIcon })
        .addTo(map)
        .bindPopup("<b>Citizen's Current Location</b><br>Updated live");
    } else {
      citizenMarkerRef.current.setLatLng([citizenLat, citizenLng]);
    }

    // Destination Marker
    if (destLat && destLng) {
      const destIcon = L.divIcon({
        className: "unisafe-dest-marker",
        html: `
          <div style="background: #dc2626; color: white; border-radius: 50%; width: 26px; height: 26px; display: flex; align-items: center; justify-content: center; font-size: 14px; box-shadow: 0 2px 6px rgba(0,0,0,0.3); border: 2px solid white;">
            🏁
          </div>
        `,
        iconSize: [26, 26],
        iconAnchor: [13, 13],
      });

      if (!destMarkerRef.current) {
        destMarkerRef.current = L.marker([destLat, destLng], { icon: destIcon })
          .addTo(map)
          .bindPopup(`<b>Destination</b><br>${journey.destination_name || "Final Point"}`);
      } else {
        destMarkerRef.current.setLatLng([destLat, destLng]);
      }

      // Polyline connecting points
      const pathPoints = [
        [citizenLat, citizenLng],
        [destLat, destLng],
      ];
      if (!polylineRef.current) {
        polylineRef.current = L.polyline(pathPoints, {
          color: "#4f46e5",
          weight: 4,
          dashArray: "6, 8",
          opacity: 0.8,
        }).addTo(map);
      } else {
        polylineRef.current.setLatLngs(pathPoints);
      }

      // Fit bounds on first load
      try {
        const bounds = L.latLngBounds([
          [citizenLat, citizenLng],
          [destLat, destLng],
        ]);
        map.fitBounds(bounds, { padding: [50, 50], maxZoom: 16 });
      } catch (_) {}
    }
  }, [journey]);

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans">
      {/* Top Navigation Bar */}
      <header className="bg-slate-800/90 backdrop-blur border-b border-slate-700/60 px-4 py-3 sticky top-0 z-50 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center font-bold text-base shadow-sm">
            🛡️
          </div>
          <div>
            <h1 className="font-bold text-sm tracking-tight text-white flex items-center gap-1.5">
              UniSafe Safe Journey
              <span className="text-[10px] bg-emerald-500/20 text-emerald-400 font-semibold px-2 py-0.5 rounded-full border border-emerald-500/30">
                LIVE
              </span>
            </h1>
            <p className="text-[11px] text-slate-400">Trusted Contact Tracking Portal</p>
          </div>
        </div>

        {journey && (
          <div className="text-right">
            <span className="inline-flex items-center gap-1.5 text-xs text-emerald-400 font-medium bg-emerald-950/60 px-2.5 py-1 rounded-full border border-emerald-800/60">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping"></span>
              {secondsAgo < 5 ? "Moving Now" : `${secondsAgo}s ago`}
            </span>
          </div>
        )}
      </header>

      {/* Main Content Area */}
      <main className="flex-1 flex flex-col max-w-4xl w-full mx-auto p-4 gap-4">
        {loading ? (
          <div className="flex-1 flex flex-col items-center justify-center py-20 text-center">
            <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mb-4"></div>
            <p className="font-semibold text-slate-200">Connecting to secure live journey stream...</p>
            <p className="text-xs text-slate-400 mt-1">Verifying encrypted tracking token</p>
          </div>
        ) : error || !journey ? (
          <div className="flex-1 flex flex-col items-center justify-center py-16 px-4 text-center">
            <div className="w-16 h-16 bg-rose-500/10 text-rose-400 rounded-2xl flex items-center justify-center text-3xl mb-4 border border-rose-500/20">
              ⚠️
            </div>
            <h2 className="text-xl font-bold text-white mb-2">Tracking Session Unavailable</h2>
            <p className="text-sm text-slate-400 max-w-md mb-6">
              {error || "This journey tracking session is no longer active. The citizen may have safely reached their destination or ended the session."}
            </p>

            {/* Token entry and demo preview */}
            <div className="flex flex-col items-center gap-3 w-full max-w-md mb-6">
              <div className="flex w-full gap-2">
                <input
                  type="text"
                  placeholder="Paste journey token here..."
                  value={manualToken}
                  onChange={(e) => setManualToken(e.target.value)}
                  className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
                />
                <button
                  onClick={() => {
                    if (manualToken.trim()) {
                      window.location.search = `?token=${encodeURIComponent(manualToken.trim())}`;
                    }
                  }}
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold transition-colors"
                >
                  Track
                </button>
              </div>

              <button
                onClick={startDemo}
                className="w-full py-2.5 px-4 bg-emerald-600/20 hover:bg-emerald-600/30 border border-emerald-500/40 text-emerald-300 rounded-xl text-xs font-bold transition-all flex items-center justify-center gap-2 shadow-sm"
              >
                <span>🚀</span> Preview Interactive Demo Tracking Session
              </button>
            </div>

            <div className="p-4 bg-slate-800/80 rounded-xl border border-slate-700 text-left max-w-md w-full">
              <h3 className="text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">Notice for Trusted Contacts:</h3>
              <ul className="text-xs text-slate-400 space-y-1.5 list-disc list-inside">
                <li>Active tracking links expire automatically when a journey completes.</li>
                <li>If you received an emergency SOS alert, call emergency services directly.</li>
              </ul>
            </div>
          </div>
        ) : (
          <>
            {isDemo && (
              <div className="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl flex items-center justify-between text-xs text-amber-300">
                <span>⚡ <strong>Interactive Demo Preview:</strong> Simulating real-time journey tracking for trusted contacts.</span>
                <button
                  onClick={() => {
                    setIsDemo(false);
                    setJourney(null);
                    setError("No tracking token provided in the URL.");
                  }}
                  className="px-2.5 py-1 bg-amber-500/20 hover:bg-amber-500/30 rounded-lg text-amber-200 font-semibold"
                >
                  Exit Demo
                </button>
              </div>
            )}
            {/* Journey Details HUD Card */}
            <div className="bg-slate-800/90 rounded-2xl border border-slate-700/80 p-4 shadow-lg backdrop-blur">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div>
                  <span className="text-[11px] font-bold text-indigo-400 uppercase tracking-wider">Heading Towards</span>
                  <h2 className="text-lg font-bold text-white flex items-center gap-2 mt-0.5">
                    📍 {journey.destination_name || "Destination"}
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Live updates stream directly from the citizen's mobile GPS device.
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <a
                    href={`https://www.google.com/maps/dir/?api=1&destination=${journey.latest_latitude},${journey.latest_longitude}`}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 px-3 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold shadow-sm transition-colors"
                  >
                    🗺️ Open in Google Maps
                  </a>
                  <a
                    href="tel:112"
                    className="inline-flex items-center gap-1.5 px-3 py-2 bg-rose-600/90 hover:bg-rose-500 text-white rounded-xl text-xs font-semibold shadow-sm transition-colors"
                  >
                    🚨 Call 112
                  </a>
                </div>
              </div>
            </div>

            {/* Map Container */}
            <div className="flex-1 min-h-[420px] rounded-2xl overflow-hidden border border-slate-700/80 shadow-2xl relative">
              <div ref={mapContainerRef} className="w-full h-full min-h-[420px] z-10" />

              {/* Map Footer Overlay Banner */}
              <div className="absolute bottom-3 left-3 z-[1000] bg-slate-900/90 backdrop-blur px-3 py-1.5 rounded-lg border border-slate-700 text-[11px] text-slate-300 shadow">
                🔵 Blue radar: Citizen moving location &nbsp;|&nbsp; 🏁 Red flag: Destination
              </div>
            </div>

            {/* Safety Footer Disclaimers */}
            <div className="p-3 bg-slate-800/40 rounded-xl border border-slate-800 text-[11px] text-slate-400 flex items-center justify-between">
              <span>Encrypted end-to-end token validation • No login required</span>
              <span>UniSafe Citizen FYP</span>
            </div>
          </>
        )}
      </main>
    </div>
  );
}
