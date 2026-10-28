import React from 'react';
import { Compass } from 'lucide-react';

export default function MumbaiViewButton({ onCenterMumbai }) {
  return (
    <div className="absolute bottom-4 right-4 z-[1000] font-sans">
      <button
        type="button"
        onClick={onCenterMumbai}
        className="bg-white/95 backdrop-blur-md hover:bg-white text-slate-800 font-bold text-xs px-3.5 py-2 rounded-xl shadow-lg border border-slate-200/80 flex items-center gap-1.5 transition active:scale-95 cursor-pointer"
        title="Re-center map on Mumbai"
      >
        <Compass className="w-4 h-4 text-slate-700" />
        <span>Mumbai View</span>
      </button>
    </div>
  );
}
