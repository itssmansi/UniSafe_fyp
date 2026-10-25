import React from 'react';

export default function AuthorityStats({ stats, title, subtitle }) {
  // Expected stats array: { label, value, color, icon }
  // colors: 'teal', 'amber', 'crimson', 'midnight'

  const colorMap = {
    teal: 'bg-unisafe-teal/10 text-unisafe-teal border-unisafe-teal/20',
    amber: 'bg-unisafe-amber/10 text-unisafe-amber border-unisafe-amber/20',
    crimson: 'bg-unisafe-crimson/10 text-unisafe-crimson border-unisafe-crimson/20',
    midnight: 'bg-unisafe-midnight-blue/10 text-unisafe-midnight-blue border-unisafe-midnight-blue/20'
  };

  return (
    <div className="mb-8">
      {(title || subtitle) && (
        <div className="mb-6">
          {title && <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">{title}</h2>}
          {subtitle && <p className="text-sm text-unisafe-dark-midnight-blue/70 mt-1">{subtitle}</p>}
        </div>
      )}
      
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        {stats.map((stat, idx) => (
          <div key={idx} className={`rounded-xl border p-4 flex flex-col justify-between ${colorMap[stat.color] || colorMap.midnight}`}>
            <div className="flex justify-between items-start mb-2">
              <span className="text-xs font-semibold uppercase tracking-wider opacity-80">{stat.label}</span>
              {stat.icon && <span className="opacity-80">{stat.icon}</span>}
            </div>
            <div className="text-3xl font-bold">{stat.value}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
