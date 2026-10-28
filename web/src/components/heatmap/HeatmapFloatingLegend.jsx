import React from 'react';

export default function HeatmapFloatingLegend({
  selectedCategory = 'Infrastructure',
  activeMode = 'hybrid',
  severityCounts = { LOW: 0, MEDIUM: 0, HIGH: 0 },
  department = null,
}) {
  const getCategoryColor = (cat) => {
    switch (cat) {
      case 'Infrastructure':
        return '#EF4444'; // Red
      case 'Sanitation':
        return '#F59E0B'; // Amber
      case 'Safety':
        return '#3B82F6'; // Blue
      case 'Greenery':
        return '#10B981'; // Green
      case 'Missing Persons':
        return '#8B5CF6'; // Purple
      default:
        return '#EF4444';
    }
  };

  const title =
    selectedCategory === 'All'
      ? department?.toLowerCase().includes('police')
        ? 'PUBLIC SAFETY'
        : 'CIVIC ISSUES'
      : selectedCategory.toUpperCase();

  const dotColor = getCategoryColor(selectedCategory);

  return (
    <div className="absolute bottom-4 left-4 z-[1000] font-sans">
      <div className="bg-white/95 backdrop-blur-md rounded-2xl shadow-xl border border-slate-200/80 p-3.5 sm:p-4 w-[280px] sm:w-[310px] space-y-3">
        {/* Header Row */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1.5 truncate">
            <span
              className="w-2.5 h-2.5 rounded-full inline-block shrink-0"
              style={{ backgroundColor: dotColor }}
            />
            <span className="text-xs font-black tracking-wider text-slate-800 truncate">
              {title}
            </span>
          </div>
          <span className="text-[10px] bg-slate-100 text-slate-600 px-2 py-0.5 rounded-md font-semibold capitalize">
            {activeMode}
          </span>
        </div>

        {/* Continuous Gradient Bar */}
        <div>
          <div className="h-2.5 w-full rounded-full bg-gradient-to-r from-[#FDE68A] via-[#F97316] via-[#DC2626] to-[#7F1D1D] shadow-inner" />
          <div className="flex justify-between items-center mt-1 text-[9px] font-bold text-slate-400 tracking-wider">
            <span>LOW DENSITY</span>
            <span>MODERATE</span>
            <span>CRITICAL CORE</span>
          </div>
        </div>

        {/* Severity Count Cards */}
        <div className="grid grid-cols-3 gap-2 pt-1 border-t border-slate-100">
          {/* Low */}
          <div className="bg-emerald-50/70 border border-emerald-100/90 rounded-xl py-1.5 px-1 text-center">
            <div className="text-[10px] font-bold text-emerald-600 flex items-center justify-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 inline-block" />
              <span>LOW</span>
            </div>
            <div className="text-sm font-extrabold text-emerald-950 mt-0.5">
              {severityCounts.LOW || 0}
            </div>
          </div>

          {/* Medium */}
          <div className="bg-amber-50/70 border border-amber-100/90 rounded-xl py-1.5 px-1 text-center">
            <div className="text-[10px] font-bold text-amber-600 flex items-center justify-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-amber-500 inline-block" />
              <span>MED</span>
            </div>
            <div className="text-sm font-extrabold text-amber-950 mt-0.5">
              {severityCounts.MEDIUM || 0}
            </div>
          </div>

          {/* High */}
          <div className="bg-rose-50/70 border border-rose-100/90 rounded-xl py-1.5 px-1 text-center">
            <div className="text-[10px] font-bold text-rose-600 flex items-center justify-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-rose-500 inline-block" />
              <span>HIGH</span>
            </div>
            <div className="text-sm font-extrabold text-rose-950 mt-0.5">
              {severityCounts.HIGH || 0}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
