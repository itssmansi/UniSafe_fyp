import React, { useEffect, useState, useMemo, useRef } from 'react';

import HeatmapHeader from '../components/heatmap/HeatmapHeader';
import HeatmapFilters from '../components/heatmap/HeatmapFilters';
import HeatmapLegend from '../components/heatmap/HeatmapLegend';
import HotspotCard from '../components/heatmap/HotspotCard';
import HotspotDetails from '../components/heatmap/HotspotDetails';
import { ActiveHotspotsStat, HighRiskAreasStat, ClusteredComplaintsStat } from '../components/heatmap/HeatmapStats';
import { fetchHeatmapData } from '../services/heatmapService';

export default function Heatmap() {
  const [zones, setZones] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Filters state
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [selectedSeverity, setSelectedSeverity] = useState('All');

  // Selected hotspot for details & map focus
  const [selectedZone, setSelectedZone] = useState(null);

  // Map DOM Ref and Leaflet Instance Refs
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const circlesLayerRef = useRef([]);

  // Default Map Center: Mumbai
  const defaultCenter = [19.0760, 72.8777];

  // 1. Fetch heatmap data from backend API
  useEffect(() => {
    let isMounted = true;
    setLoading(true);
    setError(null);

    fetchHeatmapData()
      .then((data) => {
        if (isMounted) {
          setZones(data || []);
          setLoading(false);
        }
      })
      .catch((err) => {
        if (isMounted) {
          setError(err.message || 'Failed to load heatmap data from server.');
          setLoading(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, []);

  // 2. Initialize Leaflet Map instance LOCKED to public OpenStreetMap tiles
  useEffect(() => {
    if (!mapContainerRef.current) return;
    if (mapInstanceRef.current) return; // Prevent double initialization

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

    // LOCKED IMPLEMENTATION: Public OpenStreetMap tile layer (100% free, public, ZERO API key required)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
    }).addTo(map);

    mapInstanceRef.current = map;

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  // Extract unique categories dynamically from API zones
  const categories = useMemo(() => {
    const set = new Set();
    zones.forEach((z) => {
      if (z.zone_type) set.add(z.zone_type);
    });
    return Array.from(set).sort();
  }, [zones]);

  // Filter & Sort zones (HIGH severity first)
  const filteredZones = useMemo(() => {
    let list = [...zones];

    if (selectedCategory !== 'All') {
      list = list.filter((z) => z.zone_type?.toLowerCase() === selectedCategory.toLowerCase());
    }

    if (selectedSeverity !== 'All') {
      list = list.filter((z) => z.severity === selectedSeverity);
    }

    // Sort: HIGH > MEDIUM > LOW
    const severityOrder = { HIGH: 1, MEDIUM: 2, LOW: 3 };
    list.sort((a, b) => (severityOrder[a.severity] || 4) - (severityOrder[b.severity] || 4));

    return list;
  }, [zones, selectedCategory, selectedSeverity]);

  // Helper for Severity Color Lookup
  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'LOW':
        return '#10B981';
      case 'MEDIUM':
        return '#D97706';
      case 'HIGH':
      default:
        return '#DC2626';
    }
  };

  // 3. Render Concentric Layered Radial Heat Circles on Leaflet Map
  useEffect(() => {
    const map = mapInstanceRef.current;
    const L = window.L;
    if (!map || !L) return;

    // Clear previous circle layers
    circlesLayerRef.current.forEach((layer) => map.removeLayer(layer));
    circlesLayerRef.current = [];

    filteredZones.forEach((zone) => {
      if (!zone.latitude || !zone.longitude) return;

      const color = getSeverityColor(zone.severity);
      const isSelected = selectedZone?.id === zone.id;
      const baseRadius = zone.radius_meters || 150;
      const center = [zone.latitude, zone.longitude];

      // Layer 1: Outer Fading Ring (100% radius)
      const outerCircle = L.circle(center, {
        radius: baseRadius,
        color: isSelected ? '#0B192C' : color,
        fillColor: color,
        fillOpacity: isSelected ? 0.25 : 0.14,
        weight: isSelected ? 2.5 : 1,
      }).addTo(map);

      // Layer 2: Mid-Outer Ring (72% radius)
      const midOuterCircle = L.circle(center, {
        radius: baseRadius * 0.72,
        color: color,
        fillColor: color,
        fillOpacity: isSelected ? 0.40 : 0.24,
        weight: 0,
      }).addTo(map);

      // Layer 3: Mid-Inner Ring (45% radius)
      const midInnerCircle = L.circle(center, {
        radius: baseRadius * 0.45,
        color: color,
        fillColor: color,
        fillOpacity: isSelected ? 0.60 : 0.40,
        weight: 0,
      }).addTo(map);

      // Layer 4: Concentrated Core Ring (20% radius)
      const coreCircle = L.circle(center, {
        radius: baseRadius * 0.20,
        color: color,
        fillColor: color,
        fillOpacity: isSelected ? 0.90 : 0.70,
        weight: 0,
      }).addTo(map);

      // Popup Content
      const popupContent = `
        <div style="font-family: sans-serif; font-size: 12px; color: #152937; min-width: 150px;">
          <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #f3f4f6; padding-bottom: 4px; margin-bottom: 4px;">
            <strong style="text-transform: capitalize; font-size: 13px;">${zone.zone_type} Zone</strong>
            <span style="background-color: ${color}; color: white; padding: 2px 6px; border-radius: 4px; font-weight: bold; font-size: 10px;">${zone.severity}</span>
          </div>
          <p style="margin: 4px 0;"><strong>${zone.complaint_count}</strong> complaints reported</p>
          <p style="margin: 4px 0;">Radius: <strong>${zone.radius_meters}m</strong></p>
          ${zone.risk_score !== undefined ? `<p style="margin-top: 4px; font-weight: bold; color: #0B192C;">Risk Score: ${zone.risk_score} / 100</p>` : ''}
        </div>
      `;

      outerCircle.bindPopup(popupContent);

      // Click event handlers
      const handleZoneClick = () => handleSelectZone(zone);
      outerCircle.on('click', handleZoneClick);
      midOuterCircle.on('click', handleZoneClick);
      midInnerCircle.on('click', handleZoneClick);
      coreCircle.on('click', handleZoneClick);

      // Automatically open popup if selected
      if (isSelected) {
        outerCircle.openPopup();
      }

      circlesLayerRef.current.push(outerCircle, midOuterCircle, midInnerCircle, coreCircle);
    });
  }, [filteredZones, selectedZone]);

  // Handle hotspot selection from card or circle click
  const handleSelectZone = (zone) => {
    setSelectedZone(zone);

    const map = mapInstanceRef.current;
    if (map && zone.latitude && zone.longitude) {
      map.flyTo([zone.latitude, zone.longitude], 14, { duration: 1.2 });
    }
  };

  const handleClearFilters = () => {
    setSelectedCategory('All');
    setSelectedSeverity('All');
    setSelectedZone(null);

    const map = mapInstanceRef.current;
    if (map) {
      map.flyTo(defaultCenter, 12, { duration: 1.0 });
    }
  };

  // Metrics data
  const totalHotspots = filteredZones.length;
  const totalComplaints = filteredZones.reduce((acc, z) => acc + (z.complaint_count || 0), 0);
  const highRiskCount = filteredZones.filter((z) => z.severity === 'HIGH').length;

  return (
    <div className="min-h-screen w-full bg-[#F9FAFB] font-sans flex flex-col select-none overflow-x-hidden">
      {/* Header matching the Kanban board */}
      <HeatmapHeader />

      {/* Dashboard Layout */}
      <div className="flex flex-col lg:flex-row gap-4 lg:gap-6 w-full flex-1 max-w-7xl mx-auto px-4 md:px-8 pb-8 items-start">
        
        {/* LEFT RAIL: Scrollable stats, filters, and list */}
        <div className="w-full lg:w-[320px] flex flex-col gap-4 lg:overflow-y-auto lg:h-[calc(100vh-120px)] custom-scrollbar pr-1 shrink-0">
          <HighRiskAreasStat count={highRiskCount} />
          <ClusteredComplaintsStat count={totalComplaints} />
          <ActiveHotspotsStat count={totalHotspots} />
          
          <HeatmapFilters
            categories={categories}
            selectedCategory={selectedCategory}
            setSelectedCategory={setSelectedCategory}
            selectedSeverity={selectedSeverity}
            setSelectedSeverity={setSelectedSeverity}
            onClearFilters={handleClearFilters}
          />

          <div className="bg-white border border-gray-200 rounded-[16px] p-5 shadow-sm space-y-3.5 flex-1 flex flex-col min-h-[300px]">
            <div className="flex items-center justify-between pb-2 border-b border-gray-100">
              <span className="text-[11px] font-bold text-[#64748B] uppercase tracking-wider block">
                ACTIVE HOTSPOTS
              </span>
              <span className="text-[11px] font-bold text-gray-400">
                {totalHotspots} areas
              </span>
            </div>

            {filteredZones.length === 0 ? (
              <div className="py-8 text-center text-gray-400 text-xs flex-1">
                <p className="font-semibold text-gray-500">No Hotspots Found</p>
                <button
                  onClick={handleClearFilters}
                  className="mt-2 text-[11px] text-[#0B192C] font-bold underline cursor-pointer"
                >
                  Reset Filters
                </button>
              </div>
            ) : (
              <div className="space-y-3.5 flex-1 overflow-y-auto pr-1">
                {filteredZones.map((zone) => (
                  <HotspotCard
                    key={zone.id}
                    zone={zone}
                    isSelected={selectedZone?.id === zone.id}
                    onSelect={handleSelectZone}
                  />
                ))}
              </div>
            )}
          </div>
        </div>

        {/* RIGHT COLUMN: Map and Details */}
        <div className="flex-1 w-full flex flex-col gap-4 lg:h-[calc(100vh-120px)]">
          {/* Map Centerpiece */}
          <div className="relative flex-1 bg-white border border-gray-200 rounded-[16px] overflow-hidden shadow-sm min-h-[400px]">
            {loading ? (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/80 z-20">
                <div className="w-8 h-8 border-3 border-[#0B192C] border-t-transparent rounded-full animate-spin"></div>
                <p className="mt-3 text-xs font-semibold text-[#0B192C]">
                  Loading Civic Risk Heatmap...
                </p>
              </div>
            ) : error ? (
              <div className="absolute inset-0 flex flex-col items-center justify-center p-6 text-center bg-white z-20">
                <div className="w-10 h-10 rounded-full bg-red-50 text-[#DC2626] flex items-center justify-center font-bold mb-2">
                  !
                </div>
                <h3 className="text-sm font-bold text-[#152937]">Unable to Load Heatmap</h3>
                <p className="text-xs text-gray-500 mt-1 max-w-sm">{error}</p>
                <button
                  onClick={() => window.location.reload()}
                  className="mt-4 px-4 py-1.5 bg-[#0B192C] text-white text-xs font-semibold rounded-lg hover:bg-black transition cursor-pointer"
                >
                  Retry Connection
                </button>
              </div>
            ) : null}

            {/* Floating Legend */}
            <div className="absolute bottom-4 left-4 z-[1000] hidden sm:block max-w-xs pointer-events-auto">
              <HeatmapLegend />
            </div>

            {/* Leaflet Map DOM Element Container */}
            <div ref={mapContainerRef} className="w-full h-full z-0" style={{ background: '#f8f9fa' }} />
          </div>

          {/* Selected Hotspot Details */}
          {selectedZone && (
            <div className="w-full shrink-0">
              <HotspotDetails
                zone={selectedZone}
                onClose={() => setSelectedZone(null)}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
