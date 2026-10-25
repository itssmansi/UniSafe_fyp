import React from 'react';

export default function HotspotCard({ zone, isSelected, onSelect }) {
  const { zone_type, severity, complaint_count, radius_meters } = zone;

  let badgeStyle = 'bg-[#DCFCE7] text-[#16A34A]';
  if (severity === 'MEDIUM') badgeStyle = 'bg-[#FEF3C7] text-[#D97706]';
  if (severity === 'HIGH') badgeStyle = 'bg-[#FEE2E2] text-[#DC2626]';

  return (
    <div
      onClick={() => onSelect(zone)}
      className={`p-4 sm:p-4.5 rounded-2xl transition-all cursor-pointer text-left border min-h-[80px] flex flex-col justify-between font-sans ${
        isSelected
          ? 'bg-white border-[#0B192C] ring-1 ring-[#0B192C] shadow-xs'
          : 'bg-white border-[#EBE6DF] hover:border-gray-300 hover:shadow-2xs'
      }`}
    >
      <div className="flex items-center justify-between gap-2">
        <h4 className="font-semibold text-[#0B192C] capitalize text-base">
          {zone_type || 'General Hotspot'}
        </h4>
        <span
          className={`px-2.5 py-0.5 text-xs font-extrabold rounded-md uppercase tracking-wider ${badgeStyle}`}
        >
          {severity}
        </span>
      </div>

      <div className="mt-1.5 text-sm text-[#64748B] font-medium flex items-center gap-2">
        <span>{complaint_count} reports</span>
        <span>·</span>
        <span>{radius_meters}m</span>
      </div>
    </div>
  );
}
