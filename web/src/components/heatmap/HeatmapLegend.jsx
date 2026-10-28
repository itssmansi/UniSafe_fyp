import React from 'react';

export default function HeatmapLegend({ department = null }) {
  const isPolice = department?.toLowerCase().includes('police');
  const isBMC =
    department?.toLowerCase().includes('bmc') ||
    department?.toLowerCase().includes('municipal');

  const legendItems = [
    { label: 'LOW', color: '#10B981', description: 'Low severity / Mostly resolved' },
    { label: 'MEDIUM', color: '#D97706', description: 'Moderate risk / Unresolved issues' },
    { label: 'HIGH', color: '#DC2626', description: 'Critical density / Immediate response' },
  ];

  if (!isBMC) {
    legendItems.push({
      label: 'MISSING',
      color: '#7C3AED',
      description: 'Active missing-person search zone',
    });
  }

  return (
    <div className="bg-white/95 backdrop-blur-md border border-[#EBE6DF] rounded-xl p-3 shadow-sm text-xs text-[#152937] max-w-[260px]">
      <p className="font-bold text-[#0B192C] mb-2 uppercase tracking-wider text-[10px]">
        {isPolice ? 'POLICE SAFETY LEGEND' : isBMC ? 'BMC CIVIC RISK LEGEND' : 'HOTSPOT RISK LEGEND'}
      </p>
      <div className="flex flex-col gap-1.5">
        {legendItems.map((item) => (
          <div key={item.label} className="flex items-center gap-2">
            <span
              className="w-2.5 h-2.5 rounded-full shrink-0 shadow-2xs"
              style={{ backgroundColor: item.color }}
            ></span>
            <span className="font-bold text-[#0B192C] text-[11px] w-14">
              {item.label}
            </span>
            <span className="text-gray-500 text-[10px] truncate" title={item.description}>
              {item.description}
            </span>
          </div>
        ))}
      </div>
      <div className="mt-2 pt-2 border-t border-gray-100 flex items-center justify-between text-[10px] text-gray-400">
        <span>Concentric heat ring layers</span>
        <span>4-layer gradient</span>
      </div>
    </div>
  );
}
