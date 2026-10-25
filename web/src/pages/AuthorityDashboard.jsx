import React, { useState, useEffect } from 'react';
import { supabase } from '../services/supabase';
import { getAuthorityProfile, getComplaints, getNotifications, markNotificationRead } from '../services/authorityService';
import AuthoritySidebar from '../components/authority/AuthoritySidebar';
import AuthorityHeader from '../components/authority/AuthorityHeader';
import PoliceDashboard from '../components/authority/PoliceDashboard';
import BMCDashboard from '../components/authority/BMCDashboard';
import AuthorityNotifications from '../components/authority/AuthorityNotifications';
import AuthorityComplaintDetails from '../components/authority/AuthorityComplaintDetails';
import AuthorityComplaintTable from '../components/authority/AuthorityComplaintTable';
import AuthorityEscalations from '../components/authority/AuthorityEscalations';
import AuthorityPerformance from '../components/authority/AuthorityPerformance';
import InteractiveMap from '../screens/interactive-map/InteractiveMap';
import KanbanBoard from '../screens/kanban-board/KanbanBoard';

export default function AuthorityDashboard() {
  const [authority, setAuthority] = useState(null);
  const [complaints, setComplaints] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  
  const [activeTab, setActiveTab] = useState('overview'); // overview, complaints, map, heatmap, notifications, profile
  const [selectedComplaint, setSelectedComplaint] = useState(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    async function loadData() {
      try {
        const profile = await getAuthorityProfile();
        if (profile) {
          setAuthority(profile);
          const [comps, notifs] = await Promise.all([
            getComplaints(profile),
            getNotifications(profile.id)
          ]);
          setComplaints(comps);
          setNotifications(notifs);
        }
      } catch (err) {
        console.error("Dashboard init error:", err);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, []);

  const handleLogout = async () => {
    localStorage.removeItem('unisafe_authority');
    localStorage.removeItem('user');
    await supabase.auth.signOut();
    window.location.href = '/authority/login';
  };

  const handleUpdateComplaint = (complaintId, newStatus) => {
    setComplaints(prev => prev.map(c => c.id === complaintId ? { ...c, status: newStatus } : c));
    if (selectedComplaint?.id === complaintId) {
      setSelectedComplaint(prev => ({ ...prev, status: newStatus }));
    }
  };

  const handleMarkNotificationRead = async (notifId) => {
    await markNotificationRead(notifId);
    setNotifications(prev => prev.filter(n => n.id !== notifId));
  };

  const handleNotificationClick = (notif) => {
    if (notif.type === 'VIEW_ALL') {
      setActiveTab('notifications');
      return;
    }
    // TODO: In a real backend, notif would include `complaint_id`.
    // For now, we try to match complaint title from notification body/title.
    const matchedComplaint = complaints.find(c => notif.body?.includes(c.title) || notif.title?.includes(c.title));
    if (matchedComplaint) {
      setSelectedComplaint(matchedComplaint);
    } else {
      console.log("Could not link notification to complaint, open assignments tab instead.");
      setActiveTab('assignments');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-unisafe-smoke-white/20 flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-unisafe-teal border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  // Determine which dashboard variant to show
  const isPolice = authority?.department?.toLowerCase().includes('police');
  const isBMC = authority?.department?.toLowerCase().includes('bmc') || authority?.department?.toLowerCase().includes('municipal');

  return (
    <div className="flex h-screen bg-[#F7F8F4] overflow-hidden font-sans">
      
      {/* Mobile Sidebar Overlay */}
      {mobileMenuOpen && (
        <div 
          className="fixed inset-0 bg-unisafe-midnight-blue/50 z-40 md:hidden" 
          onClick={() => setMobileMenuOpen(false)}
        />
      )}
      
      {/* Sidebar Wrapper (handles mobile translation) */}
      <div className={`fixed inset-y-0 left-0 z-50 transform transition-transform duration-300 md:relative md:translate-x-0 ${mobileMenuOpen ? 'translate-x-0' : '-translate-x-full'}`}>
        <AuthoritySidebar 
          activeTab={activeTab} 
          setActiveTab={(tab) => { setActiveTab(tab); setMobileMenuOpen(false); }} 
          authority={authority} 
          onLogout={handleLogout} 
        />
      </div>

      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        <AuthorityHeader 
          authority={authority} 
          toggleMobileMenu={() => setMobileMenuOpen(true)} 
          notifications={notifications}
          onMarkRead={handleMarkNotificationRead}
          onNotificationClick={handleNotificationClick}
        />
        
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
          {activeTab === 'overview' && (
            isPolice ? (
              <PoliceDashboard complaints={complaints} onRowClick={setSelectedComplaint} notifications={notifications} onNotificationClick={handleNotificationClick} />
            ) : isBMC ? (
              <BMCDashboard complaints={complaints} onRowClick={setSelectedComplaint} notifications={notifications} onNotificationClick={handleNotificationClick} />
            ) : (
              // Generic Fallback
              <PoliceDashboard complaints={complaints} onRowClick={setSelectedComplaint} notifications={notifications} onNotificationClick={handleNotificationClick} />
            )
          )}

          {activeTab === 'assignments' && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
              <div className="mb-6">
                <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">My Assignments</h2>
                <p className="text-sm text-unisafe-dark-midnight-blue/70">Complaints directly assigned to you.</p>
              </div>
              <AuthorityComplaintTable complaints={complaints.filter(c => c.assigned_authority_id === authority?.id || !c.assigned_authority_id)} onRowClick={setSelectedComplaint} />
            </div>
          )}

          {activeTab === 'escalations' && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-500">
              <div className="mb-6">
                <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">All Escalations</h2>
                <p className="text-sm text-unisafe-dark-midnight-blue/70">Complaints that have crossed the community threshold.</p>
              </div>
              <AuthorityEscalations complaints={complaints} onRowClick={setSelectedComplaint} />
            </div>
          )}

          {activeTab === 'performance' && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-4xl mx-auto">
              <div className="mb-6">
                <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">Department Performance</h2>
                <p className="text-sm text-unisafe-dark-midnight-blue/70">Analytics and resolution metrics.</p>
              </div>
              <AuthorityPerformance />
            </div>
          )}

          {activeTab === 'notifications' && (
            <AuthorityNotifications 
              authority={authority} 
              notifications={notifications}
              onMarkRead={handleMarkNotificationRead}
              onNotificationClick={handleNotificationClick}
            />
          )}

          {/* Integration placeholders for teammates */}
          {activeTab === 'map' && (
            <div className="w-full h-full rounded-2xl overflow-hidden shadow-sm border border-slate-200 relative [&>div]:!h-full" style={{ minHeight: '600px' }}>
              <InteractiveMap />
            </div>
          )}
          
          {activeTab === 'heatmap' && (
            <div className="flex flex-col items-center justify-center h-full border-2 border-dashed border-unisafe-smoke-white/60 rounded-2xl bg-unisafe-white p-12 text-center animate-in fade-in duration-500">
              <svg className="w-16 h-16 text-unisafe-teal/40 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" /></svg>
              <h3 className="text-xl font-bold text-unisafe-midnight-blue tracking-tight mb-2">
                Heatmap Integration Module
              </h3>
              <p className="text-unisafe-dark-midnight-blue/60 max-w-md">
                This area is reserved for the heatmap component. Your teammates can easily drop their React component right here without breaking the dashboard layout!
              </p>
            </div>
          )}
          
          {activeTab === 'kanban' && (
            <div className="w-full h-full rounded-2xl overflow-hidden shadow-sm border border-slate-200 relative" style={{ minHeight: '600px' }}>
              <KanbanBoard />
            </div>
          )}
          
          {activeTab === 'profile' && (
            <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-2xl mx-auto">
              <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue mb-6">Authority Profile</h2>
              <div className="bg-unisafe-white p-6 rounded-xl border border-unisafe-smoke-white/50 shadow-sm space-y-4">
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-1">Name</p>
                  <p className="font-medium text-unisafe-midnight-blue text-lg">{authority?.name}</p>
                </div>
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-1">Department</p>
                  <p className="font-medium text-unisafe-midnight-blue">{authority?.department}</p>
                </div>
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-1">Jurisdiction</p>
                  <p className="font-medium text-unisafe-midnight-blue">{authority?.jurisdiction}</p>
                </div>
                <div>
                  <p className="text-sm font-semibold uppercase tracking-wider text-unisafe-dark-midnight-blue/50 mb-1">Phone / ID</p>
                  <p className="font-medium text-unisafe-midnight-blue">{authority?.phone || 'Not provided'}</p>
                </div>
              </div>
            </div>
          )}

        </main>
      </div>

      {/* Details Slide-over */}
      <AuthorityComplaintDetails 
        complaint={selectedComplaint} 
        authority={authority} 
        onClose={() => setSelectedComplaint(null)} 
        onUpdate={handleUpdateComplaint}
      />
    </div>
  );
}
