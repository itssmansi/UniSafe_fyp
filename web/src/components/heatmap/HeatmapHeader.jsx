import React from 'react';
import { Flame, Search, ExternalLink } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function HeatmapHeader({
  searchQuery = '',
  setSearchQuery,
  onSearchSubmit,
  authority = null,
  isEmbedded = false,
}) {
  const isPolice = authority?.department?.toLowerCase().includes('police');
  const isBMC =
    authority?.department?.toLowerCase().includes('bmc') ||
    authority?.department?.toLowerCase().includes('municipal');

  return (
    <header className="w-full bg-white border-b border-slate-200/80 px-4 sm:px-6 py-3 font-sans">
      <div className="max-w-[1600px] mx-auto flex flex-col md:flex-row md:items-center justify-between gap-3">
        {/* Left: Title & Live Dispatch Status */}
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <Flame className="w-5 h-5 text-slate-800" />
            <h1 className="text-lg sm:text-xl font-extrabold text-slate-900 tracking-tight">
              Heatmap & Hotspots
            </h1>
          </div>

          {/* Live Dispatch Indicator */}
          <div className="flex items-center gap-1.5 ml-2 pl-3 border-l border-slate-200">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-xs font-bold text-slate-700 tracking-tight">
              Live Dispatch: <span className="text-emerald-600 font-semibold">Active</span>
            </span>
          </div>

          {authority?.department && (
            <span className="hidden lg:inline-block text-[11px] font-bold px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 border border-slate-200 ml-1">
              {authority.department}
            </span>
          )}
        </div>

        {/* Center: Search Bar */}
        <div className="flex-1 max-w-md mx-auto md:mx-4 w-full">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (onSearchSubmit) onSearchSubmit(searchQuery);
            }}
            className="relative flex items-center w-full"
          >
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery && setSearchQuery(e.target.value)}
              placeholder="Search complaints, wards, staff..."
              className="w-full bg-slate-50 hover:bg-slate-100/70 focus:bg-white text-xs font-medium text-slate-800 placeholder-slate-400 pl-9 pr-14 py-2 rounded-xl border border-slate-200/80 focus:outline-none focus:ring-1 focus:ring-slate-900 transition"
            />
            <div className="absolute right-2.5 flex items-center gap-0.5 pointer-events-none">
              <kbd className="text-[10px] font-semibold text-slate-400 bg-white border border-slate-200 rounded px-1.5 py-0.5 shadow-2xs">
                ⌘ K
              </kbd>
            </div>
          </form>
        </div>

        {/* Right: Citizen Portal Button */}
        <div className="flex items-center justify-end gap-2 shrink-0">
          <Link
            to="/"
            className="flex items-center gap-1.5 bg-slate-50 hover:bg-slate-100 text-slate-700 hover:text-slate-900 border border-slate-200/80 text-xs font-bold px-3.5 py-2 rounded-xl shadow-2xs transition active:scale-95 cursor-pointer"
          >
            <ExternalLink className="w-3.5 h-3.5 text-slate-500" />
            <span>Citizen Portal</span>
          </Link>
        </div>
      </div>
    </header>
  );
}
