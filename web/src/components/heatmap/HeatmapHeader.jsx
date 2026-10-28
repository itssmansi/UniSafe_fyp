import React from 'react';
import { ArrowLeft, RefreshCw, Layers, ShieldCheck, Maximize2, Minimize2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { useUserRole } from '../../hooks/useUserRole';
import { useSmartBack } from '../../hooks/useSmartBack';

export default function HeatmapHeader({ onRefresh, isRefreshing, isFullscreen, onToggleFullscreen }) {
  const { isAuthority } = useUserRole();
  const goBack = useSmartBack(isAuthority ? '/authority' : '/home');
  const navigate = useNavigate();

  return (
    <header className="w-full bg-white border-b border-slate-200/80 px-4 md:px-8 py-3.5 mb-5 font-sans shadow-2xs">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Left: Navigation and Breadcrumb */}
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={() => goBack(isAuthority ? '/authority' : '/home')}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 text-slate-700 text-xs font-bold transition-colors cursor-pointer shrink-0"
            title="Return to Operations Hub"
          >
            <ArrowLeft className="w-4 h-4 text-slate-600" />
            <span>Operations Hub</span>
          </button>

          <div className="h-4 w-px bg-slate-200 hidden sm:block" />

          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-base sm:text-lg font-black text-slate-900 tracking-tight leading-tight">
                Civic Risk & Density Heatmap
              </h1>
              <span className="text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded-md bg-blue-50 text-blue-700 border border-blue-200/70 hidden lg:inline-block">
                DBSCAN Telemetry
              </span>
            </div>
            <p className="text-[11px] text-slate-400 font-medium hidden sm:block">
              Centroid clustering, thermal risk surfaces, and municipal hazard surveillance
            </p>
          </div>
        </div>

        {/* Right: Actions and Live Role Status */}
        <div className="flex items-center gap-2 shrink-0 self-end md:self-auto">
          {isAuthority && (
            <button
              type="button"
              onClick={() => navigate('/kanban')}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold shadow-2xs transition-colors cursor-pointer"
              title="Open Field Dispatch Kanban"
            >
              <Layers className="w-3.5 h-3.5 text-blue-600" />
              <span className="hidden sm:inline">Kanban Dispatch</span>
            </button>
          )}

          {onRefresh && (
            <button
              type="button"
              onClick={onRefresh}
              disabled={isRefreshing}
              className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-semibold shadow-2xs transition-colors cursor-pointer ${
                isRefreshing ? 'opacity-60 pointer-events-none' : ''
              }`}
              title="Refresh Heatmap Data"
            >
              <RefreshCw className={`w-3.5 h-3.5 text-slate-600 ${isRefreshing ? 'animate-spin' : ''}`} />
              <span className="hidden sm:inline">Refresh</span>
            </button>
          )}

          {onToggleFullscreen && (
            <button
              type="button"
              onClick={onToggleFullscreen}
              className="p-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 transition-colors cursor-pointer hidden md:flex items-center justify-center"
              title={isFullscreen ? 'Exit Fullscreen' : 'Expand Fullscreen'}
            >
              {isFullscreen ? (
                <Minimize2 className="w-4 h-4 text-slate-600" />
              ) : (
                <Maximize2 className="w-4 h-4 text-slate-600" />
              )}
            </button>
          )}

          {/* Authority / Citizen Live Badge */}
          <div className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border border-emerald-200 bg-emerald-50/70 text-emerald-800 text-xs font-bold shadow-2xs">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
            <span className="text-[11px] font-bold">
              {isAuthority ? 'BMC Authority' : 'Citizen Access'}
            </span>
          </div>
        </div>
      </div>
    </header>
  );
}
