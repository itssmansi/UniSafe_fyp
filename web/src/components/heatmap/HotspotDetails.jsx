import React, { useState } from 'react';
import { 
  X, 
  MapPin, 
  Layers, 
  Crosshair, 
  Building2, 
  AlertTriangle, 
  ExternalLink, 
  Copy, 
  Check, 
  ShieldAlert 
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useUserRole } from '../../hooks/useUserRole';

export default function HotspotDetails({ zone, onClose }) {
  const { isAuthority } = useUserRole();
  const navigate = useNavigate();
  const [copied, setCopied] = useState(false);

  if (!zone) return null;

  const {
    zone_type,
    severity,
    complaint_count,
    radius_meters,
    latitude,
    longitude,
    risk_score = 65,
    assigned_authority_id,
    complaints = []
  } = zone;

  let severityBadgeClass = 'bg-emerald-50 text-emerald-700 border-emerald-200';
  let progressColor = 'bg-emerald-500';
  if (severity === 'MEDIUM') {
    severityBadgeClass = 'bg-amber-50 text-amber-700 border-amber-200';
    progressColor = 'bg-amber-500';
  } else if (severity === 'HIGH') {
    severityBadgeClass = 'bg-rose-50 text-rose-700 border-rose-200';
    progressColor = 'bg-rose-500';
  }

  const handleCopyCoords = () => {
    if (latitude && longitude) {
      navigator.clipboard.writeText(`${Number(latitude).toFixed(5)}, ${Number(longitude).toFixed(5)}`);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleOpenKanban = () => {
    navigate('/kanban');
  };

  return (
    <div className="bg-white border border-slate-200/90 rounded-2xl p-4 sm:p-5 shadow-lg mb-4 font-sans animate-in fade-in slide-in-from-bottom-2 duration-200">
      {/* Top Header */}
      <div className="flex items-start justify-between gap-3 border-b border-slate-100 pb-3 mb-3">
        <div className="space-y-0.5">
          <div className="flex items-center gap-1.5 text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            <ShieldAlert className="w-3.5 h-3.5 text-blue-600" />
            <span>CENTROID INSPECTION DRAWER</span>
          </div>
          <h3 className="text-base font-black text-slate-900 capitalize tracking-tight">
            {zone_type} Hotspot Sector
          </h3>
        </div>

        <div className="flex items-center gap-2">
          <span className={`px-2.5 py-1 text-[10px] font-black rounded-lg border uppercase tracking-wider ${severityBadgeClass}`}>
            {severity} RISK
          </span>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100 transition cursor-pointer"
            title="Close inspector"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Risk Score Progress Meter */}
      <div className="mb-4 bg-slate-50 border border-slate-200/80 rounded-xl p-3">
        <div className="flex items-center justify-between text-xs font-bold text-slate-700 mb-1.5">
          <span className="flex items-center gap-1.5">
            <span>Risk Index Score</span>
            <span className="text-[10px] font-normal text-slate-400">(DBSCAN & Upvotes)</span>
          </span>
          <span className="font-mono text-sm font-black text-slate-900">{risk_score} / 100</span>
        </div>
        <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-500 ${progressColor}`}
            style={{ width: `${Math.min(risk_score, 100)}%` }}
          />
        </div>
      </div>

      {/* Metadata Grid */}
      <div className="grid grid-cols-2 gap-2 text-xs mb-4">
        <div className="bg-slate-50 border border-slate-100 rounded-xl p-2.5 space-y-0.5">
          <span className="text-[10px] font-semibold text-slate-400 uppercase flex items-center gap-1">
            <Layers className="w-3 h-3 text-slate-500" />
            <span>Total Reports</span>
          </span>
          <p className="font-mono font-bold text-slate-900 text-sm">
            {complaint_count || 1} complaints
          </p>
        </div>

        <div className="bg-slate-50 border border-slate-100 rounded-xl p-2.5 space-y-0.5">
          <span className="text-[10px] font-semibold text-slate-400 uppercase flex items-center gap-1">
            <Crosshair className="w-3 h-3 text-slate-500" />
            <span>Catchment Radius</span>
          </span>
          <p className="font-mono font-bold text-slate-900 text-sm">
            {radius_meters || 250} meters
          </p>
        </div>

        <div className="col-span-2 bg-slate-50 border border-slate-100 rounded-xl p-2.5 flex items-center justify-between">
          <div className="space-y-0.5">
            <span className="text-[10px] font-semibold text-slate-400 uppercase flex items-center gap-1">
              <MapPin className="w-3 h-3 text-slate-500" />
              <span>Centroid GPS</span>
            </span>
            <p className="font-mono text-xs font-bold text-slate-800">
              {latitude?.toFixed(5)}° N, {longitude?.toFixed(5)}° E
            </p>
          </div>

          <button
            type="button"
            onClick={handleCopyCoords}
            className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg border border-slate-200 bg-white hover:bg-slate-100 text-slate-700 text-[11px] font-bold shadow-2xs transition cursor-pointer"
            title="Copy coordinates to clipboard"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-600" />
                <span className="text-emerald-700">Copied</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5 text-slate-500" />
                <span>Copy GPS</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Priority Action Insight */}
      {isAuthority && (
        <div className="bg-amber-50/80 border border-amber-200/90 rounded-xl p-3 mb-4 space-y-1">
          <div className="flex items-center gap-1.5 text-amber-800 text-xs font-bold">
            <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0" />
            <span>BMC Municipal Surveillance Action</span>
          </div>
          <p className="text-[11px] text-amber-900/80 leading-relaxed pl-5">
            {severity === 'HIGH'
              ? 'Multi-report cluster exceeds safety threshold. Priority field team dispatch and ward officer notification recommended.'
              : 'Cluster logged under active surveillance. Routine patrol and resolution monitoring in progress.'}
          </p>
        </div>
      )}

      {/* Action Footer */}
      <div className="flex items-center justify-between gap-2 pt-2 border-t border-slate-100">
        <span className="text-[11px] text-slate-400 flex items-center gap-1">
          <Building2 className="w-3.5 h-3.5 text-slate-400" />
          <span>{assigned_authority_id ? 'Assigned' : 'BMC Corporation'}</span>
        </span>

        {isAuthority && (
          <button
            type="button"
            onClick={handleOpenKanban}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-900 hover:bg-black text-white text-xs font-bold rounded-xl shadow-xs transition cursor-pointer"
          >
            <span>View Tickets in Kanban</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </button>
        )}
      </div>
    </div>
  );
}
