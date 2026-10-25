import React from 'react';

export default function AuthorityKpiCards({ stats }) {
  // stats: { label, value, color, description, trend }
  // colors: 'teal', 'amber', 'crimson', 'midnight'

  const colorConfig = {
    teal: { bg: 'bg-unisafe-teal/10', border: 'border-unisafe-teal/20', text: 'text-unisafe-teal', icon: 'M5 13l4 4L19 7' },
    amber: { bg: 'bg-unisafe-amber/10', border: 'border-unisafe-amber/20', text: 'text-unisafe-amber', icon: 'M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' },
    crimson: { bg: 'bg-unisafe-crimson/10', border: 'border-unisafe-crimson/20', text: 'text-unisafe-crimson', icon: 'M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' },
    midnight: { bg: 'bg-unisafe-smoke-white', border: 'border-unisafe-smoke-white/50', text: 'text-unisafe-midnight-blue', icon: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' }
  };

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      {stats.map((stat, idx) => {
        const conf = colorConfig[stat.color] || colorConfig.midnight;
        return (
          <div key={idx} className={`rounded-xl border p-5 shadow-sm bg-unisafe-white flex flex-col justify-between transition-all hover:shadow-md ${conf.border}`}>
            <div className="flex justify-between items-start mb-4">
              <h3 className="text-sm font-semibold tracking-tight text-unisafe-dark-midnight-blue/70">{stat.label}</h3>
              <div className={`p-2 rounded-full ${conf.bg} ${conf.text}`}>
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d={conf.icon} />
                </svg>
              </div>
            </div>
            <div>
              <div className="text-3xl font-bold text-unisafe-midnight-blue tracking-tight">{stat.value}</div>
              {stat.description && (
                <p className={`text-xs mt-1 ${stat.trend === 'up' ? 'text-unisafe-teal' : stat.trend === 'down' ? 'text-unisafe-crimson' : 'text-unisafe-dark-midnight-blue/50'}`}>
                  {stat.trend === 'up' && '↑ '}
                  {stat.trend === 'down' && '↓ '}
                  {stat.description}
                </p>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
