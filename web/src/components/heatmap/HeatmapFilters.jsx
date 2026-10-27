import React from 'react';

export default function HeatmapFilters({
  categories = [],
  selectedCategory,
  setSelectedCategory,
  selectedSeverity,
  setSelectedSeverity,
  onClearFilters
}) {
  const severities = ['All', 'LOW', 'MEDIUM', 'HIGH'];
  const hasActiveFilters = selectedCategory !== 'All' || selectedSeverity !== 'All';

  return (
    <div className="bg-white border border-gray-200 rounded-[16px] p-5 shadow-sm space-y-4 font-sans w-full">
      <div className="flex items-center justify-between pb-2 border-b border-gray-100">
        <span className="text-[11px] font-semibold text-[#64748B] uppercase tracking-wider block">
          FILTER HOTSPOTS
        </span>
        {hasActiveFilters && (
          <button
            type="button"
            onClick={onClearFilters}
            className="text-[11px] font-bold text-[#DC2626] hover:underline cursor-pointer"
          >
            Reset Filters
          </button>
        )}
      </div>

      {/* Category Dropdown (44px height) */}
      <div>
        <label className="text-[11px] font-semibold text-[#64748B] block mb-1">
          Category
        </label>
        <select
          value={selectedCategory}
          onChange={(e) => setSelectedCategory(e.target.value)}
          className="bg-[#F7F8F4] border border-[#EBE6DF] text-[#0B192C] text-xs font-semibold rounded-xl px-3 h-11 focus:outline-none focus:ring-1 focus:ring-[#0B192C] transition w-full cursor-pointer"
        >
          <option value="All">All Categories</option>
          {categories.map((cat) => (
            <option key={cat} value={cat}>
              {cat.charAt(0).toUpperCase() + cat.slice(1)}
            </option>
          ))}
        </select>
      </div>

      {/* Severity Level Segmented Control (40px height) */}
      <div>
        <label className="text-[11px] font-semibold text-[#64748B] block mb-1">
          Severity Level
        </label>
        <div className="grid grid-cols-4 gap-1 bg-[#F7F8F4] p-1 rounded-xl border border-[#EBE6DF]">
          {severities.map((sev) => {
            const isSelected = selectedSeverity === sev;

            return (
              <button
                key={sev}
                type="button"
                onClick={() => setSelectedSeverity(sev)}
                className={`h-10 text-xs font-bold rounded-lg transition cursor-pointer text-center flex items-center justify-center ${
                  isSelected
                    ? 'bg-[#0B192C] text-white shadow-2xs'
                    : 'text-[#152937] hover:bg-gray-200/50'
                }`}
              >
                {sev.toUpperCase()}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
