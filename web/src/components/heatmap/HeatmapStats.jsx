import React from 'react';
import { ShieldAlert, Layers, Radio } from 'lucide-react';

export function HighRiskAreasStat({ count = 0, total = 0 }) {
  const percent = total > 0 ? Math.round((count / total) * 100) : null;

  return (
    <div className="bg-white border border-slate-200/90 rounded-2xl p-4 shadow-xs hover:shadow-sm transition-all flex items-center justify-between group font-sans">
      <div className="space-y-1">
        <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest block">
          CRITICAL RISK ZONES
        </span>
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-black text-slate-900 tracking-tight font-mono">
            {count}
          </span>
          <span className="text-[10px] font-bold text-rose-700 bg-rose-50 px-2 py-0.5 rounded-md border border-rose-200/70">
            {percent !== null ? `${percent}% of total` : 'Immediate Attention'}
          </span>
        </div>
        <p className="text-[11px] text-slate-400 font-medium">High severity density centroids</p>
      </div>

      <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-rose-500/10 to-rose-600/20 text-rose-600 flex items-center justify-center border border-rose-200/80 shadow-xs shrink-0 group-hover:scale-105 transition-transform">
        <ShieldAlert className="w-5 h-5 stroke-[2.2]" />
      </div>
    </div>
  );
}

export function ClusteredComplaintsStat({ count = 0 }) {
  return (
    <div className="bg-white border border-slate-200/90 rounded-2xl p-4 shadow-xs hover:shadow-sm transition-all flex items-center justify-between group font-sans">
      <div className="space-y-1">
        <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest block">
          CLUSTERED REPORTS
        </span>
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-black text-slate-900 tracking-tight font-mono">
            {count}
          </span>
          <span className="text-[10px] font-bold text-blue-700 bg-blue-50 px-2 py-0.5 rounded-md border border-blue-200/70">
            DBSCAN Density
          </span>
        </div>
        <p className="text-[11px] text-slate-400 font-medium">Civic complaints mapped</p>
      </div>

      <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-blue-500/10 to-blue-600/20 text-blue-600 flex items-center justify-center border border-blue-200/80 shadow-xs shrink-0 group-hover:scale-105 transition-transform">
        <Layers className="w-5 h-5 stroke-[2.2]" />
      </div>
    </div>
  );
}

export function ActiveHotspotsStat({ count = 0 }) {
  return (
    <div className="bg-white border border-slate-200/90 rounded-2xl p-4 shadow-xs hover:shadow-sm transition-all flex items-center justify-between group font-sans">
      <div className="space-y-1">
        <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest block">
          ACTIVE EPICENTERS
        </span>
        <div className="flex items-baseline gap-2">
          <span className="text-2xl font-black text-slate-900 tracking-tight font-mono">
            {count}
          </span>
          <span className="text-[10px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded-md border border-amber-200/70">
            Centroids Active
          </span>
        </div>
        <p className="text-[11px] text-slate-400 font-medium">Geographic incident hubs</p>
      </div>

      <div className="w-11 h-11 rounded-xl bg-gradient-to-br from-amber-500/10 to-amber-600/20 text-amber-600 flex items-center justify-center border border-amber-200/80 shadow-xs shrink-0 group-hover:scale-105 transition-transform">
        <Radio className="w-5 h-5 stroke-[2.2]" />
      </div>
    </div>
  );
}

export default function HeatmapStats({ zones = [] }) {
  const totalHotspots = zones.length;
  const totalComplaints = zones.reduce((acc, z) => acc + (z.complaint_count || 0), 0);
  const highRiskCount = zones.filter((z) => z.severity === 'HIGH').length;

  return (
    <div className="space-y-3 w-full">
      <HighRiskAreasStat count={highRiskCount} total={totalHotspots} />
      <ClusteredComplaintsStat count={totalComplaints} />
      <ActiveHotspotsStat count={totalHotspots} />
    </div>
  );
}
