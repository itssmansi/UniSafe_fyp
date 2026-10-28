import React from 'react';
import { Building2, Sparkles, ShieldAlert, Trees, Compass, Flame, Crosshair, ChevronRight } from 'lucide-react';

const CATEGORY_ICONS = {
  infrastructure: Building2,
  sanitation: Sparkles,
  safety: ShieldAlert,
  greenery: Trees,
  default: Compass
};

export default function HotspotCard({ zone, isSelected, onSelect }) {
  const { zone_type, severity, complaint_count, radius_meters, latitude, longitude, risk_score } = zone;

  const typeLower = String(zone_type || '').toLowerCase();
  let CategoryIcon = CATEGORY_ICONS.default;
  if (typeLower.includes('infra') || typeLower.includes('road') || typeLower.includes('drain') || typeLower.includes('water')) {
    CategoryIcon = CATEGORY_ICONS.infrastructure;
  } else if (typeLower.includes('sanit') || typeLower.includes('waste') || typeLower.includes('garbage')) {
    CategoryIcon = CATEGORY_ICONS.sanitation;
  } else if (typeLower.includes('safe') || typeLower.includes('theft') || typeLower.includes('hazard') || typeLower.includes('manhole')) {
    CategoryIcon = CATEGORY_ICONS.safety;
  } else if (typeLower.includes('green') || typeLower.includes('tree') || typeLower.includes('park')) {
    CategoryIcon = CATEGORY_ICONS.greenery;
  }

  let badgeStyle = 'bg-emerald-50 text-emerald-700 border-emerald-200';
  let accentBar = 'bg-emerald-500';
  if (severity === 'MEDIUM') {
    badgeStyle = 'bg-amber-50 text-amber-700 border-amber-200';
    accentBar = 'bg-amber-500';
  } else if (severity === 'HIGH') {
    badgeStyle = 'bg-rose-50 text-rose-700 border-rose-200';
    accentBar = 'bg-rose-500';
  }

  return (
    <div
      onClick={() => onSelect(zone)}
      className={`relative p-3.5 rounded-2xl transition-all cursor-pointer text-left border flex flex-col justify-between font-sans overflow-hidden group ${
        isSelected
          ? 'bg-slate-50/80 border-slate-900 ring-2 ring-slate-900/10 shadow-md translate-x-1'
          : 'bg-white border-slate-200/90 hover:border-slate-300 hover:shadow-xs hover:translate-x-0.5'
      }`}
    >
      {/* Thermal Accent Strip */}
      <div className={`absolute top-0 left-0 bottom-0 w-1.5 ${accentBar}`} />

      <div className="pl-2 space-y-2">
        {/* Title & Severity Badge */}
        <div className="flex items-start justify-between gap-2">
          <div className="flex items-center gap-1.5 min-w-0">
            <div className="w-6 h-6 rounded-lg bg-slate-100 text-slate-600 flex items-center justify-center shrink-0">
              <CategoryIcon className="w-3.5 h-3.5" />
            </div>
            <h4 className="font-bold text-slate-900 capitalize text-xs truncate">
              {zone_type || 'General Hotspot'}
            </h4>
          </div>

          <span
            className={`px-2 py-0.5 text-[9px] font-black rounded-md border uppercase tracking-wider shrink-0 ${badgeStyle}`}
          >
            {severity}
          </span>
        </div>

        {/* Metrics Row */}
        <div className="flex items-center justify-between text-[11px] text-slate-500 font-medium">
          <div className="flex items-center gap-2">
            <span className="flex items-center gap-1 text-slate-900 font-bold">
              <Flame className="w-3.5 h-3.5 text-amber-500" />
              <span>{complaint_count || 1}</span>
              <span className="text-slate-400 font-normal">reports</span>
            </span>

            <span className="text-slate-300">·</span>

            <span className="flex items-center gap-1 text-slate-500">
              <Crosshair className="w-3 h-3 text-slate-400" />
              <span>{radius_meters || 250}m</span>
            </span>
          </div>

          {risk_score !== undefined && (
            <span className="text-[10px] font-mono font-bold text-slate-600 bg-slate-100 px-1.5 py-0.5 rounded-md">
              Risk {risk_score}
            </span>
          )}
        </div>

        {/* Footer with Pan Action */}
        <div className="pt-1.5 border-t border-slate-100 flex items-center justify-between text-[10px]">
          <span className="font-mono text-slate-400">
            {latitude ? `${Number(latitude).toFixed(3)}°, ${Number(longitude).toFixed(3)}°` : ''}
          </span>

          <span className="text-blue-600 font-bold flex items-center gap-0.5 group-hover:translate-x-0.5 transition-transform">
            <span>Focus</span>
            <ChevronRight className="w-3 h-3" />
          </span>
        </div>
      </div>
    </div>
  );
}
