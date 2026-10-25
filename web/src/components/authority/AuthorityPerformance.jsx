import React from 'react';

export default function AuthorityPerformance() {
  // Mock data for weekly resolution performance
  const data = [
    { day: 'Mon', count: 12, height: 'h-24' },
    { day: 'Tue', count: 19, height: 'h-36' },
    { day: 'Wed', count: 15, height: 'h-28' },
    { day: 'Thu', count: 22, height: 'h-40' },
    { day: 'Fri', count: 28, height: 'h-48' },
    { day: 'Sat', count: 14, height: 'h-28' },
    { day: 'Sun', count: 8, height: 'h-16' },
  ];

  return (
    <div className="bg-unisafe-white border border-unisafe-smoke-white/50 rounded-xl p-6 shadow-sm mb-8">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6">
        <div>
          <h3 className="text-lg font-semibold tracking-tight text-unisafe-midnight-blue">Response Performance</h3>
          <p className="text-sm text-unisafe-dark-midnight-blue/60">Complaints resolved this week</p>
        </div>
        <div className="mt-4 sm:mt-0 px-3 py-1 bg-unisafe-teal/10 text-unisafe-teal rounded-full text-sm font-medium border border-unisafe-teal/20">
          +14% vs Last Week
        </div>
      </div>
      
      <div className="h-56 flex items-end justify-between gap-2 pt-8 border-b border-unisafe-smoke-white relative">
        {/* Y-axis grid lines (visual only) */}
        <div className="absolute inset-0 flex flex-col justify-between pb-8 z-0 opacity-20 pointer-events-none">
          <div className="w-full border-t border-unisafe-dark-midnight-blue border-dashed"></div>
          <div className="w-full border-t border-unisafe-dark-midnight-blue border-dashed"></div>
          <div className="w-full border-t border-unisafe-dark-midnight-blue border-dashed"></div>
        </div>
        
        {data.map((d, i) => (
          <div key={i} className="flex flex-col items-center w-full z-10 group relative">
            {/* Tooltip */}
            <div className="absolute -top-10 opacity-0 group-hover:opacity-100 transition-opacity bg-unisafe-midnight-blue text-unisafe-white text-xs font-bold px-2 py-1 rounded shadow pointer-events-none">
              {d.count} resolved
            </div>
            
            <div className={`w-full max-w-[40px] bg-unisafe-teal/80 hover:bg-unisafe-teal transition-all rounded-t-sm ${d.height}`}></div>
            <span className="text-xs font-medium text-unisafe-dark-midnight-blue/60 mt-2">{d.day}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
