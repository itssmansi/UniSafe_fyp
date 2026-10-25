import React from 'react';

export default function AuthorityPriorityList({ complaints, onRowClick }) {
  // Filter for priority/urgent complaints: Critical category, status not resolved
  const priorities = complaints
    .filter(c => c.status !== 'resolved' && (c.upvote_count >= 5 || c.category?.toLowerCase().match(/assault|missing|damage|critical|urgent/)))
    .sort((a, b) => b.upvote_count - a.upvote_count)
    .slice(0, 4); // Top 4

  if (priorities.length === 0) {
    return null;
  }

  return (
    <div className="mb-8">
      <h3 className="text-xl font-bold tracking-tight text-unisafe-midnight-blue mb-4">Urgent Attention Required</h3>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {priorities.map(comp => (
          <div 
            key={comp.id} 
            onClick={() => onRowClick(comp)}
            className="group bg-unisafe-white border-l-4 border-l-unisafe-crimson border border-unisafe-smoke-white/80 rounded-r-xl p-5 shadow-sm hover:shadow-md cursor-pointer transition-all hover:bg-unisafe-crimson/5"
          >
            <div className="flex justify-between items-start mb-3">
              <span className="px-2 py-0.5 bg-unisafe-crimson/10 text-unisafe-crimson text-[10px] font-bold uppercase tracking-wider rounded">Critical Priority</span>
              <span className="text-xs font-medium text-unisafe-dark-midnight-blue/50">
                {new Date(comp.created_at).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
              </span>
            </div>
            
            <h4 className="font-semibold text-unisafe-midnight-blue mb-1 line-clamp-1 group-hover:text-unisafe-crimson transition-colors">
              {comp.title}
            </h4>
            
            <p className="text-xs text-unisafe-dark-midnight-blue/70 mb-4 line-clamp-1 flex items-center gap-1">
              <svg className="w-3.5 h-3.5 text-unisafe-amber" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
              {comp.address || 'Location Unspecified'}
            </p>
            
            <div className="flex justify-between items-center pt-3 border-t border-unisafe-smoke-white/60">
              <div className="flex items-center gap-1.5">
                <svg className="w-4 h-4 text-unisafe-teal" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" /></svg>
                <span className="text-xs font-bold text-unisafe-midnight-blue/80">{comp.upvote_count} Upvotes</span>
              </div>
              <button className="text-xs font-semibold text-unisafe-midnight-blue bg-unisafe-smoke-white px-3 py-1 rounded-md group-hover:bg-unisafe-midnight-blue group-hover:text-unisafe-white transition-colors">
                Take Action
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
