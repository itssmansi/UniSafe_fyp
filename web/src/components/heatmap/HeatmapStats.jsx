import React from 'react';

export function HighRiskAreasStat({ count }) {
  return (
    <div className="bg-white border border-gray-200 rounded-[16px] p-4 shadow-sm flex items-center justify-between w-full min-h-[75px] font-sans">
      <div>
        <span className="text-[11px] font-semibold text-[#64748B] uppercase tracking-wider block">
          HIGH RISK AREAS
        </span>
        <span className="text-2xl font-extrabold text-[#0B192C] mt-0.5 block">
          {count}
        </span>
      </div>
      <div className="w-9 h-9 rounded-xl bg-red-50 text-[#DC2626] flex items-center justify-center font-bold text-base shrink-0">
        ⚠️
      </div>
    </div>
  );
}

export function ClusteredComplaintsStat({ count }) {
  return (
    <div className="bg-white border border-gray-200 rounded-[16px] p-4 shadow-sm flex items-center justify-between w-full min-h-[75px] font-sans">
      <div>
        <span className="text-[11px] font-semibold text-[#64748B] uppercase tracking-wider block">
          CLUSTERED COMPLAINTS
        </span>
        <span className="text-2xl font-extrabold text-[#0B192C] mt-0.5 block">
          {count}
        </span>
      </div>
      <div className="w-9 h-9 rounded-xl bg-slate-100 text-[#0B192C] flex items-center justify-center font-bold text-base shrink-0">
        📋
      </div>
    </div>
  );
}

export function ActiveHotspotsStat({ count }) {
  return (
    <div className="bg-white border border-gray-200 rounded-[16px] p-4 shadow-sm flex items-center justify-between w-full min-h-[75px] font-sans">
      <div>
        <span className="text-[11px] font-semibold text-[#64748B] uppercase tracking-wider block">
          ACTIVE HOTSPOTS
        </span>
        <span className="text-2xl font-extrabold text-[#0B192C] mt-0.5 block">
          {count}
        </span>
      </div>
      <div className="w-9 h-9 rounded-xl bg-red-50 text-[#DC2626] flex items-center justify-center font-bold text-base shrink-0">
        📍
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
      <HighRiskAreasStat count={highRiskCount} />
      <ClusteredComplaintsStat count={totalComplaints} />
      <ActiveHotspotsStat count={totalHotspots} />
    </div>
  );
}
