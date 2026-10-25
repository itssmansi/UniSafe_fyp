import React from 'react';

export default function AuthorityComplaintPipeline({ complaints }) {
  const isNew = (c) => c.status === 'pending' && new Date(c.created_at) > new Date(Date.now() - 24 * 60 * 60 * 1000);
  
  const pipeline = [
    { id: 'pending', label: 'PENDING', count: complaints.filter(c => c.status === 'pending').length, color: 'text-unisafe-amber', bg: 'bg-unisafe-amber/10', border: 'border-unisafe-amber/20' },
    { id: 'in_progress', label: 'IN PROGRESS', count: complaints.filter(c => c.status === 'in_progress').length, color: 'text-unisafe-white', bg: 'bg-unisafe-midnight-blue', border: 'border-unisafe-midnight-blue' },
    { id: 'resolved', label: 'RESOLVED', count: complaints.filter(c => c.status === 'resolved').length, color: 'text-unisafe-teal', bg: 'bg-unisafe-teal/10', border: 'border-unisafe-teal/20' }
  ];

  return (
    <div className="bg-unisafe-white border border-unisafe-smoke-white/50 rounded-xl p-6 shadow-sm mb-8">
      <h3 className="text-lg font-semibold tracking-tight text-unisafe-midnight-blue mb-6">Complaint Pipeline</h3>
      <div className="flex flex-col md:flex-row items-center gap-4 w-full">
        {pipeline.map((stage, idx) => (
          <React.Fragment key={stage.id}>
            <div className={`flex-1 w-full md:w-auto p-4 rounded-lg border flex flex-col items-center justify-center text-center ${stage.bg} ${stage.border}`}>
              <span className={`text-xs font-bold uppercase tracking-wider mb-2 ${stage.color}`}>{stage.label}</span>
              <span className={`text-3xl font-black ${stage.color}`}>{stage.count}</span>
            </div>
            {idx < pipeline.length - 1 && (
              <div className="hidden md:flex text-unisafe-smoke-white/80 shrink-0">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 5l7 7-7 7" /></svg>
              </div>
            )}
            {idx < pipeline.length - 1 && (
              <div className="flex md:hidden text-unisafe-smoke-white/80 shrink-0 py-1">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" /></svg>
              </div>
            )}
          </React.Fragment>
        ))}
      </div>
    </div>
  );
}
