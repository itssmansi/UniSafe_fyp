import React from 'react';
import { useUserRole } from '../../hooks/useUserRole';

export default function HeatmapHeader() {
  const { isAuthority } = useUserRole();

  return (
    <div className="w-full flex items-center justify-between p-4 md:mb-2 max-w-7xl mx-auto font-sans relative">
      <a href="/" className="p-2 hover:bg-gray-200 rounded-full transition-colors flex items-center gap-1 text-sm font-medium text-gray-700 z-10">
        <svg className="w-5 h-5 text-gray-900" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
        </svg>
        <span className="hidden sm:inline">Home</span>
      </a>
      
      <div className="absolute left-1/2 -translate-x-1/2 text-center pointer-events-none">
        <h1 className="text-[18px] md:text-[24px] font-bold text-gray-900">
          Civic Risk Heatmap
        </h1>
      </div>

      <div className="flex items-center gap-2 z-10">
        <span className="w-2 h-2 rounded-full bg-[#10B981] animate-pulse"></span>
        <span className="text-xs font-medium text-gray-500 hidden sm:inline">
          {isAuthority ? 'Authority Mode' : 'Read-Only'}
        </span>
      </div>
    </div>
  );
}
