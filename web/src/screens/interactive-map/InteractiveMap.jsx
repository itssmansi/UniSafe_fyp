import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import { supabase } from '../../services/supabase';
import { useNavigate } from 'react-router-dom';

// --- Configuration & Constants ---
const CATEGORIES_CONFIG = {
  Infrastructure: {
    color: '#FF6B6B', lightBg: '#FEF2F2',
    svg: `<svg style="width:20px;height:20px" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>`,
    subcategories: ["Nonfunctional Street Lights", "Potholes", "Water Logging", "Prolonged Road Work", "Drainage"]
  },
  Sanitation: {
    color: '#F59E0B', lightBg: '#FFFBEB',
    svg: `<svg style="width:20px;height:20px" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>`,
    subcategories: ["Garbage Scattered on Road", "Public Washroom Cleanliness", "Garbage Dumping Near Beach/River", "Untimely Garbage Collection / Overflowing Bins"]
  },
  Safety: {
    color: '#3B82F6', lightBg: '#EFF6FF',
    svg: `<svg style="width:20px;height:20px" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>`,
    subcategories: ["Open Manholes", "Non-existent Footpath", "Women Safety", "Illegal Parking", "Theft / Robbery", "Harassment / Eve-Teasing", "Assault / Violence", "Poor Street Lighting", "Fire Hazard", "Electrical Hazard", "Exposed Wires", "Child Safety Concern", "Stray Animal Threat"]
  },
  Greenery: {
    color: '#10B981', lightBg: '#ECFDF5',
    svg: `<svg style="width:20px;height:20px" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10Z"/><path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"/></svg>`,
    subcategories: ["Waste Dumping in Green Area", "Poor Landscape Maintenance", "Watering Required for Plants", "Encroachment on Green Spaces", "Pest or Insect Infestation", "Overgrown Vegetation", "Need Tree Plantation", "Illegal Tree Cutting", "Public Problems on Greenery"]
  }
};

const getTeardropHTML = (category, isDragging = false) => {
  let parentCategory = category;
  for (const [parent, data] of Object.entries(CATEGORIES_CONFIG)) {
    if (data.subcategories.includes(category)) {
      parentCategory = parent;
      break;
    }
  }
  const config = CATEGORIES_CONFIG[parentCategory] || CATEGORIES_CONFIG['Infrastructure'];
  return `
    <div style="width:56px; height:56px; position:relative; display:flex; justify-content:center;" class="${isDragging ? '' : 'animate-[dropBounce_0.5s_cubic-bezier(0.34,1.56,0.64,1)_forwards]'}">
       <div style="
           position:absolute; top: 2px;
           width: 36px; height: 36px;
           background: ${config.color};
           border: 3px solid white;
           border-radius: 50% 50% 50% 0;
           transform: rotate(-45deg);
           box-shadow: -2px 6px 12px rgba(0,0,0,0.3);
           display: flex; align-items: center; justify-content: center;
           transition: all 0.2s ease;
       ">
         <div style="transform: rotate(45deg); color: white; display: flex; align-items:center; justify-content:center; width:20px; height:20px; drop-shadow(0 2px 2px rgba(0,0,0,0.2))">
            ${config.svg}
         </div>
       </div>
    </div>
  `;
};

const getTeardropIcon = (category) => {
  return L.divIcon({
    className: 'bg-transparent',
    html: getTeardropHTML(category, false),
    iconSize: [56, 56],
    iconAnchor: [28, 50]
  });
};

const getUserLocationIcon = () => {
  return L.divIcon({
    className: 'bg-transparent',
    html: `
      <div class="relative flex items-center justify-center w-12 h-12">
        <div class="absolute w-6 h-6 bg-[#3B82F6] rounded-full shadow-[0_0_15px_5px_rgba(59,130,246,0.5)] border-[3.5px] border-white animate-[dropBounce_0.5s_cubic-bezier(0.34,1.56,0.64,1)_forwards]"></div>
      </div>
    `,
    iconSize: [48, 48],
    iconAnchor: [24, 24],
  });
};

const MapController = ({ step, pinLocation, setPinLocation, setMapInstance, draggingCat, setDraggingCat, setActiveCategory, setStep }) => {
  const map = useMap();
  useEffect(() => {
    setMapInstance(map);
  }, [map, setMapInstance]);

  useEffect(() => {
    const handleMove = (e) => {};
    const handleUp = (e) => {
      if (draggingCat) {
        const rect = map.getContainer().getBoundingClientRect();
        if (e.clientX >= rect.left && e.clientX <= rect.right && e.clientY >= rect.top && e.clientY <= rect.bottom) {
          const latlng = map.containerPointToLatLng([e.clientX - rect.left, e.clientY - rect.top]);
          setPinLocation(latlng);
          setActiveCategory(draggingCat);
          setStep('CONFIRM_LOCATION');
        }
        setDraggingCat(null);
      }
    };
    if (draggingCat) {
      window.addEventListener('pointermove', handleMove);
      window.addEventListener('pointerup', handleUp);
    }
    return () => {
      window.removeEventListener('pointermove', handleMove);
      window.removeEventListener('pointerup', handleUp);
    };
  }, [draggingCat, map, setPinLocation, setActiveCategory, setStep, setDraggingCat]);

  return null;
};

const InteractiveMap = () => {
  const navigate = useNavigate();
  const defaultCenter = [19.107, 72.837]; 
  const [mapInstance, setMapInstance] = useState(null);
  const [loadingLocation, setLoadingLocation] = useState(false);
  const userMarkerRef = useRef(null);
  const activePinRef = useRef(null);

  const [step, setStep] = useState('IDLE');
  const [activeCategory, setActiveCategory] = useState(null);
  const [pinLocation, setPinLocation] = useState(null);
  
  const [draggingCat, setDraggingCat] = useState(null);
  const [dragPos, setDragPos] = useState({ x: 0, y: 0 });

  const [searchQuery, setSearchQuery] = useState('');
  const [isSearching, setIsSearching] = useState(false);
  const [searchResults, setSearchResults] = useState([]);
  const preventSearchRef = useRef(false);

  const [subCategory, setSubCategory] = useState('');
  const [description, setDescription] = useState('');
  const [photo, setPhoto] = useState(null);
  const [reports, setReports] = useState([]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    fetch('/api/complaints')
      .then(res => res.json())
      .then(data => {
        if(Array.isArray(data)) {
          const formatted = data.map(d => ({ ...d, location: { lat: d.latitude, lng: d.longitude } }));
          setReports(formatted);
        }
      })
      .catch(err => console.error('Error fetching complaints:', err));
  }, []);

  useEffect(() => {
    const handleMove = (e) => {
      if (draggingCat) {
        setDragPos({ x: e.clientX, y: e.clientY });
      }
    };
    if (draggingCat) {
      window.addEventListener('pointermove', handleMove);
    }
    return () => window.removeEventListener('pointermove', handleMove);
  }, [draggingCat]);

  useEffect(() => {
    if (preventSearchRef.current) return;
    const timeoutId = setTimeout(async () => {
      if (searchQuery.trim().length > 2) {
        setIsSearching(true);
        try {
          const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}`);
          const data = await res.json();
          setSearchResults(data.slice(0, 5));
        } catch(err) {
          console.error(err);
        } finally {
          setIsSearching(false);
        }
      } else {
        setSearchResults([]);
      }
    }, 600);
    return () => clearTimeout(timeoutId);
  }, [searchQuery]);

  useEffect(() => {
    if (!mapInstance) return;
    if (step !== 'IDLE' && activeCategory) {
      const loc = pinLocation || mapInstance.getCenter();
      
      if (!activePinRef.current) {
        activePinRef.current = L.marker(loc, { 
          icon: getTeardropIcon(activeCategory),
          draggable: step === 'CONFIRM_LOCATION'
        }).addTo(mapInstance);
        activePinRef.current.on('dragend', (e) => setPinLocation(e.target.getLatLng()));
      } else {
        activePinRef.current.setLatLng(loc);
        activePinRef.current.setIcon(getTeardropIcon(activeCategory));
        if (step === 'REPORT_FORM') activePinRef.current.dragging.disable();
        else activePinRef.current.dragging.enable();
      }
      if (!pinLocation) setPinLocation(loc);
    } else {
      if (activePinRef.current) {
        activePinRef.current.remove();
        activePinRef.current = null;
      }
    }
  }, [step, activeCategory, pinLocation, mapInstance]);

  const cancelReport = () => {
    setStep('IDLE'); setActiveCategory(null); setPinLocation(null);
    setSubCategory(''); setDescription(''); setPhoto(null);
  };

  const submitReport = async () => {
    setIsSubmitting(true);
    let imageUrl = null;
    if (photo) {
      const fileName = `${Date.now()}-${photo.name || 'photo.jpg'}`;
      const { data, error } = await supabase.storage.from('complaint_images').upload(fileName, photo);
      if (error) {
        console.error('Image upload failed:', error);
      } else {
        const { data: publicUrlData } = supabase.storage.from('complaint_images').getPublicUrl(fileName);
        imageUrl = publicUrlData.publicUrl;
      }
    }

    const payload = {
      latitude: pinLocation.lat,
      longitude: pinLocation.lng,
      category: subCategory,
      description: description,
      image_url: imageUrl
    };

    try {
      const res = await fetch('/api/complaints', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.error || 'Failed to submit report');
      }
      setReports([...reports, { ...data, category: data.category || activeCategory, location: { lat: data.latitude, lng: data.longitude } }]);
      cancelReport();
    } catch(err) {
      console.error(err);
      alert('Failed to submit report');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLocate = () => {
    setLoadingLocation(true);
    if (!navigator.geolocation) { alert("Geolocation not supported"); setLoadingLocation(false); return; }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const latlng = [pos.coords.latitude, pos.coords.longitude];
        if (!userMarkerRef.current) userMarkerRef.current = L.marker(latlng, { icon: getUserLocationIcon() }).addTo(mapInstance);
        else userMarkerRef.current.setLatLng(latlng);
        mapInstance.flyTo(latlng, 17, { animate: true, duration: 1.5 });
        setLoadingLocation(false);
      },
      (err) => { console.error(err); alert("Could not get your live location."); setLoadingLocation(false); },
      { enableHighAccuracy: false, timeout: 20000, maximumAge: 60000 }
    );
  };

  const handleSelectLocation = (result) => {
    preventSearchRef.current = true;
    setSearchQuery(result.display_name.split(',')[0]); 
    setSearchResults([]);
    mapInstance.flyTo([parseFloat(result.lat), parseFloat(result.lon)], 16, { animate: true, duration: 1.5 });
  };

  const handleSearchSubmit = async (e) => {
    if (e.key === 'Enter' && searchQuery.trim()) {
      setIsSearching(true);
      try {
        const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}`);
        const data = await res.json();
        if (data && data.length > 0) {
          handleSelectLocation(data[0]);
          e.target.blur();
        } else {
          alert("Location not found. Please try a different search term.");
        }
      } catch (err) { console.error(err); alert("Error searching for location."); }
      setIsSearching(false);
    }
  };

  const [upvotedReports, setUpvotedReports] = useState(() => {
    try {
      return JSON.parse(localStorage.getItem('upvotedReports') || '[]');
    } catch {
      return [];
    }
  });

  const handleUpvote = async (reportId) => {
    if (upvotedReports.includes(reportId)) return;
    
    // Optimistic update
    setUpvotedReports(prev => {
      const next = [...prev, reportId];
      localStorage.setItem('upvotedReports', JSON.stringify(next));
      return next;
    });
    setReports(prev => prev.map(r => r.id === reportId ? { ...r, upvote_count: (r.upvote_count || 0) + 1 } : r));

    try {
      await fetch(`/api/complaints/${reportId}/upvote`, { method: 'POST' });
    } catch (err) {
      console.error('Failed to upvote', err);
    }
  };

  return (
    <div className="relative w-full h-screen bg-slate-50 overflow-hidden text-slate-800 font-sans select-none">
      <style dangerouslySetInnerHTML={{__html: `
        @keyframes dropBounce {
          0% { transform: translateY(-25px) scale(1.05); opacity: 0; }
          50% { transform: translateY(4px) scale(0.98); opacity: 1; }
          100% { transform: translateY(0) scale(1); }
        }
        @keyframes slideUp { from { transform: translateY(100%); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        .hide-scroll::-webkit-scrollbar { width: 5px; }
        .hide-scroll::-webkit-scrollbar-track { background: transparent; }
        .hide-scroll::-webkit-scrollbar-thumb { background: #CBD5E1; border-radius: 10px; }
      `}} />
      
      <MapContainer 
        center={defaultCenter} 
        zoom={15} 
        style={{ height: '100%', width: '100%', zIndex: 0, filter: 'brightness(0.98) contrast(1.02)' }} 
        zoomControl={false}
        attributionControl={false}
      >
        <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" maxZoom={19} />
        <MapController 
          step={step} pinLocation={pinLocation} setPinLocation={setPinLocation} setMapInstance={setMapInstance} 
          draggingCat={draggingCat} setDraggingCat={setDraggingCat} setActiveCategory={setActiveCategory} setStep={setStep}
        />
        {reports.map((report, idx) => (
          <Marker key={report.id || idx} position={report.location} icon={getTeardropIcon(report.category)}>
            <Popup className="custom-popup" closeButton={false}>
              <div className="p-1 min-w-[180px]">
                <div className="flex justify-between items-start mb-2">
                  <h3 className="font-bold text-slate-800 text-[14px]">{report.category}</h3>
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                    report.status === 'resolved' ? 'bg-emerald-100 text-emerald-700' :
                    report.status === 'in_progress' ? 'bg-amber-100 text-amber-700' :
                    'bg-slate-100 text-slate-600'
                  }`}>
                    {report.status || 'Pending'}
                  </span>
                </div>
                {report.description && (
                  <p className="text-slate-600 text-[12px] mb-3 line-clamp-2 leading-relaxed">
                    {report.description}
                  </p>
                )}
                
                <div className="flex items-center justify-between border-t border-slate-100 pt-3 mt-1">
                  <div className="text-[11px] text-slate-500 font-medium flex items-center gap-1">
                    <svg className="w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                    Mumbai
                  </div>
                  
                  {report.id && (
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        handleUpvote(report.id);
                      }}
                      disabled={upvotedReports.includes(report.id)}
                      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full transition-all text-[12px] font-bold ${
                        upvotedReports.includes(report.id) 
                          ? 'bg-rose-50 text-rose-500 cursor-default' 
                          : 'bg-white border border-slate-200 text-slate-600 hover:bg-rose-50 hover:border-rose-200 hover:text-rose-500 active:scale-95 cursor-pointer shadow-sm'
                      }`}
                    >
                      <svg className={`w-4 h-4 ${upvotedReports.includes(report.id) ? 'fill-current' : 'fill-none'}`} stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" /></svg>
                      {report.upvote_count || 0}
                    </button>
                  )}
                </div>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
      
      {draggingCat && (
        <div 
          className="fixed z-[9999] pointer-events-none drop-shadow-2xl scale-125 transition-transform"
          style={{ left: dragPos.x - 28, top: dragPos.y - 50 }}
          dangerouslySetInnerHTML={{ __html: getTeardropHTML(draggingCat, true) }}
        />
      )}

      {/* TOP BAR */}
      <div className="absolute top-[12px] left-[16px] right-[16px] z-[1000] flex gap-3 pointer-events-auto">
        <button onClick={() => navigate(-1)} className="w-[54px] h-[54px] shrink-0 bg-white/90 backdrop-blur-xl rounded-full shadow-[0_8px_20px_rgba(0,0,0,0.12)] border border-white/80 flex items-center justify-center focus:outline-none hover:bg-white active:scale-95 transition-all">
          <svg className="w-[24px] h-[24px] text-slate-700" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M10 19l-7-7m0 0l7-7m-7 7h18" /></svg>
        </button>
        
        <div className="flex-1 relative">
          <div className="h-[54px] bg-white/90 backdrop-blur-xl rounded-[27px] shadow-[0_8px_20px_rgba(0,0,0,0.12)] border border-white/80 flex items-center px-5 overflow-hidden relative z-[1001] focus-within:ring-2 focus-within:ring-[#00C853]/40 transition-all">
            <svg className="w-[20px] h-[20px] text-slate-500 mr-2 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            <input 
              type="text" 
              value={searchQuery}
              onChange={(e) => { preventSearchRef.current = false; setSearchQuery(e.target.value); }}
              onKeyDown={handleSearchSubmit}
              placeholder="Search location..." 
              className="bg-transparent border-none outline-none w-full text-slate-800 placeholder-slate-400 text-[15px] font-semibold h-full pr-8" 
            />
            {isSearching ? (
              <svg className="animate-spin h-5 w-5 text-slate-400 absolute right-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            ) : searchQuery && (
              <button onClick={() => { preventSearchRef.current = true; setSearchQuery(''); setSearchResults([]); }} className="absolute right-4 text-slate-400 hover:text-slate-600 focus:outline-none bg-slate-100/50 rounded-full p-1 transition-colors">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            )}
          </div>

          {/* Suggestions Dropdown */}
          {searchResults.length > 0 && (
            <div className="absolute top-[64px] left-0 right-0 bg-white/95 backdrop-blur-2xl rounded-[24px] shadow-[0_16px_40px_rgba(0,0,0,0.15)] p-2 max-h-[280px] overflow-y-auto z-[1000] border border-white/80 hide-scroll animate-[fadeIn_0.2s_ease-out]">
              {searchResults.map((result, idx) => (
                <div 
                  key={idx}
                  onClick={() => handleSelectLocation(result)}
                  className="flex items-center gap-3.5 p-3.5 hover:bg-slate-50 cursor-pointer border-b border-slate-100 last:border-0 rounded-xl transition-colors active:bg-slate-100"
                >
                   <div className="w-[38px] h-[38px] rounded-full bg-blue-50 flex items-center justify-center shrink-0 text-blue-500 shadow-sm border border-blue-100/50">
                      <svg className="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                   </div>
                   <span className="text-[14px] font-semibold text-slate-700 leading-snug">
                      {result.display_name}
                   </span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* STATE: IDLE */}
      {step === 'IDLE' && (
        <>
          {/* FLOATING CATEGORIES */}
          <div className="absolute top-[90px] left-1/2 -translate-x-1/2 z-[900] flex flex-col items-center w-max max-w-[92vw] pointer-events-auto transition-all duration-300">
            <div className="bg-slate-800/85 backdrop-blur-md text-white text-[12px] font-semibold tracking-wide px-[20px] py-[10px] rounded-full mb-4 shadow-[0_8px_20px_rgba(0,0,0,0.2)] border border-white/10 whitespace-nowrap animate-[pulse_3s_ease-in-out_infinite]">
              Tap or drag a category below to report
            </div>
            
            <div className="bg-white/95 backdrop-blur-xl rounded-[36px] p-2 md:p-3 shadow-[0_20px_50px_rgba(0,0,0,0.12)] border border-white/80 flex justify-between gap-1 sm:gap-4 w-full md:w-auto">
              {Object.entries(CATEGORIES_CONFIG).map(([catName, config]) => (
                <div 
                  key={catName} 
                  onPointerDown={(e) => { e.preventDefault(); setDraggingCat(catName); setDragPos({ x: e.clientX, y: e.clientY }); }}
                  className="group flex flex-col items-center gap-[8px] cursor-grab touch-none w-[70px] p-2 rounded-2xl transition-colors hover:bg-slate-50"
                >
                  <div className="w-[52px] h-[52px] rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(0,0,0,0.1)] transition-transform duration-300 active:scale-95 group-hover:-translate-y-1" style={{ backgroundColor: config.color }}>
                    <div dangerouslySetInnerHTML={{ __html: config.svg }} />
                  </div>
                  <span className="text-[11px] font-bold text-slate-600 leading-tight tracking-tight">{catName}</span>
                </div>
              ))}
            </div>
          </div>

          {/* BOTTOM RIGHT CONTROLS */}
          <div className="absolute bottom-[36px] right-[20px] z-[1000] flex flex-col gap-4 pointer-events-auto">
            <button className="w-[54px] h-[54px] bg-white/95 backdrop-blur-xl rounded-full shadow-[0_10px_25px_rgba(0,0,0,0.12)] border border-white/80 flex items-center justify-center text-slate-700 hover:bg-white active:scale-95 transition-all focus:outline-none">
              <svg className="w-[24px] h-[24px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" /></svg>
            </button>
            <button
              onClick={handleLocate}
              disabled={loadingLocation || !mapInstance}
              className="w-[54px] h-[54px] bg-white/95 backdrop-blur-xl rounded-full shadow-[0_10px_25px_rgba(0,0,0,0.12)] border border-white/80 flex items-center justify-center text-blue-600 hover:bg-white active:scale-95 transition-all focus:outline-none disabled:opacity-75"
            >
              {loadingLocation ? (
                <svg className="animate-spin h-[24px] w-[24px] text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
              ) : (
                <svg className="w-[24px] h-[24px]" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="5"></circle>
                  <line x1="12" y1="2" x2="12" y2="6"></line>
                  <line x1="12" y1="18" x2="12" y2="22"></line>
                  <line x1="2" y1="12" x2="6" y2="12"></line>
                  <line x1="18" y1="12" x2="22" y2="12"></line>
                </svg>
              )}
            </button>
          </div>
        </>
      )}

      {/* STATE: CONFIRM LOCATION */}
      {step === 'CONFIRM_LOCATION' && (
        <div className="absolute bottom-[36px] left-[20px] right-[20px] z-[1000] bg-white/95 backdrop-blur-2xl rounded-[32px] p-6 shadow-[0_20px_50px_rgba(0,0,0,0.15)] border border-white/80 flex flex-col items-center animate-[slideUp_0.4s_cubic-bezier(0.16,1,0.3,1)] pointer-events-auto">
          <p className="text-slate-500 font-bold text-[14px] uppercase tracking-wider mb-5">Refine Pin Location</p>
          <div className="flex w-full gap-4">
            <button onClick={cancelReport} className="w-[60px] h-[60px] bg-slate-100 text-slate-500 rounded-[20px] flex items-center justify-center shrink-0 hover:bg-slate-200 active:scale-95 transition-all">
              <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" /></svg>
            </button>
            <button onClick={() => setStep('REPORT_FORM')} className="flex-1 bg-[#00C853] text-white rounded-[20px] flex items-center justify-center font-extrabold text-[17px] gap-3 shadow-[0_8px_20px_rgba(0,200,83,0.25)] hover:bg-[#00B34A] hover:shadow-[0_10px_25px_rgba(0,200,83,0.3)] active:scale-95 transition-all">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" /></svg> 
              Confirm Location
            </button>
          </div>
        </div>
      )}

      {/* STATE: REPORT FORM (Bottom Sheet) */}
      {step === 'REPORT_FORM' && (
        <div className="absolute inset-0 z-[2000] bg-slate-900/40 backdrop-blur-sm flex flex-col justify-end animate-[fadeIn_0.3s_ease-out] pointer-events-auto">
          <div className="bg-white w-full rounded-t-[40px] p-7 pb-10 shadow-[0_-10px_40px_rgba(0,0,0,0.1)] flex flex-col relative animate-[slideUp_0.4s_cubic-bezier(0.16,1,0.3,1)]">
            
            {/* Drag Handle */}
            <div className="w-12 h-1.5 bg-slate-200 rounded-full mx-auto mb-7"></div>
            
            {/* Header */}
            <div className="flex justify-between items-start mb-7">
              <div className="flex gap-4 items-center">
                <div className="w-[52px] h-[52px] rounded-2xl flex items-center justify-center shadow-sm" style={{ backgroundColor: CATEGORIES_CONFIG[activeCategory].lightBg, color: CATEGORIES_CONFIG[activeCategory].color }}>
                  <div dangerouslySetInnerHTML={{ __html: CATEGORIES_CONFIG[activeCategory].svg }} />
                </div>
                <div>
                  <h2 className="text-[20px] font-extrabold text-slate-800 leading-tight">Report {activeCategory} <br/>Issue</h2>
                  {pinLocation && (
                    <p className="text-[13px] text-slate-400 font-semibold mt-1 flex items-center gap-1">
                      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                      {pinLocation.lat.toFixed(5)}, {pinLocation.lng.toFixed(5)}
                    </p>
                  )}
                </div>
              </div>
              <button onClick={cancelReport} className="w-10 h-10 bg-slate-100 text-slate-500 rounded-full flex items-center justify-center hover:bg-slate-200 transition-colors">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            {/* Dropdown */}
            <div className="relative mb-5">
              <select 
                value={subCategory}
                onChange={(e) => setSubCategory(e.target.value)}
                className={
                  "w-full border-2 bg-slate-50 hover:bg-slate-100 focus:bg-white rounded-[20px] p-[18px] text-slate-700 font-bold appearance-none outline-none transition-all " + 
                  (subCategory ? "border-[#00C853] shadow-[0_0_0_4px_rgba(0,200,83,0.1)]" : "border-transparent focus:border-[#00C853] focus:shadow-[0_0_0_4px_rgba(0,200,83,0.1)]")
                }
              >
                <option value="" disabled>Select a Subcategory</option>
                {CATEGORIES_CONFIG[activeCategory].subcategories.map(sub => (
                  <option key={sub} value={sub}>{sub}</option>
                ))}
              </select>
              <svg className="w-5 h-5 absolute right-5 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M19 9l-7 7-7-7" /></svg>
            </div>

            {/* Textarea */}
            <div className="relative mb-5">
              <textarea 
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full border-2 border-transparent bg-slate-50 hover:bg-slate-100 focus:bg-white focus:border-[#00C853] focus:shadow-[0_0_0_4px_rgba(0,200,83,0.1)] rounded-[20px] p-[18px] text-slate-700 outline-none min-h-[120px] resize-none font-semibold transition-all" 
                placeholder="Provide additional details..." 
                maxLength={300}
              ></textarea>
              <span className="absolute bottom-5 right-5 text-[12px] font-bold text-slate-400">{description.length}/300</span>
            </div>

            {/* Add Photo Button (Live Camera Only) */}
            <label className="w-full border-2 border-dashed border-slate-200 bg-slate-50/50 rounded-[20px] p-[18px] mb-8 flex items-center justify-center gap-2 text-slate-500 font-extrabold cursor-pointer hover:bg-slate-50 transition-colors">
              {photo ? (
                <span className="text-[#00C853] flex items-center gap-2">
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" /></svg>
                  Photo Captured
                </span>
              ) : (
                <>
                  <svg className="w-[22px] h-[22px]" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                  Click Live Photo (Optional)
                </>
              )}
              <input type="file" accept="image/*" capture="environment" className="hidden" onChange={(e) => setPhoto(e.target.files[0])} />
            </label>
            
            {/* Actions */}
            <div className="flex gap-4">
              <button onClick={cancelReport} className="w-[120px] py-[18px] bg-slate-100 text-slate-600 font-extrabold rounded-[20px] hover:bg-slate-200 active:scale-95 transition-all">
                Cancel
              </button>
              <button 
                onClick={submitReport}
                disabled={!subCategory || isSubmitting}
                className={
                  "flex-1 py-[18px] font-extrabold rounded-[20px] transition-all " +
                  (subCategory ? "bg-[#00C853] text-white shadow-[0_8px_20px_rgba(0,200,83,0.25)] hover:bg-[#00B34A] active:scale-95" : "bg-slate-100 text-slate-400")
                }
              >
                {isSubmitting ? "Submitting..." : "Submit Report"}
              </button>
            </div>

          </div>
        </div>
      )}
    </div>
  );
};

export default InteractiveMap;
