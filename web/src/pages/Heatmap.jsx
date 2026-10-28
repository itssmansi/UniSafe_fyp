import React, { useEffect, useState, useMemo, useRef, useCallback, Component } from 'react';
import 'leaflet.heat';
import { 
  Compass, 
  Layers, 
  SlidersHorizontal, 
  ShieldAlert, 
  Radio, 
  Building2, 
  Sparkles, 
  Trees, 
  RotateCcw,
  CheckCircle2,
  AlertTriangle,
  Search,
  Filter,
  Maximize2
} from 'lucide-react';

import HeatmapFilters from '../components/heatmap/HeatmapFilters';
import HeatmapLegend from '../components/heatmap/HeatmapLegend';
import HotspotCard from '../components/heatmap/HotspotCard';
import HotspotDetails from '../components/heatmap/HotspotDetails';
import { ActiveHotspotsStat, HighRiskAreasStat, ClusteredComplaintsStat } from '../components/heatmap/HeatmapStats';
import { fetchHeatmapData } from '../services/heatmapService';

// Monkey-patch simpleheat & L.HeatLayer to prevent IndexSizeError when canvas dimension is 0
function patchSimpleHeat() {
  if (typeof window === 'undefined') return;

  if (window.simpleheat && window.simpleheat.prototype && !window.simpleheat._patched) {
    const origDraw = window.simpleheat.prototype.draw;
    window.simpleheat.prototype.draw = function (minOpacity) {
      if (!this._width || !this._height || this._width <= 0 || this._height <= 0) {
        return this;
      }
      try {
        return origDraw.call(this, minOpacity);
      } catch (e) {
        return this;
      }
    };
    window.simpleheat._patched = true;
  }

  if (window.L && window.L.HeatLayer && window.L.HeatLayer.prototype && !window.L.HeatLayer._patched) {
    const origRedraw = window.L.HeatLayer.prototype._redraw;
    window.L.HeatLayer.prototype._redraw = function () {
      if (!this._map) return;
      try {
        const size = this._map.getSize();
        if (!size || size.x <= 0 || size.y <= 0) return;
        return origRedraw.call(this);
      } catch (e) {
        return;
      }
    };
    window.L.HeatLayer._patched = true;
  }
}
patchSimpleHeat();

// Tile Providers for executive visualization (100% Free, NO API KEY, Zero Watermarks)
export const MAP_STYLES = {
  streets: {
    id: 'streets',
    label: 'OpenStreetMap',
    url: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    maxZoom: 19
  },
  satellite: {
    id: 'satellite',
    label: 'Satellite Imagery',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Tiles &copy; Esri',
    maxZoom: 18
  },
  topo: {
    id: 'topo',
    label: 'Topographic',
    url: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '&copy; <a href="https://opentopomap.org">OpenTopoMap</a>',
    maxZoom: 17
  }
};

// Distinct Thermal Gradients & Category Metadata (Official 4 Categories + Subcategories)
export const CATEGORY_CONFIG = {
  all: {
    id: 'all',
    label: 'All Categories',
    themeColor: '#0F172A',
    gradient: {
      0.15: '#3B82F6', // Cobalt Blue
      0.35: '#06B6D4', // Radiant Cyan
      0.55: '#10B981', // Emerald Green
      0.72: '#F59E0B', // Amber Yellow
      0.88: '#F97316', // Hot Orange
      1.00: '#DC2626'  // Blazing Crimson Core
    },
    gradientCss: 'linear-gradient(to right, #3B82F6 0%, #06B6D4 25%, #10B981 50%, #F59E0B 72%, #F97316 88%, #DC2626 100%)',
    subcategories: []
  },
  infrastructure: {
    id: 'infrastructure',
    label: 'Infrastructure',
    themeColor: '#EF4444',
    lightBg: '#FEF2F2',
    gradient: {
      0.15: '#FEF3C7',
      0.35: '#F59E0B',
      0.55: '#EA580C',
      0.75: '#DC2626',
      1.00: '#991B1B'
    },
    gradientCss: 'linear-gradient(to right, #FEF3C7 0%, #F59E0B 30%, #EA580C 60%, #DC2626 85%, #991B1B 100%)',
    subcategories: [
      { id: 'drainage', label: 'Drainage', keywords: ['drainage', 'open drain', 'sewage'] },
      { id: 'water_supply', label: 'Water Supply', keywords: ['water', 'water supply', 'water pipe', 'leakage'] },
      { id: 'roads_potholes', label: 'Roads & Potholes', keywords: ['road', 'potholes', 'road damage', 'prolonged road work'] },
      { id: 'streetlights', label: 'Streetlights', keywords: ['streetlight', 'streetlights', 'nonfunctional street lights'] },
      { id: 'water_logging', label: 'Water Logging', keywords: ['water logging', 'waterlogging'] },
      { id: 'general_infrastructure', label: 'General Infrastructure', keywords: ['infrastructure'] }
    ]
  },
  sanitation: {
    id: 'sanitation',
    label: 'Sanitation',
    themeColor: '#F59E0B',
    lightBg: '#FFFBEB',
    gradient: {
      0.15: '#FEF9C3',
      0.35: '#FDE047',
      0.55: '#F59E0B',
      0.75: '#D97706',
      1.00: '#B45309'
    },
    gradientCss: 'linear-gradient(to right, #FEF9C3 0%, #FDE047 30%, #F59E0B 60%, #D97706 85%, #B45309 100%)',
    subcategories: [
      { id: 'garbage_roads', label: 'Garbage on Roads', keywords: ['garbage scattered on road', 'garbage on road'] },
      { id: 'garbage_bins', label: 'Garbage & Waste Bins', keywords: ['garbage', 'overflowing bins', 'waste bins', 'garbage collection', 'untimely garbage collection / overflowing bins'] },
      { id: 'public_washrooms', label: 'Public Washrooms', keywords: ['public washroom cleanliness', 'washroom', 'toilet'] },
      { id: 'waterfront_dumping', label: 'Waterfront Dumping', keywords: ['garbage dumping near beach/river', 'waterfront dumping', 'beach dumping'] }
    ]
  },
  safety: {
    id: 'safety',
    label: 'Safety',
    themeColor: '#3B82F6',
    lightBg: '#EFF6FF',
    gradient: {
      0.15: '#DBEAFE',
      0.35: '#60A5FA',
      0.55: '#2563EB',
      0.75: '#1D4ED8',
      1.00: '#1E3A8A'
    },
    gradientCss: 'linear-gradient(to right, #DBEAFE 0%, #60A5FA 30%, #2563EB 60%, #1D4ED8 85%, #1E3A8A 100%)',
    subcategories: [
      { id: 'theft_robbery', label: 'Theft & Robbery', keywords: ['theft', 'theft / robbery', 'robbery'] },
      { id: 'women_safety', label: 'Women Safety & Harassment', keywords: ['women safety', 'harassment / eve-teasing', 'eve-teasing', 'harassment'] },
      { id: 'violence_assault', label: 'Assault & Violence', keywords: ['assault / violence', 'assault', 'violence'] },
      { id: 'open_manholes', label: 'Open Manholes', keywords: ['open manholes', 'open manhole'] },
      { id: 'pedestrian_footpath', label: 'Pedestrian Footpaths', keywords: ['non-existent footpath', 'footpath'] },
      { id: 'illegal_parking', label: 'Illegal Parking', keywords: ['illegal parking'] },
      { id: 'stray_animals', label: 'Stray Animal Threat', keywords: ['stray animal threat', 'stray dog', 'stray animal'] },
      { id: 'hazards', label: 'Fire & Electrical Hazards', keywords: ['fire hazard', 'electrical hazard', 'exposed wires', 'hazard'] }
    ]
  },
  greenery: {
    id: 'greenery',
    label: 'Greenery',
    themeColor: '#10B981',
    lightBg: '#ECFDF5',
    gradient: {
      0.15: '#D1FAE5',
      0.35: '#34D399',
      0.55: '#10B981',
      0.75: '#059669',
      1.00: '#064E3B'
    },
    gradientCss: 'linear-gradient(to right, #D1FAE5 0%, #34D399 30%, #10B981 60%, #059669 85%, #064E3B 100%)',
    subcategories: [
      { id: 'landscape_maintenance', label: 'Landscape Maintenance', keywords: ['poor landscape maintenance', 'landscape maintenance', 'greenery', 'overgrown vegetation', 'watering required for plants', 'trees', 'illegal tree cutting', 'need tree plantation'] },
      { id: 'green_space_dumping', label: 'Dumping in Green Areas', keywords: ['waste dumping in green area', 'encroachment on green spaces'] }
    ]
  }
};

export function classifyCategory(raw) {
  if (!raw) {
    return {
      parentId: 'infrastructure',
      subId: 'general_infrastructure',
      parentLabel: 'Infrastructure',
      subLabel: 'General Infrastructure'
    };
  }

  const s = String(raw).trim().toLowerCase();

  for (const [parentId, catCfg] of Object.entries(CATEGORY_CONFIG)) {
    if (parentId === 'all') continue;
    for (const sub of catCfg.subcategories || []) {
      for (const kw of sub.keywords) {
        if (s === kw.toLowerCase()) {
          return {
            parentId,
            subId: sub.id,
            parentLabel: catCfg.label,
            subLabel: sub.label
          };
        }
      }
    }
  }

  const allKeywords = [];
  for (const [parentId, catCfg] of Object.entries(CATEGORY_CONFIG)) {
    if (parentId === 'all') continue;
    for (const sub of catCfg.subcategories || []) {
      for (const kw of sub.keywords) {
        allKeywords.push({
          parentId,
          subId: sub.id,
          parentLabel: catCfg.label,
          subLabel: sub.label,
          keyword: kw.toLowerCase()
        });
      }
    }
  }
  allKeywords.sort((a, b) => b.keyword.length - a.keyword.length);

  for (const item of allKeywords) {
    if (s.includes(item.keyword)) {
      return {
        parentId: item.parentId,
        subId: item.subId,
        parentLabel: item.parentLabel,
        subLabel: item.subLabel
      };
    }
  }

  if (s.includes('infra') || s.includes('pothole') || s.includes('road')) {
    return { parentId: 'infrastructure', subId: 'general_infrastructure', parentLabel: 'Infrastructure', subLabel: 'General Infrastructure' };
  }
  if (s.includes('sanit') || s.includes('waste') || s.includes('garbage')) {
    return { parentId: 'sanitation', subId: 'garbage_bins', parentLabel: 'Sanitation', subLabel: 'Garbage & Waste Bins' };
  }
  if (s.includes('safe') || s.includes('crime') || s.includes('police') || s.includes('theft')) {
    return { parentId: 'safety', subId: 'theft_robbery', parentLabel: 'Safety', subLabel: 'Theft & Robbery' };
  }
  if (s.includes('green') || s.includes('park') || s.includes('tree') || s.includes('plant')) {
    return { parentId: 'greenery', subId: 'landscape_maintenance', parentLabel: 'Greenery', subLabel: 'Landscape Maintenance' };
  }

  return {
    parentId: 'infrastructure',
    subId: 'general_infrastructure',
    parentLabel: 'Infrastructure',
    subLabel: 'General Infrastructure'
  };
}

class HeatmapErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  componentDidCatch(error, errorInfo) {
    console.error('Heatmap render error caught:', error, errorInfo);
  }
  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-[500px] w-full bg-slate-50 flex flex-col items-center justify-center p-6 text-center font-sans">
          <div className="w-12 h-12 rounded-2xl bg-rose-50 border border-rose-200 text-rose-600 flex items-center justify-center mb-3">
            <AlertTriangle className="w-6 h-6 stroke-[2]" />
          </div>
          <h2 className="text-base font-bold text-slate-900">Heatmap Loading Notice</h2>
          <p className="text-xs text-slate-500 mt-1 max-w-md">
            {this.state.error?.message || 'A display glitch occurred while rendering the map.'}
          </p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            className="mt-4 px-4 py-2 bg-slate-900 text-white text-xs font-bold rounded-xl hover:bg-black transition cursor-pointer"
          >
            Reload Heatmap
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

function HeatmapContent() {
  const [zones, setZones] = useState([]);
  const [complaints, setComplaints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Filters state
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedSubcategory, setSelectedSubcategory] = useState('all');
  const [selectedSeverity, setSelectedSeverity] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [layerMenuOpen, setLayerMenuOpen] = useState(false);
  const layerMenuRef = useRef(null);

  // Map Tile Style ('streets' | 'satellite' | 'topo') - Default OpenStreetMap (Zero watermarks!)
  const [mapStyle, setMapStyle] = useState('streets');
  const [styleMenuOpen, setStyleMenuOpen] = useState(false);
  const styleMenuRef = useRef(null);

  // Close floating menus when clicking outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (layerMenuRef.current && !layerMenuRef.current.contains(event.target)) {
        setLayerMenuOpen(false);
      }
      if (styleMenuRef.current && !styleMenuRef.current.contains(event.target)) {
        setStyleMenuOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Visualization settings
  const [viewMode, setViewMode] = useState('hybrid'); // 'hybrid' | 'heatmap' | 'epicenters'
  const [heatRadius, setHeatRadius] = useState(38);
  const [heatBlur, setHeatBlur] = useState(24);
  const [heatIntensity, setHeatIntensity] = useState(1.0);
  const [showControls, setShowControls] = useState(false);

  // Selected hotspot for details & focus
  const [selectedZone, setSelectedZone] = useState(null);

  // Leaflet Map & Layer Refs
  const mapContainerRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const tileLayerRef = useRef(null);
  const heatLayerRef = useRef(null);
  const epicentersLayerRef = useRef([]);

  // Default Map Center: Mumbai
  const defaultCenter = [19.0760, 72.8777];

  // 1. Fetch heatmap & complaints data
  useEffect(() => {
    let isMounted = true;
    setLoading(true);
    setError(null);

    const loadData = () => {
      fetchHeatmapData()
        .then((data) => {
          if (!isMounted) return;
          if (data && typeof data === 'object') {
            setZones(data.zones || []);
            setComplaints(data.complaints || []);
          } else if (Array.isArray(data)) {
            setZones(data);
          }
          setLoading(false);
        })
        .catch((err) => {
          if (isMounted) {
            setError(err.message || 'Failed to load heatmap data from server.');
            setLoading(false);
          }
        });
    };

    loadData();
    const intervalId = setInterval(loadData, 20000);

    return () => {
      isMounted = false;
      clearInterval(intervalId);
    };
  }, []);

  // 2. Initialize Leaflet Map Instance LOCKED to OpenStreetMap (NO API Key required, Zero Watermarks)
  useEffect(() => {
    patchSimpleHeat();
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
      zoomControl: false,
    });

    // Zoom controls safely in bottom-right (no collision with top menus)
    L.control.zoom({ position: 'bottomright' }).addTo(map);

    const initialStyle = MAP_STYLES[mapStyle] || MAP_STYLES.streets;
    const tileLayer = L.tileLayer(initialStyle.url, {
      attribution: initialStyle.attribution,
      maxZoom: initialStyle.maxZoom || 19,
    }).addTo(map);

    tileLayerRef.current = tileLayer;
    mapInstanceRef.current = map;

    const timer = setTimeout(() => {
      try {
        map.invalidateSize();
      } catch (e) {}
    }, 200);

    const handleResize = () => {
      try {
        map.invalidateSize();
      } catch (e) {}
    };
    window.addEventListener('resize', handleResize);

    return () => {
      clearTimeout(timer);
      window.removeEventListener('resize', handleResize);
      if (mapInstanceRef.current) {
        mapInstanceRef.current.remove();
        mapInstanceRef.current = null;
      }
    };
  }, []);

  // Dynamic Tile Layer Switcher
  useEffect(() => {
    const map = mapInstanceRef.current;
    const L = window.L;
    if (!map || !L) return;

    const styleCfg = MAP_STYLES[mapStyle] || MAP_STYLES.streets;

    if (tileLayerRef.current) {
      try {
        map.removeLayer(tileLayerRef.current);
      } catch (e) {}
    }

    const newTile = L.tileLayer(styleCfg.url, {
      attribution: styleCfg.attribution,
      maxZoom: styleCfg.maxZoom || 19,
    }).addTo(map);

    tileLayerRef.current = newTile;
  }, [mapStyle]);

  // Complaint counts grouped by parent category and by subcategory
  const { categoryCounts, subcategoryCounts } = useMemo(() => {
    const catCounts = {
      all: complaints.length,
      infrastructure: 0,
      sanitation: 0,
      safety: 0,
      greenery: 0
    };
    const subCounts = {};

    Object.values(CATEGORY_CONFIG).forEach((cfg) => {
      (cfg.subcategories || []).forEach((sub) => {
        subCounts[sub.id] = 0;
      });
    });

    complaints.forEach((c) => {
      const { parentId, subId } = classifyCategory(c.category);
      if (catCounts[parentId] !== undefined) {
        catCounts[parentId] += 1;
      }
      if (subCounts[subId] !== undefined) {
        subCounts[subId] += 1;
      } else {
        subCounts[subId] = 1;
      }
    });

    return { categoryCounts: catCounts, subcategoryCounts: subCounts };
  }, [complaints]);

  // Main 4 Categories filter options + All Categories
  const filterCategoryOptions = useMemo(() => {
    return [
      {
        id: 'all',
        label: 'All Categories',
        themeColor: '#0F172A',
        count: categoryCounts.all || 0
      },
      {
        id: 'infrastructure',
        label: 'Infrastructure',
        themeColor: CATEGORY_CONFIG.infrastructure.themeColor,
        count: categoryCounts.infrastructure || 0
      },
      {
        id: 'sanitation',
        label: 'Sanitation',
        themeColor: CATEGORY_CONFIG.sanitation.themeColor,
        count: categoryCounts.sanitation || 0
      },
      {
        id: 'safety',
        label: 'Safety',
        themeColor: CATEGORY_CONFIG.safety.themeColor,
        count: categoryCounts.safety || 0
      },
      {
        id: 'greenery',
        label: 'Greenery',
        themeColor: CATEGORY_CONFIG.greenery.themeColor,
        count: categoryCounts.greenery || 0
      }
    ];
  }, [categoryCounts]);

  // Subcategories available under currently active category
  const activeSubcategories = useMemo(() => {
    if (selectedCategory === 'all') return [];
    const cfg = CATEGORY_CONFIG[selectedCategory];
    if (!cfg || !cfg.subcategories) return [];

    return cfg.subcategories.map((sub) => ({
      id: sub.id,
      label: sub.label,
      count: subcategoryCounts[sub.id] || 0
    }));
  }, [selectedCategory, subcategoryCounts]);

  const activeCategoryConfig = CATEGORY_CONFIG[selectedCategory] || CATEGORY_CONFIG.all;
  const activeSubcategoryConfig = activeSubcategories.find((s) => s.id === selectedSubcategory);

  // Severity Counts for the filter tabs
  const severityCounts = useMemo(() => {
    return {
      LOW: zones.filter((z) => z.severity === 'LOW').length,
      MEDIUM: zones.filter((z) => z.severity === 'MEDIUM').length,
      HIGH: zones.filter((z) => z.severity === 'HIGH').length
    };
  }, [zones]);

  // Filter zones and complaints by hierarchical category, subcategory, severity, and search
  const filteredZones = useMemo(() => {
    let list = zones.filter((z) => {
      const { parentId, subId, parentLabel, subLabel } = classifyCategory(z.zone_type);
      if (selectedCategory !== 'all' && parentId !== selectedCategory) {
        return false;
      }
      if (selectedSubcategory !== 'all' && subId !== selectedSubcategory) {
        return false;
      }
      if (selectedSeverity !== 'All' && z.severity !== selectedSeverity) {
        return false;
      }
      if (searchQuery && searchQuery.trim().length > 0) {
        const q = searchQuery.toLowerCase().trim();
        const typeMatch = String(z.zone_type || '').toLowerCase().includes(q);
        const subMatch = String(subLabel || '').toLowerCase().includes(q);
        const parentMatch = String(parentLabel || '').toLowerCase().includes(q);
        if (!typeMatch && !subMatch && !parentMatch) return false;
      }
      return true;
    });
    const severityOrder = { HIGH: 1, MEDIUM: 2, LOW: 3 };
    list.sort((a, b) => (severityOrder[a.severity] || 4) - (severityOrder[b.severity] || 4));
    return list;
  }, [zones, selectedCategory, selectedSubcategory, selectedSeverity, searchQuery]);

  const filteredComplaints = useMemo(() => {
    return complaints.filter((c) => {
      const { parentId, subId } = classifyCategory(c.category);
      if (selectedCategory !== 'all' && parentId !== selectedCategory) {
        return false;
      }
      if (selectedSubcategory !== 'all' && subId !== selectedSubcategory) {
        return false;
      }
      return true;
    });
  }, [complaints, selectedCategory, selectedSubcategory]);

  const getSeverityColor = (severity) => {
    switch (severity) {
      case 'LOW':
        return '#059669';
      case 'MEDIUM':
        return '#D97706';
      case 'HIGH':
      default:
        return '#DC2626';
    }
  };

  // 4. Render Professional Canvas Heatmap Layer
  useEffect(() => {
    patchSimpleHeat();
    const map = mapInstanceRef.current;
    const L = window.L;
    if (!map || !L) return;

    try {
      const size = map.getSize();
      if (!size || size.x <= 0 || size.y <= 0) return;
    } catch (e) {
      return;
    }

    if (typeof L.heatLayer !== 'function') return;

    if (viewMode === 'epicenters') {
      if (heatLayerRef.current) {
        try {
          map.removeLayer(heatLayerRef.current);
        } catch (e) {}
        heatLayerRef.current = null;
      }
      return;
    }

    const heatPoints = [];

    filteredComplaints.forEach((c) => {
      const lat = parseFloat(c.latitude);
      const lng = parseFloat(c.longitude);
      if (!isNaN(lat) && !isNaN(lng)) {
        const upvotes = Number(c.upvote_count) || 0;
        const baseWeight = Math.min(0.35 + upvotes * 0.1, 0.9);
        heatPoints.push([lat, lng, baseWeight * heatIntensity]);
      }
    });

    filteredZones.forEach((z) => {
      const lat = parseFloat(z.latitude);
      const lng = parseFloat(z.longitude);
      if (!isNaN(lat) && !isNaN(lng)) {
        let baseWeight = 0.55;
        if (z.severity === 'HIGH') baseWeight = 0.95;
        else if (z.severity === 'MEDIUM') baseWeight = 0.75;
        else baseWeight = 0.45;

        const count = Number(z.complaint_count) || 0;
        if (count >= 10) baseWeight = Math.min(baseWeight + 0.1, 1.0);

        heatPoints.push([lat, lng, baseWeight * heatIntensity]);
      }
    });

    const activeConfig = CATEGORY_CONFIG[selectedCategory] || CATEGORY_CONFIG.all;

    const heatOptions = {
      minOpacity: 0.14,
      maxZoom: 16,
      max: 1.0,
      radius: heatRadius,
      blur: heatBlur,
      gradient: activeConfig.gradient
    };

    try {
      if (heatLayerRef.current) {
        heatLayerRef.current.setLatLngs(heatPoints);
        heatLayerRef.current.setOptions(heatOptions);
        if (typeof heatLayerRef.current._redraw === 'function') {
          heatLayerRef.current._redraw();
        }
      } else if (heatPoints.length > 0) {
        heatLayerRef.current = L.heatLayer(heatPoints, heatOptions).addTo(map);
      }
    } catch (e) {
      console.warn('Thermal heat layer render notice:', e);
    }
  }, [filteredComplaints, filteredZones, viewMode, heatRadius, heatBlur, heatIntensity, selectedCategory, selectedSubcategory]);

  // 5. Render Executive Epicenter Beacons on Map
  useEffect(() => {
    const map = mapInstanceRef.current;
    const L = window.L;
    if (!map || !L) return;

    epicentersLayerRef.current.forEach((layer) => {
      try {
        map.removeLayer(layer);
      } catch (e) {}
    });
    epicentersLayerRef.current = [];

    if (viewMode === 'heatmap') return;

    filteredZones.forEach((zone) => {
      if (!zone.latitude || !zone.longitude) return;

      const { parentId, parentLabel, subLabel } = classifyCategory(zone.zone_type);
      const themeColor = CATEGORY_CONFIG[parentId]?.themeColor || '#0F172A';
      const severityColor = getSeverityColor(zone.severity);
      const isSelected = selectedZone?.id === zone.id;
      const count = Number(zone.complaint_count) || 1;
      const center = [zone.latitude, zone.longitude];

      // Focused catchment area halo when selected
      if (isSelected) {
        const catchmentHalo = L.circle(center, {
          radius: zone.radius_meters || 250,
          color: themeColor,
          weight: 2,
          fillColor: themeColor,
          fillOpacity: 0.14,
        }).addTo(map);
        epicentersLayerRef.current.push(catchmentHalo);
      }

      // High-contrast, executive beacon pin
      const html = `
        <div style="
          position: relative;
          display: flex;
          align-items: center;
          justify-content: center;
          width: ${isSelected ? '32px' : '28px'};
          height: ${isSelected ? '32px' : '28px'};
          background: ${isSelected ? '#0F172A' : severityColor};
          color: #FFFFFF;
          border: 2px solid #FFFFFF;
          border-radius: 9999px;
          box-shadow: ${
            isSelected
              ? '0 0 0 4px rgba(15, 23, 42, 0.35), 0 8px 18px rgba(0,0,0,0.4)'
              : zone.severity === 'HIGH'
              ? '0 0 0 4px rgba(220, 38, 38, 0.28), 0 4px 12px rgba(220, 38, 38, 0.45)'
              : '0 0 0 3px rgba(0,0,0,0.12), 0 2px 8px rgba(0,0,0,0.22)'
          };
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
          font-size: ${count >= 100 ? '9px' : count >= 10 ? '11px' : '12px'};
          font-weight: 900;
          cursor: pointer;
          user-select: none;
          transition: transform 0.15s ease;
        ">
          ${zone.severity === 'HIGH' && !isSelected ? `
            <span style="
              position: absolute;
              inset: -4px;
              border-radius: 9999px;
              background: rgba(220, 38, 38, 0.35);
              animation: ping 2s cubic-bezier(0, 0, 0.2, 1) infinite;
              pointer-events: none;
            "></span>
          ` : ''}
          <span style="position: relative; z-index: 1;">${count}</span>
        </div>
      `;

      const customIcon = L.divIcon({
        html,
        className: 'custom-epicenter-badge',
        iconSize: isSelected ? [32, 32] : [28, 28],
        iconAnchor: isSelected ? [16, 16] : [14, 14],
      });

      const marker = L.marker(center, { icon: customIcon }).addTo(map);

      const popupContent = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 12px; color: #0F172A; min-width: 180px; padding: 2px;">
          <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid #E2E8F0; padding-bottom: 6px; margin-bottom: 6px;">
            <div>
              <strong style="font-size: 13px; font-weight: 800; color: #0F172A;">${subLabel || zone.zone_type}</strong>
              <div style="font-size: 10px; color: #64748B; font-weight: 600;">${parentLabel}</div>
            </div>
            <span style="background-color: ${severityColor}; color: white; padding: 2px 7px; border-radius: 6px; font-weight: 800; font-size: 9px; letter-spacing: 0.5px;">${zone.severity}</span>
          </div>
          <div style="color: #475569; line-height: 1.5; font-size: 11px;">
            <p style="margin: 3px 0;">Reports: <strong style="color: #0F172A; font-family: monospace;">${count}</strong></p>
            <p style="margin: 3px 0;">Catchment: <strong style="color: #0F172A; font-family: monospace;">${zone.radius_meters || 250}m</strong></p>
            ${zone.risk_score !== undefined ? `<p style="margin-top: 4px; font-weight: 700; color: #0F172A;">Risk Score: <span style="font-family: monospace; color: #DC2626;">${zone.risk_score}/100</span></p>` : ''}
          </div>
        </div>
      `;

      marker.bindPopup(popupContent, { className: 'custom-popup' });
      marker.on('click', () => handleSelectZone(zone));

      if (isSelected) {
        marker.openPopup();
      }

      epicentersLayerRef.current.push(marker);
    });
  }, [filteredZones, selectedZone, viewMode, selectedCategory, selectedSubcategory]);

  const handleSelectZone = useCallback((zone) => {
    setSelectedZone(zone);
    const map = mapInstanceRef.current;
    if (map && zone.latitude && zone.longitude) {
      map.flyTo([zone.latitude, zone.longitude], 14, { duration: 1.2 });
    }
  }, []);

  const handleClearFilters = () => {
    setSelectedCategory('all');
    setSelectedSubcategory('all');
    setSelectedSeverity('All');
    setSearchQuery('');
    setSelectedZone(null);

    const map = mapInstanceRef.current;
    if (map) {
      map.flyTo(defaultCenter, 12, { duration: 1.0 });
    }
  };

  const totalHotspots = filteredZones.length;
  const totalComplaints = filteredZones.reduce((acc, z) => acc + (z.complaint_count || 0), 0);
  const highRiskCount = filteredZones.filter((z) => z.severity === 'HIGH').length;

  return (
    <div className="w-full font-sans flex flex-col select-none">
      
      {/* MAIN TWO-COLUMN WORKSPACE (No redundant headers, perfectly aligned with dashboard) */}
      <div className="flex flex-col lg:flex-row gap-4 lg:gap-6 w-full items-start">
        
        {/* LEFT RAIL: STATS, FILTERS, HOTSPOTS LIST */}
        <div className="w-full lg:w-[330px] flex flex-col gap-4 shrink-0">
          <HighRiskAreasStat count={highRiskCount} total={zones.length} />
          <ClusteredComplaintsStat count={totalComplaints} />
          <ActiveHotspotsStat count={totalHotspots} />
          
          <HeatmapFilters
            categories={filterCategoryOptions}
            selectedCategory={selectedCategory}
            setSelectedCategory={setSelectedCategory}
            subcategories={activeSubcategories}
            selectedSubcategory={selectedSubcategory}
            setSelectedSubcategory={setSelectedSubcategory}
            selectedSeverity={selectedSeverity}
            setSelectedSeverity={setSelectedSeverity}
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
            severityCounts={severityCounts}
            onClearFilters={handleClearFilters}
          />

          {/* Active Hotspots Scroll Container */}
          <div className="bg-white border border-slate-200/90 rounded-2xl p-4 sm:p-5 shadow-xs space-y-3 flex flex-col min-h-[320px] max-h-[500px]">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100">
              <span className="text-[11px] font-bold text-slate-500 uppercase tracking-wider block">
                ACTIVE HOTSPOTS
              </span>
              <span className="text-[11px] font-bold font-mono text-slate-400">
                {filteredZones.length} sectors
              </span>
            </div>

            {filteredZones.length === 0 ? (
              <div className="py-12 text-center text-slate-400 text-xs flex-1 flex flex-col items-center justify-center space-y-2">
                <p className="font-semibold text-slate-500">No Hotspots Match Active Filters</p>
                <button
                  type="button"
                  onClick={handleClearFilters}
                  className="inline-flex items-center gap-1 text-[11px] text-blue-600 font-bold hover:underline cursor-pointer"
                >
                  <RotateCcw className="w-3 h-3" />
                  <span>Reset All Filters</span>
                </button>
              </div>
            ) : (
              <div className="space-y-2.5 flex-1 overflow-y-auto pr-1 custom-scrollbar">
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

        {/* RIGHT COLUMN: MAP & HUD CONTROLS */}
        <div className="flex-1 w-full flex flex-col min-h-[580px] h-[640px] lg:h-[calc(100vh-140px)]">
          <div className="relative flex-1 bg-slate-100 border border-slate-200/90 rounded-2xl overflow-hidden shadow-xs min-h-[480px]">
            {loading ? (
              <div className="absolute inset-0 flex flex-col items-center justify-center bg-white/85 z-20 backdrop-blur-xs">
                <div className="w-9 h-9 border-3 border-slate-900 border-t-transparent rounded-full animate-spin"></div>
                <p className="mt-3 text-xs font-bold text-slate-800 tracking-tight">
                  Loading Civic Risk Thermal Map...
                </p>
              </div>
            ) : error ? (
              <div className="absolute inset-0 flex flex-col items-center justify-center p-6 text-center bg-white z-20">
                <div className="w-11 h-11 rounded-2xl bg-rose-50 border border-rose-200 text-rose-600 flex items-center justify-center mb-2">
                  <AlertTriangle className="w-5 h-5 stroke-[2.2]" />
                </div>
                <h3 className="text-sm font-bold text-slate-900">Unable to Load Heatmap</h3>
                <p className="text-xs text-slate-500 mt-1 max-w-sm">{error}</p>
                <button
                  onClick={() => window.location.reload()}
                  className="mt-4 px-4 py-1.5 bg-slate-900 text-white text-xs font-bold rounded-xl hover:bg-black transition cursor-pointer"
                >
                  Retry Connection
                </button>
              </div>
            ) : null}

            {/* TOP-LEFT: FLOATING LAYER SELECTOR */}
            <div className="absolute top-3.5 left-3.5 z-[1000] pointer-events-auto">
              <div ref={layerMenuRef} className="relative">
                <button
                  type="button"
                  onClick={() => setLayerMenuOpen((prev) => !prev)}
                  className="bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-xl px-3.5 py-2 shadow-md flex items-center gap-2 text-xs font-bold text-slate-900 hover:bg-slate-50 cursor-pointer transition"
                >
                  <span
                    className="w-2.5 h-2.5 rounded-full shrink-0"
                    style={{ backgroundColor: activeCategoryConfig?.themeColor || '#0F172A' }}
                  />
                  <span className="truncate max-w-[200px]">
                    {selectedCategory === 'all'
                      ? 'Layer: All Categories'
                      : selectedSubcategory === 'all'
                      ? `Layer: ${activeCategoryConfig?.label}`
                      : `Layer: ${activeCategoryConfig?.label} › ${activeSubcategoryConfig?.label || ''}`}
                  </span>
                  <span className="text-[10px] font-mono font-bold text-slate-500 bg-slate-100 px-1.5 py-0.5 rounded-md shrink-0">
                    {filteredComplaints.length}
                  </span>
                  <svg
                    className={`w-3.5 h-3.5 text-slate-400 transition-transform ${layerMenuOpen ? 'rotate-180' : ''}`}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                {layerMenuOpen && (
                  <div className="absolute top-11 left-0 w-80 bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-2xl p-2.5 shadow-xl z-50 space-y-2.5 animate-in fade-in slide-in-from-top-2">
                    <div>
                      <div className="px-1 text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">
                        Main Categories
                      </div>
                      <div className="grid grid-cols-2 gap-1">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedCategory('all');
                            setSelectedSubcategory('all');
                            setSelectedZone(null);
                            setLayerMenuOpen(false);
                          }}
                          className={`col-span-2 px-2.5 py-1.5 rounded-xl text-left text-xs font-semibold flex items-center justify-between transition cursor-pointer ${
                            selectedCategory === 'all'
                              ? 'bg-slate-900 text-white font-bold shadow-xs'
                              : 'bg-slate-50 text-slate-700 hover:bg-slate-100'
                          }`}
                        >
                          <div className="flex items-center gap-2 truncate">
                            <Compass className="w-3.5 h-3.5 shrink-0" />
                            <span>All Categories</span>
                          </div>
                          <span
                            className={`text-[10px] px-1.5 py-0.2 rounded-md font-mono font-bold ${
                              selectedCategory === 'all' ? 'bg-white/20 text-white' : 'bg-slate-200 text-slate-600'
                            }`}
                          >
                            {categoryCounts.all || 0}
                          </span>
                        </button>

                        {filterCategoryOptions
                          .filter((cat) => cat.id !== 'all')
                          .map((cat) => {
                            const isCatActive = selectedCategory === cat.id;
                            return (
                              <button
                                key={cat.id}
                                type="button"
                                onClick={() => {
                                  setSelectedCategory(cat.id);
                                  setSelectedSubcategory('all');
                                  setSelectedZone(null);
                                }}
                                className={`px-2.5 py-1.5 rounded-xl text-left text-xs font-semibold flex items-center justify-between transition cursor-pointer ${
                                  isCatActive
                                    ? 'text-white font-bold shadow-xs'
                                    : 'bg-slate-50 text-slate-700 hover:bg-slate-100'
                                }`}
                                style={{
                                  backgroundColor: isCatActive ? cat.themeColor : undefined
                                }}
                              >
                                <div className="flex items-center gap-1.5 truncate">
                                  <span
                                    className="w-2 h-2 rounded-full shrink-0"
                                    style={{ backgroundColor: isCatActive ? '#FFFFFF' : cat.themeColor }}
                                  />
                                  <span className="truncate">{cat.label}</span>
                                </div>
                                <span
                                  className={`text-[10px] px-1 py-0.2 rounded-md font-mono font-bold shrink-0 ${
                                    isCatActive ? 'bg-white/25 text-white' : 'bg-slate-200 text-slate-600'
                                  }`}
                                >
                                  {cat.count}
                                </span>
                              </button>
                            );
                          })}
                      </div>
                    </div>

                    {selectedCategory !== 'all' && (
                      <div className="pt-2 border-t border-slate-100">
                        <div className="flex items-center justify-between px-1 mb-1.5">
                          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                            {activeCategoryConfig?.label} Sub-Types
                          </span>
                          <span className="text-[10px] font-mono text-slate-400">
                            {activeSubcategories.length}
                          </span>
                        </div>

                        <div className="space-y-1 max-h-48 overflow-y-auto pr-1 custom-scrollbar">
                          <button
                            type="button"
                            onClick={() => {
                              setSelectedSubcategory('all');
                              setSelectedZone(null);
                              setLayerMenuOpen(false);
                            }}
                            className={`w-full px-2.5 py-1.5 rounded-xl text-left text-xs font-semibold flex items-center justify-between transition cursor-pointer ${
                              selectedSubcategory === 'all'
                                ? 'bg-slate-900 text-white font-bold shadow-xs'
                                : 'text-slate-700 hover:bg-slate-100'
                            }`}
                          >
                            <div className="flex items-center gap-2 truncate">
                              <span
                                className="w-1.5 h-1.5 rounded-full shrink-0"
                                style={{ backgroundColor: activeCategoryConfig?.themeColor }}
                              />
                              <span className="truncate">All {activeCategoryConfig?.label}</span>
                            </div>
                            <span
                              className={`text-[10px] px-1.5 py-0.2 rounded-md font-mono font-bold ${
                                selectedSubcategory === 'all' ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
                              }`}
                            >
                              {categoryCounts[selectedCategory] || 0}
                            </span>
                          </button>

                          {activeSubcategories.map((sub) => {
                            const isSubActive = selectedSubcategory === sub.id;
                            return (
                              <button
                                key={sub.id}
                                type="button"
                                onClick={() => {
                                  setSelectedSubcategory(sub.id);
                                  setSelectedZone(null);
                                  setLayerMenuOpen(false);
                                }}
                                className={`w-full px-2.5 py-1.5 rounded-xl text-left text-xs font-semibold flex items-center justify-between transition cursor-pointer ${
                                  isSubActive
                                    ? 'bg-slate-900 text-white font-bold shadow-xs'
                                    : 'text-slate-700 hover:bg-slate-100'
                                }`}
                              >
                                <div className="flex items-center gap-2 truncate">
                                  <span
                                    className="w-1.5 h-1.5 rounded-full shrink-0"
                                    style={{
                                      backgroundColor: isSubActive ? '#FFFFFF' : activeCategoryConfig?.themeColor
                                    }}
                                  />
                                  <span className="truncate">{sub.label}</span>
                                </div>
                                <span
                                  className={`text-[10px] px-1.5 py-0.2 rounded-md font-mono font-bold ${
                                    isSubActive ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
                                  }`}
                                >
                                  {sub.count}
                                </span>
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>

            {/* TOP-RIGHT: HUD CONTROLS */}
            <div className="absolute top-3.5 right-3.5 z-[1000] flex flex-col items-end gap-2 pointer-events-auto">
              <div className="bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-2xl p-1.5 shadow-md flex items-center gap-1.5 text-xs">
                {/* View Mode Switcher */}
                <div className="flex bg-slate-100 rounded-xl p-0.5">
                  <button
                    type="button"
                    onClick={() => setViewMode('hybrid')}
                    title="Hybrid: Thermal Heatmap + Epicenter Nodes"
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                      viewMode === 'hybrid'
                        ? 'bg-slate-900 text-white shadow-2xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Hybrid
                  </button>

                  <button
                    type="button"
                    onClick={() => setViewMode('heatmap')}
                    title="Thermal Heatmap Density Only"
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                      viewMode === 'heatmap'
                        ? 'bg-slate-900 text-white shadow-2xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Heatmap
                  </button>

                  <button
                    type="button"
                    onClick={() => setViewMode('epicenters')}
                    title="Hotspot Epicenters Only"
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                      viewMode === 'epicenters'
                        ? 'bg-slate-900 text-white shadow-2xs'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    Hotspots
                  </button>
                </div>

                {/* Reset Mumbai View */}
                <button
                  type="button"
                  onClick={() => {
                    const map = mapInstanceRef.current;
                    if (map) map.flyTo(defaultCenter, 12, { duration: 1.0 });
                  }}
                  title="Reset to Mumbai Overview"
                  className="p-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 transition cursor-pointer"
                >
                  <Compass className="w-4 h-4 text-slate-600" />
                </button>

                {/* Map Tile Style Switcher Dropdown */}
                <div ref={styleMenuRef} className="relative">
                  <button
                    type="button"
                    onClick={() => setStyleMenuOpen((prev) => !prev)}
                    title="Select Map Tile Style"
                    className="p-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 transition cursor-pointer"
                  >
                    <Layers className="w-4 h-4 text-slate-600" />
                  </button>

                  {styleMenuOpen && (
                    <div className="absolute right-0 top-10 w-40 bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-xl p-1 shadow-lg z-50 space-y-0.5">
                      {Object.values(MAP_STYLES).map((st) => (
                        <button
                          key={st.id}
                          type="button"
                          onClick={() => {
                            setMapStyle(st.id);
                            setStyleMenuOpen(false);
                          }}
                          className={`w-full text-left px-2.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center justify-between ${
                            mapStyle === st.id
                              ? 'bg-slate-900 text-white'
                              : 'text-slate-700 hover:bg-slate-100'
                          }`}
                        >
                          <span>{st.label}</span>
                          {mapStyle === st.id && <span className="w-1.5 h-1.5 rounded-full bg-white" />}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                {/* Calibration HUD Toggle */}
                <button
                  type="button"
                  onClick={() => setShowControls((prev) => !prev)}
                  title="Tune Heatmap Intensity & Blur"
                  className={`p-1.5 rounded-xl border transition-all cursor-pointer ${
                    showControls
                      ? 'bg-amber-100 text-amber-900 border-amber-300'
                      : 'bg-white hover:bg-slate-100 text-slate-700 border-slate-200'
                  }`}
                >
                  <SlidersHorizontal className="w-4 h-4" />
                </button>
              </div>

              {/* Calibration Slider Drawer */}
              {showControls && (
                <div className="bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-2xl p-4 shadow-xl text-xs w-64 space-y-3 transition-all animate-in fade-in slide-in-from-top-2">
                  <div className="flex items-center justify-between pb-1.5 border-b border-slate-100">
                    <span className="font-extrabold text-[11px] uppercase tracking-wider text-slate-900 flex items-center gap-1.5">
                      <SlidersHorizontal className="w-3.5 h-3.5 text-slate-500" />
                      <span>Heat Calibration</span>
                    </span>
                    <button
                      type="button"
                      onClick={() => {
                        setHeatRadius(38);
                        setHeatBlur(24);
                        setHeatIntensity(1.0);
                      }}
                      className="text-[10px] text-blue-600 hover:underline font-bold cursor-pointer"
                    >
                      Reset
                    </button>
                  </div>

                  <div>
                    <div className="flex justify-between text-[11px] font-semibold text-slate-600 mb-1">
                      <span>Heat Radius</span>
                      <span className="font-mono font-bold text-slate-900">{heatRadius}px</span>
                    </div>
                    <input
                      type="range"
                      min="18"
                      max="65"
                      value={heatRadius}
                      onChange={(e) => setHeatRadius(Number(e.target.value))}
                      className="w-full h-1.5 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-slate-900"
                    />
                  </div>

                  <div>
                    <div className="flex justify-between text-[11px] font-semibold text-slate-600 mb-1">
                      <span>Diffusion Blur</span>
                      <span className="font-mono font-bold text-slate-900">{heatBlur}px</span>
                    </div>
                    <input
                      type="range"
                      min="10"
                      max="42"
                      value={heatBlur}
                      onChange={(e) => setHeatBlur(Number(e.target.value))}
                      className="w-full h-1.5 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-slate-900"
                    />
                  </div>

                  <div>
                    <div className="flex justify-between text-[11px] font-semibold text-slate-600 mb-1">
                      <span>Intensity Multiplier</span>
                      <span className="font-mono font-bold text-slate-900">{heatIntensity.toFixed(1)}x</span>
                    </div>
                    <input
                      type="range"
                      min="0.5"
                      max="1.8"
                      step="0.1"
                      value={heatIntensity}
                      onChange={(e) => setHeatIntensity(Number(e.target.value))}
                      className="w-full h-1.5 bg-slate-200 rounded-lg appearance-none cursor-pointer accent-slate-900"
                    />
                  </div>
                </div>
              )}
            </div>

            {/* FLOATING LEGEND: Bottom-Left */}
            <div className="absolute bottom-4 left-4 z-[1000] hidden sm:block pointer-events-auto">
              <HeatmapLegend
                categoryConfig={
                  selectedSubcategory !== 'all' && activeSubcategoryConfig
                    ? { ...activeCategoryConfig, label: `${activeCategoryConfig.label} › ${activeSubcategoryConfig.label}` }
                    : activeCategoryConfig
                }
                viewMode={viewMode}
                counts={{
                  LOW: zones.filter((z) => z.severity === 'LOW').length,
                  MEDIUM: zones.filter((z) => z.severity === 'MEDIUM').length,
                  HIGH: zones.filter((z) => z.severity === 'HIGH').length
                }}
              />
            </div>

            {/* LEAFLET MAP DOM CONTAINER */}
            <div
              ref={mapContainerRef}
              className="w-full h-full min-h-[480px] z-0"
              style={{ background: '#f8fafc', minHeight: '480px' }}
            />
          </div>

          {/* Selected Hotspot Inspection Drawer */}
          {selectedZone && (
            <div className="w-full shrink-0 mt-3 animate-in fade-in slide-in-from-bottom-2">
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

export default function Heatmap() {
  return (
    <HeatmapErrorBoundary>
      <HeatmapContent />
    </HeatmapErrorBoundary>
  );
}
