import React from 'react';
import { AlertTriangle, ClipboardList, MapPin } from 'lucide-react';

export function HighRiskAreasStat({ count = 0 }) {
  return (
    <div className="bg-white border border-slate-100 rounded-[20px] p-4 sm:p-5 shadow-xs flex items-center justify-between w-full font-sans transition hover:shadow-sm">
      <div>
        <span className="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
          HIGH RISK AREAS
        </span>
        <span className="text-2xl sm:text-3xl font-extrabold text-slate-900 mt-1 block tabular-nums">
          {count}
        </span>
      </div>
      <div className="w-10 h-10 rounded-2xl bg-amber-50/80 border border-amber-100/60 text-amber-500 flex items-center justify-center shrink-0">
        <AlertTriangle className="w-5 h-5 text-amber-500" />
      </div>
    </div>
  );
}

export function ClusteredComplaintsStat({ count = 0 }) {
  return (
    <div className="bg-white border border-slate-100 rounded-[20px] p-4 sm:p-5 shadow-xs flex items-center justify-between w-full font-sans transition hover:shadow-sm">
      <div>
        <span className="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
          CLUSTERED COMPLAINTS
        </span>
        <span className="text-2xl sm:text-3xl font-extrabold text-slate-900 mt-1 block tabular-nums">
          {count}
        </span>
      </div>
      <div className="w-10 h-10 rounded-2xl bg-slate-50 border border-slate-100 text-slate-700 flex items-center justify-center shrink-0">
        <ClipboardList className="w-5 h-5 text-slate-600" />
      </div>
    </div>
  );
}

export function ActiveHotspotsStat({ count = 0 }) {
  return (
    <div className="bg-white border border-slate-100 rounded-[20px] p-4 sm:p-5 shadow-xs flex items-center justify-between w-full font-sans transition hover:shadow-sm">
      <div>
        <span className="text-[10px] sm:text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
          ACTIVE HOTSPOTS
        </span>
        <span className="text-2xl sm:text-3xl font-extrabold text-slate-900 mt-1 block tabular-nums">
          {count}
        </span>
      </div>
      <div className="w-10 h-10 rounded-2xl bg-rose-50/80 border border-rose-100/60 text-rose-500 flex items-center justify-center shrink-0">
        <MapPin className="w-5 h-5 text-rose-500" />
      </div>
    </div>
  );
}

export default function HeatmapStats({ zones = [] }) {
  const totalHotspots = zones.length;
  const totalComplaints = zones.reduce((acc, z) => acc + (z.complaint_count || 0), 0);
  const highRiskCount = zones.filter((z) => z.severity === 'HIGH').length;

  return (
    <div className="space-y-3.5 w-full font-sans">
      <HighRiskAreasStat count={highRiskCount} />
      <ClusteredComplaintsStat count={totalComplaints} />
      <ActiveHotspotsStat count={totalHotspots} />
    </div>
  );
}
