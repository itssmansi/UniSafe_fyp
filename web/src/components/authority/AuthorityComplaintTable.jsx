import React from 'react';

export default function AuthorityComplaintTable({ complaints, onRowClick }) {
  const statusColors = {
    pending: 'bg-unisafe-amber/10 text-unisafe-amber border-unisafe-amber/20',
    in_progress: 'bg-unisafe-midnight-blue/10 text-unisafe-midnight-blue border-unisafe-midnight-blue/20',
    resolved: 'bg-unisafe-teal/10 text-unisafe-teal border-unisafe-teal/20',
    rejected: 'bg-unisafe-crimson/10 text-unisafe-crimson border-unisafe-crimson/20',
  };

  if (!complaints || complaints.length === 0) {
    return (
      <div className="bg-unisafe-white border border-unisafe-smoke-white/50 rounded-xl p-8 text-center">
        <p className="text-unisafe-dark-midnight-blue/50">No complaints found.</p>
      </div>
    );
  }

  return (
    <div className="bg-unisafe-white rounded-xl shadow-sm border border-unisafe-smoke-white/50 overflow-hidden">
      {/* Mobile Card View (hidden on md+) */}
      <div className="md:hidden divide-y divide-unisafe-smoke-white/50">
        {complaints.map((comp) => {
          const isCritical = comp.upvote_count >= 10 || comp.category?.toLowerCase().match(/assault|missing|critical/);
          return (
            <div key={comp.id} className={`p-4 ${isCritical ? 'bg-unisafe-crimson/5' : ''}`}>
              <div className="flex justify-between items-start mb-2">
                <div className="font-medium text-unisafe-midnight-blue flex items-center gap-2">
                  {isCritical && <span className="w-2 h-2 rounded-full bg-unisafe-crimson shrink-0"></span>}
                  <span className="line-clamp-1">{comp.title}</span>
                </div>
                <span className={`px-2 py-0.5 text-[10px] font-bold uppercase rounded-sm border ${statusColors[comp.status] || statusColors.pending}`}>
                  {(comp.status || 'pending').replace('_', ' ')}
                </span>
              </div>
              <div className="text-xs text-unisafe-dark-midnight-blue/70 space-y-1 mb-3">
                <p><strong>Category:</strong> {comp.category || 'General'}</p>
                <p className="truncate"><strong>Location:</strong> {comp.address || (comp.latitude && comp.longitude ? `${comp.latitude.toFixed(4)}, ${comp.longitude.toFixed(4)}` : 'Unknown')}</p>
                <div className="flex items-center gap-1 font-medium text-unisafe-teal">
                  <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" /></svg>
                  {comp.upvote_count || 0} Upvotes
                </div>
              </div>
              <button 
                onClick={() => onRowClick(comp)}
                className="w-full text-center text-sm font-semibold text-unisafe-teal bg-unisafe-teal/10 hover:bg-unisafe-teal hover:text-unisafe-white py-2 rounded-lg transition-colors"
              >
                View Details
              </button>
            </div>
          );
        })}
      </div>

      {/* Desktop Table View (hidden on mobile) */}
      <div className="hidden md:block overflow-x-auto">
        <table className="w-full text-left text-sm">
          <thead className="bg-unisafe-smoke-white/30 text-unisafe-dark-midnight-blue/60 text-xs uppercase tracking-wider border-b border-unisafe-smoke-white/50">
            <tr>
              <th className="px-6 py-4 font-semibold">Complaint</th>
              <th className="px-6 py-4 font-semibold">Category</th>
              <th className="px-6 py-4 font-semibold">Location</th>
              <th className="px-6 py-4 font-semibold">Status</th>
              <th className="px-6 py-4 font-semibold">Support</th>
              <th className="px-6 py-4 font-semibold">Created</th>
              <th className="px-6 py-4 font-semibold text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-unisafe-smoke-white/50">
            {complaints.map((comp) => {
              const isCritical = comp.upvote_count >= 10 || comp.category?.toLowerCase().match(/assault|missing|critical/);
              
              return (
                <tr 
                  key={comp.id} 
                  className={`hover:bg-unisafe-smoke-white transition-colors ${isCritical ? 'bg-unisafe-crimson/5' : ''}`}
                >
                  <td className="px-6 py-4">
                    <div className="font-medium text-unisafe-midnight-blue flex items-center gap-2">
                      {isCritical && <span className="w-2 h-2 rounded-full bg-unisafe-crimson" title="Critical Priority"></span>}
                      {comp.title}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-unisafe-dark-midnight-blue/70">{comp.category || 'General'}</td>
                  <td className="px-6 py-4 text-unisafe-dark-midnight-blue/70 max-w-[200px] truncate" title={comp.address || (comp.latitude && comp.longitude ? `${comp.latitude}, ${comp.longitude}` : '')}>
                    {comp.address || (comp.latitude && comp.longitude ? `${comp.latitude.toFixed(4)}, ${comp.longitude.toFixed(4)}` : 'Location unknown')}
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 text-xs font-bold uppercase rounded-sm border ${statusColors[comp.status] || statusColors.pending}`}>
                      {(comp.status || 'pending').replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-1.5 font-medium text-unisafe-midnight-blue/80">
                      <svg className="w-4 h-4 text-unisafe-teal" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" /></svg>
                      {comp.upvote_count || 0}
                    </div>
                  </td>
                  <td className="px-6 py-4 text-unisafe-dark-midnight-blue/70 text-xs">
                    {new Date(comp.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button 
                      onClick={() => onRowClick(comp)}
                      className="text-unisafe-midnight-blue bg-unisafe-smoke-white hover:text-unisafe-white font-medium px-3 py-1.5 rounded-lg hover:bg-unisafe-midnight-blue transition-colors text-xs"
                    >
                      View
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
