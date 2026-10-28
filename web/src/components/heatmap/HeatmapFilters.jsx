import React from 'react';
import { ChevronDown } from 'lucide-react';

export default function HeatmapFilters({
  categoryHierarchy = { totalCount: 0, mainCategories: {}, subCategoriesByMain: {} },
  selectedCategory = 'Infrastructure',
  setSelectedCategory,
  selectedSubCategory = 'All',
  setSelectedSubCategory,
  selectedSeverity = 'All',
  setSelectedSeverity,
  onClearFilters,
  department = null,
}) {
  const isPolice = department?.toLowerCase().includes('police');
  const isBMC =
    department?.toLowerCase().includes('bmc') ||
    department?.toLowerCase().includes('municipal');

  // Permitted main categories
  const mainCategories = isPolice
    ? ['Safety', 'Missing Persons']
    : isBMC
    ? ['Infrastructure', 'Sanitation', 'Greenery']
    : ['Infrastructure', 'Sanitation', 'Safety', 'Greenery'];

  // Current active main category to look up subcategories
  const activeMainCat =
    selectedCategory === 'All' ? mainCategories[0] : selectedCategory;

  const subCategoriesObj =
    categoryHierarchy.subCategoriesByMain?.[activeMainCat] || {};
  const subCategoryEntries = Object.entries(subCategoriesObj);

  const severities = ['ALL', 'LOW', 'MEDIUM', 'HIGH'];

  const hasActiveFilters =
    selectedCategory !== (isPolice ? 'Safety' : 'Infrastructure') ||
    selectedSubCategory !== 'All' ||
    selectedSeverity !== 'All';

  return (
    <div className="bg-white border border-slate-100 rounded-[20px] p-5 shadow-xs space-y-4 font-sans w-full">
      {/* Header Row */}
      <div className="flex items-center justify-between pb-2 border-b border-slate-100">
        <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider block">
          FILTER HOTSPOTS
        </span>
        {hasActiveFilters && (
          <button
            type="button"
            onClick={onClearFilters}
            className="text-[11px] font-bold text-red-600 hover:text-red-700 hover:underline cursor-pointer transition"
          >
            Reset Filters
          </button>
        )}
      </div>

      {/* 1. Problem Category Dropdown */}
      <div>
        <label className="text-xs font-semibold text-slate-700 block mb-1.5">
          Problem Category
        </label>
        <div className="relative">
          <select
            value={selectedCategory}
            onChange={(e) => {
              setSelectedCategory(e.target.value);
              setSelectedSubCategory('All');
            }}
            className="w-full appearance-none bg-slate-50 hover:bg-slate-100/70 focus:bg-white text-xs font-semibold text-slate-800 rounded-xl px-3.5 py-2.5 border border-slate-200/80 focus:outline-none focus:ring-1 focus:ring-slate-900 transition cursor-pointer pr-9"
          >
            <option value="All">
              All Categories ({categoryHierarchy.totalCount})
            </option>
            {mainCategories.map((cat) => {
              const count = categoryHierarchy.mainCategories?.[cat] || 0;
              return (
                <option key={cat} value={cat}>
                  {cat} ({count})
                </option>
              );
            })}
          </select>
          <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
        </div>
      </div>

      {/* 2. Sub-Category Dropdown */}
      <div>
        <label className="text-xs font-semibold text-slate-700 block mb-1.5">
          Sub-Category
        </label>
        <div className="relative">
          <select
            value={selectedSubCategory}
            onChange={(e) => setSelectedSubCategory(e.target.value)}
            className="w-full appearance-none bg-slate-50 hover:bg-slate-100/70 focus:bg-white text-xs font-semibold text-slate-800 rounded-xl px-3.5 py-2.5 border border-slate-200/80 focus:outline-none focus:ring-1 focus:ring-slate-900 transition cursor-pointer pr-9"
          >
            <option value="All">
              All {activeMainCat} (
              {selectedCategory === 'All'
                ? categoryHierarchy.totalCount
                : categoryHierarchy.mainCategories?.[selectedCategory] || 0}
              )
            </option>
            {subCategoryEntries.map(([subName, subCount]) => (
              <option key={subName} value={subName}>
                {subName} ({subCount})
              </option>
            ))}
          </select>
          <ChevronDown className="w-4 h-4 text-slate-400 absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none" />
        </div>
      </div>

      {/* 3. Severity Level Segmented Control */}
      <div>
        <label className="text-xs font-semibold text-slate-700 block mb-1.5">
          Severity Level
        </label>
        <div className="grid grid-cols-4 gap-1 bg-slate-50 p-1 rounded-xl border border-slate-200/80">
          {severities.map((sev) => {
            const isSelected =
              selectedSeverity.toUpperCase() === sev.toUpperCase();
            return (
              <button
                key={sev}
                type="button"
                onClick={() =>
                  setSelectedSeverity(sev === 'ALL' ? 'All' : sev)
                }
                className={`py-2 text-[11px] font-bold rounded-lg transition cursor-pointer text-center flex items-center justify-center ${
                  isSelected
                    ? 'bg-slate-900 text-white shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50'
                }`}
              >
                {sev}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
