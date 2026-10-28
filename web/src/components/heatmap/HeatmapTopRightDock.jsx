import React, { useState } from 'react';
import { SlidersHorizontal, RotateCcw, X } from 'lucide-react';

export default function HeatmapTopRightDock({
  activeMode = 'hybrid',
  setActiveMode,
  timeRange = 'all',
  setTimeRange,
  selectedSeverity = 'All',
  setSelectedSeverity,
  selectedJurisdiction = 'All',
  setSelectedJurisdiction,
  jurisdictions = [],
  onResetFilters,
  department = null,
}) {
  const [showSettings, setShowSettings] = useState(false);

  const isPolice = department?.toLowerCase().includes('police');
  const isBMC =
    department?.toLowerCase().includes('bmc') ||
    department?.toLowerCase().includes('municipal');

  const modes = [
    { id: 'hybrid', label: 'Hybrid' },
    { id: 'heatmap', label: 'Heatmap' },
    { id: 'hotspots', label: 'Hotspots' },
  ];

  const timeOptions = [
    { id: 'all', label: 'All Time' },
    { id: '30d', label: '30 Days' },
    { id: '7d', label: '7 Days' },
  ];

  const severities = ['All', 'HIGH', 'MEDIUM', 'LOW'];

  const hasExtraFilters =
    timeRange !== 'all' ||
    selectedSeverity !== 'All' ||
    selectedJurisdiction !== 'All';

  return (
    <div className="absolute top-4 right-4 z-[1000] font-sans flex flex-col items-end">
      {/* Dock Pill */}
      <div className="bg-white/95 backdrop-blur-md shadow-lg border border-slate-200/80 rounded-full p-1 flex items-center gap-1">
        {modes.map((mode) => {
          const isActive = activeMode === mode.id;
          return (
            <button
              key={mode.id}
              type="button"
              onClick={() => setActiveMode(mode.id)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition cursor-pointer ${
                isActive
                  ? 'bg-slate-900 text-white shadow-xs'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100/70'
              }`}
            >
              {mode.label}
            </button>
          );
        })}

        {/* Settings / Sliders Icon Button */}
        <button
          type="button"
          onClick={() => setShowSettings(!showSettings)}
          className={`p-1.5 rounded-full transition cursor-pointer relative ${
            showSettings || hasExtraFilters
              ? 'bg-slate-100 text-slate-900'
              : 'text-slate-500 hover:text-slate-800 hover:bg-slate-50'
          }`}
          title="Filter Options"
        >
          <SlidersHorizontal className="w-4 h-4" />
          {hasExtraFilters && (
            <span className="absolute top-1 right-1 w-2 h-2 rounded-full bg-red-500" />
          )}
        </button>
      </div>

      {/* Extra Filters Popover Drawer */}
      {showSettings && (
        <div className="mt-2 bg-white/98 backdrop-blur-md rounded-2xl shadow-2xl border border-slate-100 p-4 w-72 text-slate-800 space-y-3.5 animate-in fade-in zoom-in-95 duration-200 text-xs">
          <div className="flex items-center justify-between pb-2 border-b border-slate-100">
            <span className="font-bold text-[11px] text-slate-400 uppercase tracking-wider">
              {isPolice ? 'Police Hotspot Controls' : 'BMC Ward & Severity'}
            </span>
            <button
              type="button"
              onClick={() => setShowSettings(false)}
              className="text-slate-400 hover:text-slate-600 p-0.5 rounded cursor-pointer"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>

          {/* Time Horizon */}
          <div>
            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block mb-1">
              Time Horizon
            </label>
            <div className="grid grid-cols-3 gap-1 bg-slate-100/70 p-1 rounded-xl">
              {timeOptions.map((to) => (
                <button
                  key={to.id}
                  type="button"
                  onClick={() => setTimeRange(to.id)}
                  className={`py-1 rounded-lg text-center font-semibold text-[11px] transition cursor-pointer ${
                    timeRange === to.id
                      ? 'bg-white text-slate-900 shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  {to.label}
                </button>
              ))}
            </div>
          </div>

          {/* Severity */}
          <div>
            <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block mb-1">
              Severity Level
            </label>
            <div className="grid grid-cols-4 gap-1 bg-slate-100/70 p-1 rounded-xl">
              {severities.map((sev) => (
                <button
                  key={sev}
                  type="button"
                  onClick={() => setSelectedSeverity(sev)}
                  className={`py-1 rounded-lg text-center font-semibold text-[11px] transition cursor-pointer ${
                    selectedSeverity === sev
                      ? 'bg-white text-slate-900 shadow-2xs'
                      : 'text-slate-600 hover:text-slate-900'
                  }`}
                >
                  {sev}
                </button>
              ))}
            </div>
          </div>

          {/* Jurisdiction / Ward Dropdown */}
          {jurisdictions.length > 0 && (
            <div>
              <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block mb-1">
                {isPolice ? 'Police Jurisdiction' : 'BMC Ward / Zone'}
              </label>
              <select
                value={selectedJurisdiction}
                onChange={(e) => setSelectedJurisdiction(e.target.value)}
                className="w-full bg-slate-50 border border-slate-200 rounded-xl px-2.5 py-1.5 text-xs font-semibold text-slate-800 focus:outline-none focus:ring-1 focus:ring-slate-900 cursor-pointer"
              >
                <option value="All">All Jurisdictions</option>
                {jurisdictions.map((j) => (
                  <option key={j} value={j}>
                    {j}
                  </option>
                ))}
              </select>
            </div>
          )}

          {/* Reset Filters */}
          {hasExtraFilters && (
            <div className="pt-2 border-t border-slate-100 flex justify-end">
              <button
                type="button"
                onClick={onResetFilters}
                className="flex items-center gap-1 text-[11px] font-bold text-red-600 hover:underline cursor-pointer"
              >
                <RotateCcw className="w-3 h-3" />
                <span>Reset Additional Filters</span>
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
