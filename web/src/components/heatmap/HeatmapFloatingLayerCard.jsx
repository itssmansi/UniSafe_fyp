import React from 'react';
import { ChevronUp, ChevronDown } from 'lucide-react';

export default function HeatmapFloatingLayerCard({
  categoryHierarchy = { totalCount: 0, mainCategories: {}, subCategoriesByMain: {} },
  selectedCategory = 'Infrastructure',
  setSelectedCategory,
  selectedSubCategory = 'All',
  setSelectedSubCategory,
  department = null,
  isExpanded = true,
  setIsExpanded,
}) {
  const isPolice = department?.toLowerCase().includes('police');
  const isBMC =
    department?.toLowerCase().includes('bmc') ||
    department?.toLowerCase().includes('municipal');

  // Available main categories based on role
  const mainCategoriesList = isPolice
    ? ['Safety', 'Missing Persons']
    : isBMC
    ? ['Infrastructure', 'Sanitation', 'Greenery']
    : ['Infrastructure', 'Sanitation', 'Safety', 'Greenery'];

  // Current subcategories for the selected main category
  const activeMainCat =
    selectedCategory === 'All' ? mainCategoriesList[0] : selectedCategory;

  const subCategoriesObj = categoryHierarchy.subCategoriesByMain?.[activeMainCat] || {};
  const subCategoryEntries = Object.entries(subCategoriesObj);

  // Fallback defaults if category has 0 in database so the officer can still explore types
  const defaultSubCategories = {
    Infrastructure: [
      'Drainage',
      'Water Supply',
      'Roads & Potholes',
      'Streetlights',
      'Water Logging',
      'General Infrastructure',
    ],
    Sanitation: [
      'Garbage Scattered on Road',
      'Public Washrooms',
      'Garbage Dumping',
      'Waste Collection',
    ],
    Greenery: [
      'Encroachment on Green Spaces',
      'Tree Trimming / Fallen Trees',
      'Park & Landscape Maintenance',
    ],
    Safety: [
      'Theft / Robbery',
      'Assault / Violence',
      'Harassment / Eve-Teasing',
      'Child Safety Concern',
      'Electrical Hazard',
      'Illegal Parking',
      'Women Safety',
    ],
    'Missing Persons': ['Active Cases', 'Sightings Reported', 'Resolved'],
  };

  const currentDisplaySubCategories =
    subCategoryEntries.length > 0
      ? subCategoryEntries.map(([name, count]) => ({ name, count }))
      : (defaultSubCategories[activeMainCat] || []).map((name) => ({
          name,
          count: 0,
        }));

  // Total count for current selected category
  const selectedCatCount =
    selectedCategory === 'All'
      ? categoryHierarchy.totalCount
      : categoryHierarchy.mainCategories?.[selectedCategory] || 0;

  // Dot color lookup
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

  const currentColor = getCategoryColor(activeMainCat);

  return (
    <div className="absolute top-4 left-14 sm:left-16 z-[1000] font-sans transition-all">
      {/* Collapsed Pill Button / Header */}
      <button
        type="button"
        onClick={() => setIsExpanded(!isExpanded)}
        className="bg-white/95 backdrop-blur-md shadow-lg border border-slate-200/80 rounded-full px-3.5 py-1.5 flex items-center gap-2 hover:bg-white text-slate-800 transition active:scale-95 cursor-pointer"
        title="Toggle Layer Details"
      >
        <span
          className="w-2.5 h-2.5 rounded-full inline-block"
          style={{ backgroundColor: currentColor }}
        />
        <span className="text-xs font-bold tracking-tight">
          Layer:{' '}
          <span className="font-semibold text-slate-700">
            {selectedCategory === 'All' ? 'All Categories' : selectedCategory}
          </span>
        </span>
        <span className="bg-slate-100 text-slate-600 text-[11px] font-bold px-2 py-0.5 rounded-full">
          {selectedCatCount}
        </span>
        {isExpanded ? (
          <ChevronUp className="w-3.5 h-3.5 text-slate-400" />
        ) : (
          <ChevronDown className="w-3.5 h-3.5 text-slate-400" />
        )}
      </button>

      {/* Expanded Floating Panel */}
      {isExpanded && (
        <div className="mt-2 bg-white/98 backdrop-blur-md rounded-2xl shadow-2xl border border-slate-100 p-4 w-[330px] sm:w-[350px] max-w-[calc(100vw-32px)] text-slate-800 space-y-4 animate-in fade-in zoom-in-95 duration-200">
          {/* Section 1: Main Categories */}
          <div>
            <div className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mb-2">
              MAIN CATEGORIES
            </div>

            {/* All Categories Option */}
            <button
              type="button"
              onClick={() => {
                setSelectedCategory('All');
                setSelectedSubCategory('All');
              }}
              className={`w-full flex items-center justify-between px-3 py-1.5 rounded-full text-xs font-semibold mb-2 transition cursor-pointer ${
                selectedCategory === 'All'
                  ? 'bg-slate-900 text-white shadow-xs'
                  : 'bg-slate-50 text-slate-700 hover:bg-slate-100'
              }`}
            >
              <div className="flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-slate-900 inline-block" />
                <span>All Categories</span>
              </div>
              <span
                className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${
                  selectedCategory === 'All'
                    ? 'bg-slate-800 text-white'
                    : 'bg-slate-200/70 text-slate-600'
                }`}
              >
                {categoryHierarchy.totalCount}
              </span>
            </button>

            {/* Main Categories Pills Grid */}
            <div className="grid grid-cols-2 gap-1.5">
              {mainCategoriesList.map((cat) => {
                const isSelected = selectedCategory === cat;
                const count = categoryHierarchy.mainCategories?.[cat] || 0;
                const color = getCategoryColor(cat);

                return (
                  <button
                    key={cat}
                    type="button"
                    onClick={() => {
                      setSelectedCategory(cat);
                      setSelectedSubCategory('All');
                    }}
                    className={`flex items-center justify-between px-2.5 py-1.5 rounded-xl text-xs font-semibold transition cursor-pointer border ${
                      isSelected
                        ? 'bg-red-500 border-red-500 text-white shadow-xs'
                        : 'bg-white border-slate-100 text-slate-700 hover:bg-slate-50'
                    }`}
                    style={
                      isSelected
                        ? { backgroundColor: color, borderColor: color }
                        : {}
                    }
                  >
                    <div className="flex items-center gap-1.5 truncate">
                      <span
                        className="w-2 h-2 rounded-full shrink-0"
                        style={{
                          backgroundColor: isSelected ? 'white' : color,
                        }}
                      />
                      <span className="truncate">{cat}</span>
                    </div>
                    <span
                      className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full ml-1 ${
                        isSelected
                          ? 'bg-white/20 text-white'
                          : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {count}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Section 2: Sub-Categories */}
          <div className="border-t border-slate-100 pt-3">
            <div className="flex items-center justify-between mb-2">
              <span className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                {activeMainCat.toUpperCase()} SUB-CATEGORIES
              </span>
              <span className="text-[10px] font-semibold text-slate-400">
                {currentDisplaySubCategories.length} types
              </span>
            </div>

            {/* All Sub-category Pill */}
            <button
              type="button"
              onClick={() => setSelectedSubCategory('All')}
              className={`w-full flex items-center justify-between px-3 py-1.5 rounded-full text-xs font-semibold mb-1.5 transition cursor-pointer ${
                selectedSubCategory === 'All'
                  ? 'bg-slate-900 text-white shadow-xs'
                  : 'bg-slate-50 text-slate-700 hover:bg-slate-100'
              }`}
            >
              <div className="flex items-center gap-2">
                <span
                  className="w-2 h-2 rounded-full"
                  style={{ backgroundColor: currentColor }}
                />
                <span>All {activeMainCat}</span>
              </div>
              <span
                className={`text-[11px] font-bold px-2 py-0.5 rounded-full ${
                  selectedSubCategory === 'All'
                    ? 'bg-slate-800 text-white'
                    : 'bg-slate-200/70 text-slate-600'
                }`}
              >
                {selectedCatCount}
              </span>
            </button>

            {/* Sub-categories List */}
            <div className="space-y-1 max-h-48 overflow-y-auto pr-1 scrollbar-thin">
              {currentDisplaySubCategories.map((sub) => {
                const isSelected = selectedSubCategory === sub.name;

                return (
                  <button
                    key={sub.name}
                    type="button"
                    onClick={() => setSelectedSubCategory(sub.name)}
                    className={`w-full flex items-center justify-between px-3 py-1 rounded-lg text-xs transition cursor-pointer ${
                      isSelected
                        ? 'bg-slate-100 font-bold text-slate-900'
                        : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900 font-medium'
                    }`}
                  >
                    <div className="flex items-center gap-2 truncate">
                      <span
                        className="w-1.5 h-1.5 rounded-full shrink-0"
                        style={{ backgroundColor: currentColor }}
                      />
                      <span className="truncate">{sub.name}</span>
                    </div>
                    <span className="text-[11px] font-semibold text-slate-400 tabular-nums ml-2">
                      {sub.count}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
