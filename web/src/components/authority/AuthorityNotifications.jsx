import React from 'react';
import AuthorityNotificationItem from './AuthorityNotificationItem';

export default function AuthorityNotifications({ authority, notifications = [], onMarkRead, onNotificationClick }) {
  const handleMarkAllRead = () => {
    notifications.filter(n => !n.is_read).forEach(n => onMarkRead(n.id));
  };

  const unreadCount = notifications.filter(n => !n.is_read).length;

  return (
    <div className="max-w-4xl mx-auto animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-unisafe-midnight-blue">Notifications Center</h2>
          <p className="text-sm text-unisafe-dark-midnight-blue/70">
            {unreadCount > 0 ? `You have ${unreadCount} unread alert${unreadCount === 1 ? '' : 's'}.` : "You're all caught up."}
          </p>
        </div>
        {unreadCount > 0 && (
          <button 
            onClick={handleMarkAllRead}
            className="text-sm font-semibold text-unisafe-teal hover:text-unisafe-teal/80 bg-unisafe-teal/5 hover:bg-unisafe-teal/10 px-4 py-2 rounded-lg transition-colors"
          >
            Mark all as read
          </button>
        )}
      </div>

      <div className="space-y-3">
        {notifications.length === 0 ? (
          <div className="text-center py-16 bg-unisafe-white rounded-xl border border-unisafe-smoke-white/50 shadow-sm">
            <svg className="w-16 h-16 text-unisafe-midnight-blue/20 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg>
            <p className="text-unisafe-dark-midnight-blue/80 font-bold text-lg">No notifications</p>
            <p className="text-sm text-unisafe-dark-midnight-blue/50 mt-1">When you receive alerts, they will appear here.</p>
          </div>
        ) : (
          notifications.map(notif => (
            <AuthorityNotificationItem 
              key={notif.id} 
              notification={notif} 
              onMarkRead={onMarkRead}
              onClick={onNotificationClick}
            />
          ))
        )}
      </div>
    </div>
  );
}
