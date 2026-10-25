import React from 'react';

export default function HeatmapLegend() {
  const legendItems = [
    { label: 'LOW', color: '#10B981', description: 'Low severity / Mostly resolved' },
    { label: 'MEDIUM', color: '#D97706', description: 'Moderate risk / Unresolved issues' },
    { label: 'HIGH', color: '#DC2626', description: 'Critical risk / High complaint density' },
  ];

  return (
    <div className="bg-white/90 backdrop-blur-md border border-[#EBE6DF] rounded-xl p-3 shadow-sm text-xs text-[#152937]">
      <p className="font-bold text-[#0B192C] mb-2 uppercase tracking-wider text-[10px]">
        RISK SEVERITY LEGEND
      </p>
      <div className="flex flex-col gap-1.5">
        {legendItems.map((item) => (
          <div key={item.label} className="flex items-center gap-2">
            <span
              className="w-2.5 h-2.5 rounded-full shrink-0"
              style={{ backgroundColor: item.color }}
            ></span>
            <span className="font-bold text-[#0B192C] text-[11px] w-14">
              {item.label}
            </span>
            <span className="text-gray-500 text-[11px]">
              {item.description}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
