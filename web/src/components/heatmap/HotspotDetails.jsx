import React from 'react';
import { useUserRole } from '../../hooks/useUserRole';

export default function HotspotDetails({ zone, onClose }) {
  const { isAuthority } = useUserRole();

  if (!zone) return null;

  const {
    zone_type,
    severity,
    complaint_count,
    radius_meters,
    latitude,
    longitude,
    risk_score,
    assigned_authority_id
  } = zone;

  let severityBadgeClass = 'bg-emerald-100 text-[#10B981] border-emerald-300';
  if (severity === 'MEDIUM') severityBadgeClass = 'bg-amber-100 text-[#D97706] border-amber-300';
  if (severity === 'HIGH') severityBadgeClass = 'bg-red-100 text-[#DC2626] border-red-300';

  return (
    <div className="bg-white border border-gray-200 rounded-[16px] p-4 sm:p-5 shadow-sm mb-4">
      <div className="flex items-start justify-between gap-2 border-b border-gray-100 pb-3 mb-3">
        <div>
          <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block">
            Selected Hotspot Details
          </span>
          <h3 className="text-base sm:text-lg font-bold text-[#152937] capitalize mt-0.5">
            {zone_type} Zone
          </h3>
        </div>
        <button
          onClick={onClose}
          className="text-gray-400 hover:text-gray-600 text-xs font-semibold p-1 rounded-md hover:bg-gray-100 cursor-pointer"
          title="Close details"
        >
          ✕
        </button>
      </div>

      <div className="space-y-2.5 text-xs">
        <div className="flex items-center justify-between">
          <span className="text-gray-500 font-medium">Severity Level:</span>
          <span className={`px-2.5 py-0.5 text-xs font-bold rounded-md border uppercase ${severityBadgeClass}`}>
            {severity}
          </span>
        </div>

        {risk_score !== undefined && (
          <div className="flex items-center justify-between">
            <span className="text-gray-500 font-medium">Risk Score:</span>
            <span className="font-bold text-[#1E3A5F] text-sm">{risk_score} / 100</span>
          </div>
        )}

        <div className="flex items-center justify-between">
          <span className="text-gray-500 font-medium">Total Complaints:</span>
          <span className="font-semibold text-[#152937]">{complaint_count} reports</span>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-gray-500 font-medium">Geographical Radius:</span>
          <span className="font-semibold text-[#152937]">{radius_meters} meters</span>
        </div>

        <div className="flex items-center justify-between">
          <span className="text-gray-500 font-medium">Centroid Coordinates:</span>
          <span className="font-mono text-[11px] text-gray-700">
            {latitude?.toFixed(4)}, {longitude?.toFixed(4)}
          </span>
        </div>

        <div className="flex items-center justify-between pt-2 border-t border-gray-100">
          <span className="text-gray-500 font-medium">Assigned Authority:</span>
          <span className="text-gray-600 italic">
            {assigned_authority_id ? 'Assigned' : 'Pending Assignment'}
          </span>
        </div>

        {/* Authority Action Insight Notice (Rendered only when isAuthority is true) */}
        {isAuthority && (
          <div className="mt-3 pt-3 border-t border-amber-100 bg-amber-50/60 p-2.5 rounded-lg border">
            <p className="text-[11px] font-bold text-[#D97706] uppercase tracking-wider flex items-center gap-1">
              <span>⚠ Authority Priority Notice</span>
            </p>
            <p className="text-[11px] text-gray-600 mt-0.5 leading-tight">
              {severity === 'HIGH'
                ? 'High complaint density detected. Priority response recommended.'
                : 'Monitored area under active authority surveillance.'}
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
