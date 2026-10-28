import React, { useEffect, useState, useMemo, useRef } from 'react';
import HeatmapHeader from '../components/heatmap/HeatmapHeader';
import HeatmapStats from '../components/heatmap/HeatmapStats';
import HeatmapFilters from '../components/heatmap/HeatmapFilters';
import HeatmapFloatingLayerCard from '../components/heatmap/HeatmapFloatingLayerCard';
import HeatmapTopRightDock from '../components/heatmap/HeatmapTopRightDock';
import HeatmapFloatingLegend from '../components/heatmap/HeatmapFloatingLegend';
import MumbaiViewButton from '../components/heatmap/MumbaiViewButton';
import HotspotDetails from '../components/heatmap/HotspotDetails';
import { fetchHeatmapData } from '../services/heatmapService';
import { getAuthorityProfile } from '../services/authorityService';

export default function Heatmap({ authority: propAuthority = null, isEmbedded = false }) {
  const [authority, setAuthority] = useState(propAuthority);
  const [zones, setZones] = useState([]);
  const [categoryHierarchy, setCategoryHierarchy] = useState({
    totalCount: 0,
    mainCategories: {},
    subCategoriesByMain: {},
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Department identification
  const department = authority?.department || null;
  const isPolice = department?.toLowerCase().includes('police');
  const isBMC =
    department?.toLowerCase().includes('bmc') ||
    department?.toLowerCase().includes('municipal');

  // Filter States matching reference design
  const [selectedCategory, setSelectedCategory] = useState(
    isPolice ? 'Safety' : 'Infrastructure'
  );
  const [selectedSubCategory, setSelectedSubCategory] = useState('All');
  const [activeMode, setActiveMode] = useState('hybrid'); // 'hybrid' | 'heatmap' | 'hotspots'
  const [selectedSeverity, setSelectedSeverity] = useState('All');
  const [timeRange, setTimeRange] = useState('all');
  const [selectedJurisdiction, setSelectedJurisdiction] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [isLayerExpanded, setIsLayerExpanded] = useState(true);

  // Selected hotspot for details & map focus
  const [selectedZone, setSelectedZone] = useState(null);

  // Map DOM Ref and Leaflet Instance Refs
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const mapLayersRef = useRef([]);

  // Default Map Center: Mumbai
  const defaultCenter = [19.076, 72.8777];

  // Resolve authority profile if not provided via props
  useEffect(() => {
    if (propAuthority) {
      setAuthority(propAuthority);
      return;
    }
    const cached = localStorage.getItem('unisafe_authority');
    if (cached) {
      try {
        setAuthority(JSON.parse(cached));
      } catch (_) {}
    } else {
      getAuthorityProfile().then((prof) => {
        if (prof) setAuthority(prof);
      });
    }
  }, [propAuthority]);

  // Sync default category when department is known
  useEffect(() => {
    if (isPolice && selectedCategory === 'Infrastructure') {
      setSelectedCategory('Safety');
    }
  }, [isPolice]);

  // 1. Fetch heatmap data from Supabase
  useEffect(() => {
    let isMounted = true;
    setLoading(true);
    setError(null);

    fetchHeatmapData({
      authority,
      role: 'authority',
      timeRange,
      jurisdiction: selectedJurisdiction !== 'All' ? selectedJurisdiction : null,
    })
      .then((data) => {
        if (isMounted) {
          setZones(data || []);
          if (data?.categoryHierarchy) {
            setCategoryHierarchy(data.categoryHierarchy);
          }
          setLoading(false);
        }
      })
      .catch((err) => {
        if (isMounted) {
          setError(err.message || 'Failed to load heatmap data from Supabase.');
          setLoading(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, [authority, timeRange, selectedJurisdiction]);

  // 2. Initialize Leaflet Map instance
  useEffect(() => {
    if (!mapContainerRef.current) return;
    if (mapInstanceRef.current) return;

    const L = window.L;
    if (!L) {
      console.warn('Leaflet JS is not loaded yet.');
      return;
    }

    const map = L.map(mapContainerRef.current, {
      center: defaultCenter,
      zoom: 12,
      zoomControl: true,
    });

    // Public OpenStreetMap tile layer
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map);

    mapInstanceRef.current = map;

    // Handle container resize & ensure full render
    const handleResize = () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.invalidateSize();
      }
    };
    window.addEventListener('resize', handleResize);
    const timer = setTimeout(handleResize, 300);

    return () => {
      window.removeEventListener('resize', handleResize);
      clearTimeout(timer);
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  // Filter zones according to selected category, sub-category, severity, and search
  const filteredZones = useMemo(() => {
    let list = [...zones];

    // Filter by Main Category
    if (selectedCategory !== 'All') {
      list = list.filter((z) => {
        const main = (z.main_category || z.zone_type || '').toLowerCase();
        return (
          main.includes(selectedCategory.toLowerCase()) ||
          selectedCategory.toLowerCase().includes(main)
        );
      });
    }

    // Filter by Sub-Category
    if (selectedSubCategory !== 'All') {
      list = list.filter((z) => {
        const sub = (z.sub_category || '').toLowerCase();
        return (
          sub.includes(selectedSubCategory.toLowerCase()) ||
          selectedSubCategory.toLowerCase().includes(sub)
        );
      });
    }

    // Filter by Severity
    if (selectedSeverity !== 'All') {
      list = list.filter((z) => z.severity === selectedSeverity);
    }

    // Filter by Search Query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      list = list.filter((z) => {
        const matchesType = (z.zone_type || '').toLowerCase().includes(q);
        const matchesSub = (z.sub_category || '').toLowerCase().includes(q);
        const matchesWard = (z.jurisdiction || '').toLowerCase().includes(q);
        const matchesComplaints = (z.complaints || []).some(
          (c) =>
            (c.title || '').toLowerCase().includes(q) ||
            (c.address || '').toLowerCase().includes(q)
        );
        return matchesType || matchesSub || matchesWard || matchesComplaints;
      });
    }

    return list;
  }, [
    zones,
    selectedCategory,
    selectedSubCategory,
    selectedSeverity,
    searchQuery,
  ]);

  // Compute severity counts for the floating legend
  const severityCounts = useMemo(() => {
    const counts = { LOW: 0, MEDIUM: 0, HIGH: 0 };
    filteredZones.forEach((z) => {
      if (counts[z.severity] !== undefined) counts[z.severity]++;
    });
    return counts;
  }, [filteredZones]);

  // Extract unique jurisdictions for the filter popover
  const jurisdictions = useMemo(() => {
    const set = new Set();
    zones.forEach((z) => {
      if (z.jurisdiction) set.add(z.jurisdiction);
    });
    return Array.from(set).sort();
  }, [zones]);

  // 3. Render Concentric Radial Circles & Cluster Count Badges
  useEffect(() => {
    const map = mapInstanceRef.current;
    const L = window.L;
    if (!map || !L) return;

    // Clear previous map layers
    mapLayersRef.current.forEach((layer) => map.removeLayer(layer));
    mapLayersRef.current = [];

    filteredZones.forEach((zone) => {
      if (!zone.latitude || !zone.longitude) return;

      const isSelected = selectedZone?.id === zone.id;
      const baseRadius = zone.radius_meters || 200;
      const center = [zone.latitude, zone.longitude];

      // ==========================================
      // A. Heatmap Gradient Layer (In 'hybrid' or 'heatmap' mode)
      // Warm amber glow fading into intense crimson core
      // ==========================================
      if (activeMode === 'hybrid' || activeMode === 'heatmap') {
        // Layer 1: Outer Fading Ring (100% radius) - Warm Amber
        const outerCircle = L.circle(center, {
          radius: baseRadius,
          color: isSelected ? '#0F172A' : '#F59E0B',
          fillColor: '#F59E0B',
          fillOpacity: isSelected ? 0.30 : 0.16,
          weight: isSelected ? 2 : 0,
        }).addTo(map);

        // Layer 2: Mid-Outer Ring (72% radius) - Warm Orange
        const midOuterCircle = L.circle(center, {
          radius: baseRadius * 0.72,
          color: '#EA580C',
          fillColor: '#EA580C',
          fillOpacity: isSelected ? 0.45 : 0.30,
          weight: 0,
        }).addTo(map);

        // Layer 3: Mid-Inner Ring (45% radius) - Vivid Crimson
        const midInnerCircle = L.circle(center, {
          radius: baseRadius * 0.45,
          color: '#DC2626',
          fillColor: '#DC2626',
          fillOpacity: isSelected ? 0.70 : 0.52,
          weight: 0,
        }).addTo(map);

        // Layer 4: Concentrated Core Ring (20% radius) - Deep Red / Maroon
        const coreCircle = L.circle(center, {
          radius: baseRadius * 0.20,
          color: '#991B1B',
          fillColor: '#991B1B',
          fillOpacity: isSelected ? 0.95 : 0.82,
          weight: 0,
        }).addTo(map);

        const handleZoneClick = () => handleSelectZone(zone);
        outerCircle.on('click', handleZoneClick);
        midOuterCircle.on('click', handleZoneClick);
        midInnerCircle.on('click', handleZoneClick);
        coreCircle.on('click', handleZoneClick);

        mapLayersRef.current.push(
          outerCircle,
          midOuterCircle,
          midInnerCircle,
          coreCircle
        );
      } else if (activeMode === 'hotspots') {
        // Hotspots Mode: Clean boundary ring
        const boundaryCircle = L.circle(center, {
          radius: baseRadius,
          color: isSelected ? '#0F172A' : '#EF4444',
          fillColor: '#EF4444',
          fillOpacity: 0.10,
          weight: 2,
        }).addTo(map);

        boundaryCircle.on('click', () => handleSelectZone(zone));
        mapLayersRef.current.push(boundaryCircle);
      }

      // ==========================================
      // B. Circular White Count Badge (In 'hybrid' or 'hotspots' mode)
      // Displays the cluster count (e.g., 36, 24, 10, 15) right at center
      // ==========================================
      if (activeMode === 'hybrid' || activeMode === 'hotspots') {
        const markerHtml = `
          <div style="
            background: white;
            color: #0F172A;
            font-weight: 800;
            font-size: 13px;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            width: 32px;
            height: 32px;
            border-radius: 9999px;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 14px rgba(0,0,0,0.22);
            border: 2px solid white;
            cursor: pointer;
            transform: ${isSelected ? 'scale(1.2)' : 'scale(1)'};
            transition: transform 0.15s ease;
          ">
            ${zone.complaint_count}
          </div>
        `;

        const badgeIcon = L.divIcon({
          className: 'custom-hotspot-count-marker',
          html: markerHtml,
          iconSize: [32, 32],
          iconAnchor: [16, 16],
        });

        const countMarker = L.marker(center, { icon: badgeIcon }).addTo(map);
        countMarker.on('click', () => handleSelectZone(zone));
        mapLayersRef.current.push(countMarker);
      }
    });
  }, [filteredZones, selectedZone, activeMode]);

  // Handle hotspot selection & smooth pan
  const handleSelectZone = (zone) => {
    setSelectedZone(zone);
    const map = mapInstanceRef.current;
    if (map && zone.latitude && zone.longitude) {
      map.flyTo([zone.latitude, zone.longitude], 14, { duration: 1.0 });
    }
  };

  // Re-center on Mumbai
  const handleCenterMumbai = () => {
    const map = mapInstanceRef.current;
    if (map) {
      map.flyTo(defaultCenter, 12, { duration: 1.0 });
    }
  };

  // Clear / reset all filters
  const handleResetFilters = () => {
    setSelectedCategory(isPolice ? 'Safety' : 'Infrastructure');
    setSelectedSubCategory('All');
    setSelectedSeverity('All');
    setTimeRange('all');
    setSelectedJurisdiction('All');
    setSearchQuery('');
    setSelectedZone(null);
  };

  return (
    <div className={`w-full bg-[#F8FAFC] flex flex-col font-sans ${isEmbedded ? 'rounded-2xl' : 'min-h-screen'}`}>
      {/* 1. Header with Page Title, Live Indicator, Search Bar & Citizen Portal Button */}
      <HeatmapHeader
        searchQuery={searchQuery}
        setSearchQuery={setSearchQuery}
        onSearchSubmit={(q) => console.log('Search submit:', q)}
        authority={authority}
        isEmbedded={isEmbedded}
      />

      {/* 2. Main 2-Column Dashboard Layout */}
      <div className="flex-1 max-w-[1600px] w-full mx-auto p-4 sm:p-6 flex flex-col lg:flex-row gap-5">
        {/* Left Column: Summary Stat Cards + Filter Controls */}
        <div className="w-full lg:w-[320px] xl:w-[340px] shrink-0 space-y-4">
          {/* Summary Stat Cards (High Risk Areas, Clustered Complaints, Active Hotspots) */}
          <HeatmapStats zones={filteredZones} />

          {/* Filter Hotspots Card (Problem Category, Sub-Category, Severity Level) */}
          <HeatmapFilters
            categoryHierarchy={categoryHierarchy}
            selectedCategory={selectedCategory}
            setSelectedCategory={setSelectedCategory}
            selectedSubCategory={selectedSubCategory}
            setSelectedSubCategory={setSelectedSubCategory}
            selectedSeverity={selectedSeverity}
            setSelectedSeverity={setSelectedSeverity}
            onClearFilters={handleResetFilters}
            department={department}
          />
        </div>

        {/* Right Column: Full Interactive Map Area */}
        <div className="flex-1 w-full h-[650px] lg:h-[calc(100vh-140px)] min-h-[620px] relative rounded-[22px] overflow-hidden shadow-xs border border-slate-200/90 bg-white">
          {/* Leaflet Map DOM */}
          <div ref={mapContainerRef} className="w-full h-full z-0" />

          {/* Floating Layer & Sub-Categories Card (Top-Left of map) */}
          <HeatmapFloatingLayerCard
            categoryHierarchy={categoryHierarchy}
            selectedCategory={selectedCategory}
            setSelectedCategory={setSelectedCategory}
            selectedSubCategory={selectedSubCategory}
            setSelectedSubCategory={setSelectedSubCategory}
            department={department}
            isExpanded={isLayerExpanded}
            setIsExpanded={setIsLayerExpanded}
          />

          {/* Floating Mode Dock (Top-Right of map: Hybrid, Heatmap, Hotspots + Settings) */}
          <HeatmapTopRightDock
            activeMode={activeMode}
            setActiveMode={setActiveMode}
            timeRange={timeRange}
            setTimeRange={setTimeRange}
            selectedSeverity={selectedSeverity}
            setSelectedSeverity={setSelectedSeverity}
            selectedJurisdiction={selectedJurisdiction}
            setSelectedJurisdiction={setSelectedJurisdiction}
            jurisdictions={jurisdictions}
            onResetFilters={handleResetFilters}
            department={department}
          />

          {/* Floating Heatmap Legend (Bottom-Left of map: Gradient + Low/Med/High boxes) */}
          <HeatmapFloatingLegend
            selectedCategory={selectedCategory}
            activeMode={activeMode}
            severityCounts={severityCounts}
            department={department}
          />

          {/* Floating "Mumbai View" Button (Bottom-Right of map) */}
          <MumbaiViewButton onCenterMumbai={handleCenterMumbai} />

          {/* Selected Hotspot Details Slide-over Drawer */}
          {selectedZone && (
            <div className="absolute top-16 right-4 sm:right-6 z-[1001] w-80 max-w-[calc(100vw-32px)] shadow-2xl rounded-2xl animate-in fade-in slide-in-from-right-4 duration-200">
              <HotspotDetails
                zone={selectedZone}
                onClose={() => setSelectedZone(null)}
              />
            </div>
          )}

          {/* Loading Overlay */}
          {loading && (
            <div className="absolute inset-0 bg-white/60 backdrop-blur-xs flex items-center justify-center z-[1002]">
              <div className="bg-white px-4 py-3 rounded-2xl shadow-xl border border-slate-100 flex items-center gap-3">
                <span className="w-4 h-4 border-2 border-slate-800 border-t-transparent rounded-full animate-spin" />
                <span className="text-xs font-bold text-slate-800">
                  Loading {isPolice ? 'Police Hotspots' : 'BMC Ward Heatmap'}...
                </span>
              </div>
            </div>
          )}

          {/* Error Notice */}
          {error && (
            <div className="absolute top-20 left-1/2 -translate-x-1/2 z-[1002] bg-rose-50 border border-rose-200 text-rose-800 text-xs font-semibold px-4 py-2 rounded-xl shadow-lg flex items-center gap-2">
              <span>⚠ {error}</span>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
