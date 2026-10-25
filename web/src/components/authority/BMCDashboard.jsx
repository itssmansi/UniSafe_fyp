import React from 'react';
import AuthorityKpiCards from './AuthorityKpiCards';
import AuthorityComplaintPipeline from './AuthorityComplaintPipeline';
import AuthorityPriorityList from './AuthorityPriorityList';
import AuthorityEscalations from './AuthorityEscalations';
import AuthorityPerformance from './AuthorityPerformance';
import AuthorityComplaintTable from './AuthorityComplaintTable';
import AuthorityNotificationItem from './AuthorityNotificationItem';

export default function BMCDashboard({ complaints, onRowClick, notifications = [], onNotificationClick }) {
  // BMC Stats Calculation
  const total = complaints.length;
  const priority = complaints.filter(c => c.upvote_count >= 10 || c.category?.toLowerCase().match(/damage|drainage|infrastructure/)).length;
  const pending = complaints.filter(c => c.status === 'pending').length;
  const inProgress = complaints.filter(c => c.status === 'in_progress').length;
  const resolved = complaints.filter(c => c.status === 'resolved').length;
  const escalationsCount = complaints.filter(c => c.upvote_count >= 10).length;

  const kpis = [
    { label: 'Assigned Issues', value: total, color: 'midnight', trend: 'up', description: '+5 from yesterday' },
    { label: 'Pending Assessment', value: pending, color: 'amber', trend: 'up', description: 'Requires routing' },
    { label: 'Priority / Escalated', value: priority + escalationsCount, color: 'crimson', trend: 'down', description: 'Infrastructure risks' },
    { label: 'Resolution Rate', value: '82%', color: 'teal', trend: 'up', description: 'Above 75% SLA target' },
  ];

  const recentNotifications = notifications.slice(0, 5);

  return (
    <div className="animate-in fade-in slide-in-from-bottom-4 duration-500 max-w-[1400px] mx-auto">
      <div className="mb-6">
        <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">Civic Operations Center</h2>
        <p className="text-sm text-unisafe-dark-midnight-blue/70">Monitor civic infrastructure and services assigned directly to you.</p>
      </div>
      
      <AuthorityKpiCards stats={kpis} />
      
      <AuthorityComplaintPipeline complaints={complaints} />
      
      <AuthorityEscalations complaints={complaints} onRowClick={onRowClick} />
      
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-8 mb-8">
        <div className="xl:col-span-2 flex flex-col gap-8">
          <AuthorityPriorityList complaints={complaints} onRowClick={onRowClick} />
          <AuthorityPerformance />
        </div>
        <div className="xl:col-span-1">
          <div className="mb-4 flex items-end justify-between">
            <div>
              <h3 className="text-xl font-bold tracking-tight text-unisafe-midnight-blue">Recent Notifications</h3>
              <p className="text-sm text-unisafe-dark-midnight-blue/60">System alerts</p>
            </div>
            <button 
              onClick={() => onNotificationClick && onNotificationClick({ type: 'VIEW_ALL' })}
              className="text-xs font-semibold text-unisafe-teal hover:text-unisafe-midnight-blue transition-colors pb-1"
            >
              View All
            </button>
          </div>
          
          <div className="bg-unisafe-white border border-unisafe-smoke-white/50 rounded-xl p-4 shadow-sm flex flex-col gap-3 min-h-[400px]">
            {recentNotifications.length === 0 ? (
              <div className="flex-1 flex flex-col items-center justify-center text-center p-6">
                <svg className="w-12 h-12 text-unisafe-midnight-blue/10 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg>
                <p className="text-sm font-medium text-unisafe-midnight-blue/70">No new alerts</p>
              </div>
            ) : (
              recentNotifications.map(notif => (
                <AuthorityNotificationItem 
                  key={notif.id} 
                  notification={notif} 
                  onClick={() => onNotificationClick && onNotificationClick(notif)}
                />
              ))
            )}
          </div>
        </div>
      </div>

      <div className="mb-8">
        <div className="mb-4">
          <h3 className="text-xl font-bold tracking-tight text-unisafe-midnight-blue">My Assigned Complaints</h3>
          <p className="text-sm text-unisafe-dark-midnight-blue/60">Complete assigned civic issue log</p>
        </div>
        <AuthorityComplaintTable complaints={complaints} onRowClick={onRowClick} />
      </div>
    </div>
  );
}
