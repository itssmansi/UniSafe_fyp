import React from 'react';

export default function AuthorityEscalations({ complaints, onRowClick }) {
  // Escalations: Complaints that have reached the threshold of 10 upvotes
  const escalations = complaints
    .filter(c => c.upvote_count >= 10 && c.status !== 'resolved')
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

  if (escalations.length === 0) {
    return null;
  }

  return (
    <div className="mb-8 bg-unisafe-amber/5 border border-unisafe-amber/20 rounded-xl p-6">
      <div className="flex items-center gap-3 mb-6">
        <div className="p-2 bg-unisafe-amber/20 rounded-lg text-unisafe-amber">
          <svg className="w-5 h-5 animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
        </div>
        <div>
          <h3 className="text-xl font-bold tracking-tight text-unisafe-amber">Community Escalations</h3>
          <p className="text-sm text-unisafe-amber/80">These complaints have exceeded the community verification threshold.</p>
        </div>
      </div>
      
      <div className="space-y-3">
        {escalations.map(comp => (
          <div 
            key={comp.id}
            onClick={() => onRowClick(comp)}
            className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 bg-unisafe-white p-4 rounded-lg shadow-sm border border-unisafe-amber/20 hover:border-unisafe-amber/50 cursor-pointer transition-colors"
          >
            <div className="flex-1">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-xs font-bold text-unisafe-amber bg-unisafe-amber/10 px-2 py-0.5 rounded">ESCALATED</span>
                <span className="text-sm font-semibold text-unisafe-midnight-blue truncate">{comp.title}</span>
              </div>
              <p className="text-xs text-unisafe-dark-midnight-blue/60">{comp.category} • {comp.address}</p>
            </div>
            
            <div className="flex items-center justify-between sm:justify-end gap-6 w-full sm:w-auto border-t sm:border-t-0 border-unisafe-smoke-white pt-3 sm:pt-0 mt-3 sm:mt-0">
              <div className="text-center sm:text-right">
                <p className="text-[10px] font-semibold text-unisafe-dark-midnight-blue/50 uppercase tracking-wider">Support</p>
                <p className="text-sm font-bold text-unisafe-teal">{comp.upvote_count} Verified</p>
              </div>
              <div className="text-center sm:text-right">
                <p className="text-[10px] font-semibold text-unisafe-dark-midnight-blue/50 uppercase tracking-wider">Status</p>
                <p className="text-sm font-bold text-unisafe-midnight-blue capitalize">{(comp.status || 'pending').replace('_', ' ')}</p>
              </div>
              <button className="hidden sm:block text-unisafe-amber bg-unisafe-amber/10 hover:bg-unisafe-amber hover:text-unisafe-white p-2 rounded-lg transition-colors">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
