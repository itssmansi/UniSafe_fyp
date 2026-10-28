import React from 'react';
import { Filter, RotateCcw, Building2, Sparkles, ShieldAlert, Trees, Compass, Search } from 'lucide-react';

const CATEGORY_ICONS = {
  all: Compass,
  infrastructure: Building2,
  sanitation: Sparkles,
  safety: ShieldAlert,
  greenery: Trees
};

export default function HeatmapFilters({
  categories = [],
  selectedCategory,
  setSelectedCategory,
  subcategories = [],
  selectedSubcategory,
  setSelectedSubcategory,
  selectedSeverity,
  setSelectedSeverity,
  searchQuery = '',
  setSearchQuery,
  severityCounts = { LOW: 0, MEDIUM: 0, HIGH: 0 },
  onClearFilters,
}) {
  const severities = [
    { id: 'All', label: 'ALL', color: 'bg-slate-900', text: 'text-slate-700' },
    { id: 'LOW', label: 'LOW', color: 'bg-emerald-500', text: 'text-emerald-700', count: severityCounts.LOW },
    { id: 'MEDIUM', label: 'MED', color: 'bg-amber-500', text: 'text-amber-700', count: severityCounts.MEDIUM },
    { id: 'HIGH', label: 'HIGH', color: 'bg-rose-500', text: 'text-rose-700', count: severityCounts.HIGH },
  ];

  const hasActiveFilters =
    selectedCategory !== 'all' ||
    (selectedSubcategory && selectedSubcategory !== 'all') ||
    selectedSeverity !== 'All' ||
    (searchQuery && searchQuery.trim().length > 0);

  return (
    <div className="bg-white border border-slate-200/90 rounded-2xl p-4 sm:p-5 shadow-xs space-y-4 font-sans w-full">
      {/* Top Header */}
      <div className="flex items-center justify-between pb-2.5 border-b border-slate-100">
        <div className="flex items-center gap-1.5 text-slate-700">
          <Filter className="w-3.5 h-3.5 text-slate-500" />
          <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">
            INCIDENT FILTERS
          </span>
        </div>
        {hasActiveFilters && (
          <button
            type="button"
            onClick={onClearFilters}
            className="inline-flex items-center gap-1 text-[11px] font-bold text-rose-600 hover:text-rose-700 transition cursor-pointer"
            title="Reset active filters"
          >
            <RotateCcw className="w-3 h-3" />
            <span>Reset</span>
          </button>
        )}
      </div>

      {/* Search Input */}
      {setSearchQuery && (
        <div className="relative">
          <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 pointer-events-none" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search hotspots or categories..."
            className="w-full bg-slate-50 border border-slate-200 rounded-xl pl-9 pr-3 py-2 text-xs font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-slate-900 focus:bg-white transition"
          />
        </div>
      )}

      {/* Main Category Dropdown / Segment */}
      <div>
        <label className="text-[11px] font-bold text-slate-600 block mb-1.5 uppercase tracking-wide">
          Incident Domain
        </label>
        <div className="relative">
          <select
            value={selectedCategory}
            onChange={(e) => {
              setSelectedCategory(e.target.value);
              if (setSelectedSubcategory) {
                setSelectedSubcategory('all');
              }
            }}
            className="w-full bg-slate-50 border border-slate-200 text-slate-900 text-xs font-bold rounded-xl px-3 py-2.5 appearance-none focus:outline-none focus:ring-1 focus:ring-slate-900 transition cursor-pointer pr-8"
          >
            {categories.map((cat) => {
              const val = typeof cat === 'object' ? cat.id : cat;
              const label = typeof cat === 'object' ? cat.label : cat;
              const count = typeof cat === 'object' && cat.count !== undefined ? ` (${cat.count})` : '';
              return (
                <option key={val} value={val}>
                  {label}{count}
                </option>
              );
            })}
          </select>
          <div className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-slate-400">
            <svg className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 9l-7 7-7-7" />
            </svg>
          </div>
        </div>
      </div>

      {/* Subcategory Chips (Cascading) */}
      {selectedCategory !== 'all' && subcategories && subcategories.length > 0 && (
        <div className="space-y-1.5 animate-in fade-in duration-200">
          <label className="text-[11px] font-bold text-slate-600 block uppercase tracking-wide">
            Sub-Category Filter
          </label>
          <div className="flex flex-wrap gap-1.5 max-h-36 overflow-y-auto custom-scrollbar p-0.5">
            <button
              type="button"
              onClick={() => setSelectedSubcategory('all')}
              className={`px-2.5 py-1 rounded-lg text-[11px] font-bold transition-all cursor-pointer ${
                selectedSubcategory === 'all'
                  ? 'bg-slate-900 text-white shadow-2xs'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              All {categories.find((c) => c.id === selectedCategory)?.label || ''}
            </button>
            {subcategories.map((sub) => {
              const isActive = selectedSubcategory === sub.id;
              return (
                <button
                  key={sub.id}
                  type="button"
                  onClick={() => setSelectedSubcategory(sub.id)}
                  className={`px-2.5 py-1 rounded-lg text-[11px] font-bold transition-all cursor-pointer flex items-center gap-1.5 ${
                    isActive
                      ? 'bg-slate-900 text-white shadow-2xs'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                  }`}
                >
                  <span>{sub.label}</span>
                  <span className={`text-[10px] px-1 py-0.2 rounded-sm ${isActive ? 'bg-white/25 text-white' : 'bg-slate-200 text-slate-500'}`}>
                    {sub.count}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* Severity Level Segmented Tabs */}
      <div>
        <label className="text-[11px] font-bold text-slate-600 block mb-1.5 uppercase tracking-wide">
          Severity Level
        </label>
        <div className="grid grid-cols-4 gap-1 bg-slate-100 p-1 rounded-xl border border-slate-200">
          {severities.map((sev) => {
            const isSelected = selectedSeverity === sev.id;

            return (
              <button
                key={sev.id}
                type="button"
                onClick={() => setSelectedSeverity(sev.id)}
                className={`py-2 text-[11px] font-black rounded-lg transition-all cursor-pointer flex flex-col items-center justify-center gap-0.5 ${
                  isSelected
                    ? 'bg-white text-slate-900 shadow-2xs border border-slate-200'
                    : 'text-slate-500 hover:text-slate-900'
                }`}
              >
                <div className="flex items-center gap-1">
                  {sev.id !== 'All' && (
                    <span className={`w-1.5 h-1.5 rounded-full ${sev.color}`} />
                  )}
                  <span>{sev.label}</span>
                </div>
                {sev.count !== undefined && (
                  <span className="text-[9px] font-mono text-slate-400">
                    {sev.count}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
