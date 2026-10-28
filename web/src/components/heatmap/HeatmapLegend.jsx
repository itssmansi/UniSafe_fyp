import React, { useState } from 'react';
import { ChevronDown, ChevronUp, Layers } from 'lucide-react';

export default function HeatmapLegend({
  categoryConfig,
  viewMode = 'hybrid',
  counts = { LOW: 0, MEDIUM: 0, HIGH: 0 }
}) {
  const [collapsed, setCollapsed] = useState(false);

  const gradientCss = categoryConfig?.gradientCss || 'linear-gradient(to right, #3B82F6 0%, #06B6D4 25%, #10B981 50%, #F59E0B 72%, #F97316 88%, #DC2626 100%)';
  const categoryLabel = categoryConfig?.label || 'All Categories';
  const themeColor = categoryConfig?.themeColor || '#0F172A';

  if (collapsed) {
    return (
      <button
        type="button"
        onClick={() => setCollapsed(false)}
        className="bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-xl px-3 py-1.5 shadow-md text-xs font-bold text-slate-800 hover:bg-slate-50 flex items-center gap-1.5 cursor-pointer font-sans transition-all"
        title="Expand Thermal Legend"
      >
        <span className="w-2 h-2 rounded-full" style={{ backgroundColor: themeColor }} />
        <span>Legend</span>
        <ChevronUp className="w-3.5 h-3.5 text-slate-400" />
      </button>
    );
  }

  return (
    <div className="bg-white/95 backdrop-blur-md border border-slate-200/90 rounded-2xl p-3.5 shadow-lg text-xs text-slate-800 font-sans w-72 transition-all">
      <div className="flex items-center justify-between pb-2 border-b border-slate-100 mb-2.5">
        <div className="flex items-center gap-1.5 min-w-0">
          <span
            className="w-2.5 h-2.5 rounded-full shrink-0"
            style={{ backgroundColor: themeColor }}
          />
          <span className="font-extrabold uppercase tracking-wider text-[10px] text-slate-900 truncate">
            {categoryLabel}
          </span>
        </div>

        <div className="flex items-center gap-1.5">
          <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-slate-100 text-slate-600 capitalize">
            {viewMode}
          </span>
          <button
            type="button"
            onClick={() => setCollapsed(true)}
            className="p-0.5 text-slate-400 hover:text-slate-600 rounded transition cursor-pointer"
            title="Minimize Legend"
          >
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Dynamic Thermal Density Gradient Bar */}
      <div className="space-y-1.5 mb-3">
        <div 
          className="w-full h-2.5 rounded-full shadow-inner border border-black/10 transition-all duration-300"
          style={{ background: gradientCss }}
        />
        <div className="flex justify-between text-[9px] font-bold text-slate-400 uppercase tracking-tight px-0.5">
          <span>Low</span>
          <span>Moderate</span>
          <span>Elevated</span>
          <span>Critical</span>
        </div>
      </div>

      {/* Severity Breakdown Badges */}
      <div className="grid grid-cols-3 gap-1.5 pt-1 border-t border-slate-100">
        <div className="flex flex-col items-center bg-emerald-50/70 border border-emerald-200/60 rounded-xl p-1.5 text-center">
          <div className="flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
            <span className="text-[9px] font-extrabold text-emerald-800">LOW</span>
          </div>
          <span className="text-xs font-black font-mono text-emerald-950 mt-0.5">
            {counts.LOW || 0}
          </span>
        </div>

        <div className="flex flex-col items-center bg-amber-50/70 border border-amber-200/60 rounded-xl p-1.5 text-center">
          <div className="flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500"></span>
            <span className="text-[9px] font-extrabold text-amber-800">MED</span>
          </div>
          <span className="text-xs font-black font-mono text-amber-950 mt-0.5">
            {counts.MEDIUM || 0}
          </span>
        </div>

        <div className="flex flex-col items-center bg-rose-50/70 border border-rose-200/60 rounded-xl p-1.5 text-center">
          <div className="flex items-center gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-rose-500"></span>
            <span className="text-[9px] font-extrabold text-rose-800">HIGH</span>
          </div>
          <span className="text-xs font-black font-mono text-rose-950 mt-0.5">
            {counts.HIGH || 0}
          </span>
        </div>
      </div>
    </div>
  );
}
