import React, { useState } from 'react';
import { updateComplaintStatus } from '../../services/authorityService';

export default function AuthorityComplaintDetails({ complaint, authority, onClose, onUpdate }) {
  const [updating, setUpdating] = useState(false);

  if (!complaint) return null;

  const isCritical = complaint.upvote_count >= 10 || complaint.category?.toLowerCase().includes('assault') || complaint.category?.toLowerCase().includes('missing');

  const handleStatusChange = async (newStatus) => {
    if (newStatus === complaint.status) return;
    setUpdating(true);
    try {
      await updateComplaintStatus(complaint.id, authority.id, newStatus);
      if (onUpdate) onUpdate(complaint.id, newStatus);
    } catch (err) {
      alert("Failed to update status: " + err.message);
    }
    setUpdating(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-end bg-unisafe-midnight-blue/40 backdrop-blur-sm transition-opacity">
      <div className="w-full max-w-xl h-full bg-unisafe-white shadow-2xl flex flex-col animate-in slide-in-from-right duration-300">
        
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-unisafe-smoke-white/50 bg-unisafe-smoke-white/30">
          <div className="flex items-center gap-3">
            {isCritical && <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider bg-unisafe-crimson text-unisafe-white">Critical</span>}
            <h2 className="text-xl font-bold text-unisafe-midnight-blue tracking-tight">Complaint Details</h2>
          </div>
          <button onClick={onClose} className="p-2 text-unisafe-dark-midnight-blue/50 hover:bg-unisafe-smoke-white rounded-full transition-colors">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6 space-y-8">
          
          {/* Main Info */}
          <div>
            <h3 className="text-2xl font-bold text-unisafe-midnight-blue mb-2">{complaint.title}</h3>
            <div className="flex flex-wrap items-center gap-4 text-sm text-unisafe-dark-midnight-blue/70">
              <span className="flex items-center gap-1">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" /></svg>
                {complaint.category || 'General'}
              </span>
              <span className="flex items-center gap-1">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                {new Date(complaint.created_at).toLocaleString()}
              </span>
              <span className="flex items-center gap-1 font-medium text-unisafe-teal">
                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M14 10h4.764a2 2 0 011.789 2.894l-3.5 7A2 2 0 0115.263 21h-4.017c-.163 0-.326-.02-.485-.06L7 20m7-10V5a2 2 0 00-2-2h-.095c-.5 0-.905.405-.905.905 0 .714-.211 1.412-.608 2.006L7 11v9m7-10h-2M7 20H5a2 2 0 01-2-2v-6a2 2 0 012-2h2.5" /></svg>
                {complaint.upvote_count || 0} Upvotes
              </span>
            </div>
          </div>

          {/* Description */}
          <div>
            <h4 className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-2">Description</h4>
            <p className="text-unisafe-midnight-blue bg-unisafe-smoke-white/20 p-4 rounded-xl border border-unisafe-smoke-white/50 leading-relaxed">
              {complaint.description || "No description provided."}
            </p>
          </div>

          {/* Location */}
          <div>
            <h4 className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-2">Location</h4>
            <div className="flex items-start gap-3 bg-unisafe-smoke-white/20 p-4 rounded-xl border border-unisafe-smoke-white/50">
              <svg className="w-5 h-5 text-unisafe-teal shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
              <div>
                <p className="text-unisafe-midnight-blue font-medium">{complaint.address || "Location unknown"}</p>
                <p className="text-xs text-unisafe-dark-midnight-blue/50 mt-1">Lat: {complaint.latitude?.toFixed(4) || 'N/A'}, Lng: {complaint.longitude?.toFixed(4) || 'N/A'}</p>
              </div>
            </div>
          </div>

          {/* Media / Before After */}
          {complaint.image_url && (
            <div>
              <h4 className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-2">Evidence</h4>
              <div className="bg-unisafe-smoke-white/20 rounded-xl overflow-hidden border border-unisafe-smoke-white/50 relative aspect-video">
                <img src={complaint.image_url} alt="Evidence" className="w-full h-full object-cover" />
              </div>
            </div>
          )}

          {/* Resolution Info (if resolved) */}
          {complaint.status === 'resolved' && (
            <div className="bg-unisafe-teal/5 border border-unisafe-teal/20 p-5 rounded-xl">
              <div className="flex items-center gap-2 mb-4">
                <svg className="w-5 h-5 text-unisafe-teal" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                <h4 className="text-sm font-bold uppercase tracking-wider text-unisafe-teal">Resolution Details</h4>
              </div>
              
              <div className="grid grid-cols-2 gap-4 mb-4">
                <div>
                  <p className="text-[10px] font-semibold text-unisafe-teal/70 uppercase tracking-wider mb-2">Before</p>
                  <div className="aspect-video bg-unisafe-smoke-white/50 rounded-lg overflow-hidden border border-unisafe-teal/20 flex items-center justify-center">
                    {complaint.image_url ? (
                      <img src={complaint.image_url} alt="Before" className="w-full h-full object-cover" />
                    ) : (
                      <span className="text-xs text-unisafe-teal/50">No image</span>
                    )}
                  </div>
                </div>
                <div>
                  <p className="text-[10px] font-semibold text-unisafe-teal/70 uppercase tracking-wider mb-2">After</p>
                  <div className="aspect-video bg-unisafe-teal/10 rounded-lg overflow-hidden border border-unisafe-teal/30 flex items-center justify-center">
                    {/* UI Integration Point for AFTER image */}
                    {complaint.resolution_image_url ? (
                      <img src={complaint.resolution_image_url} alt="After" className="w-full h-full object-cover" />
                    ) : (
                      <div className="text-center">
                        <svg className="w-6 h-6 text-unisafe-teal/40 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                        <span className="text-xs text-unisafe-teal/60">Image pending</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <p className="text-sm text-unisafe-midnight-blue mb-3">
                {complaint.resolution_note || "Resolved successfully by authority."}
              </p>
              
              <div className="flex items-center justify-between border-t border-unisafe-teal/10 pt-3">
                <span className="text-xs font-medium text-unisafe-teal">
                  Resolved by: {complaint.resolved_by_name || 'Assigned Authority'}
                </span>
                <span className={`text-xs font-bold px-2 py-1 rounded ${complaint.verification_count > 0 ? 'bg-unisafe-teal/20 text-unisafe-teal' : 'bg-unisafe-amber/20 text-unisafe-amber'}`}>
                  {complaint.verification_count > 0 ? `${complaint.verification_count} Citizen Verified` : 'Awaiting Citizen Verification'}
                </span>
              </div>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="p-6 border-t border-unisafe-smoke-white/50 bg-unisafe-smoke-white/30 flex items-center justify-between">
          <span className="text-sm font-medium text-unisafe-dark-midnight-blue/70">Update Status:</span>
          <div className="flex gap-2">
            <button 
              onClick={() => handleStatusChange('pending')}
              disabled={updating || complaint.status === 'pending'}
              className="px-4 py-2 text-sm font-medium rounded-lg border border-unisafe-amber text-unisafe-amber hover:bg-unisafe-amber/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Pending
            </button>
            <button 
              onClick={() => handleStatusChange('in_progress')}
              disabled={updating || complaint.status === 'in_progress'}
              className="px-4 py-2 text-sm font-medium rounded-lg border border-unisafe-midnight-blue text-unisafe-midnight-blue hover:bg-unisafe-midnight-blue/10 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              In Progress
            </button>
            <button 
              onClick={() => handleStatusChange('resolved')}
              disabled={updating || complaint.status === 'resolved'}
              className="px-4 py-2 text-sm font-medium rounded-lg bg-unisafe-teal text-unisafe-white hover:bg-unisafe-teal/90 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Resolve
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
