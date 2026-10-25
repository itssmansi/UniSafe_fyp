import React, { useState, useRef, useEffect } from 'react';
import AuthorityNotificationItem from './AuthorityNotificationItem';

export default function AuthorityHeader({ authority, toggleMobileMenu, notifications = [], onMarkRead, onNotificationClick }) {
  const isPolice = authority?.department?.toLowerCase().includes('police');
  const badgeColor = isPolice ? 'bg-unisafe-midnight-blue text-unisafe-smoke-white' : 'bg-unisafe-amber/10 text-unisafe-amber border border-unisafe-amber/20';

  const [showDropdown, setShowDropdown] = useState(false);
  const dropdownRef = useRef(null);

  // Close dropdown on outside click
  useEffect(() => {
    function handleClickOutside(event) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setShowDropdown(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const unreadCount = notifications.filter(n => !n.is_read).length;
  const recentNotifications = notifications.slice(0, 5);

  const handleMarkAllRead = () => {
    notifications.filter(n => !n.is_read).forEach(n => onMarkRead(n.id));
    setShowDropdown(false);
  };

  return (
    <header className="bg-unisafe-white border-b border-unisafe-smoke-white/50 px-6 py-4 flex items-center justify-between sticky top-0 z-20 shadow-sm">
      <div className="flex items-center gap-4 flex-1 justify-between">
        <div className="flex items-center gap-4 w-full max-w-xl">
          {/* Mobile menu button */}
          <button onClick={toggleMobileMenu} className="md:hidden text-unisafe-midnight-blue hover:text-unisafe-teal transition-colors">
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
          </button>
          
          {/* Search Box */}
          <div className="relative w-full max-w-md hidden sm:block">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <svg className="w-4 h-4 text-unisafe-midnight-blue/50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
            </div>
            <input 
              type="text" 
              className="block w-full pl-10 pr-3 py-2 border border-unisafe-midnight-blue/20 rounded-lg leading-5 bg-unisafe-white placeholder-unisafe-midnight-blue/50 focus:outline-none focus:ring-1 focus:ring-unisafe-teal focus:border-unisafe-teal sm:text-sm transition-colors" 
              placeholder="Search complaints, insights, records..." 
            />
          </div>
        </div>

        <div className="flex items-center gap-4 sm:gap-6 shrink-0 relative">
          {/* System Status */}
          <div className="hidden lg:flex items-center gap-2 px-3 py-1 bg-unisafe-teal/10 rounded-full border border-unisafe-teal/20">
            <div className="w-2 h-2 rounded-full bg-unisafe-teal animate-pulse"></div>
            <span className="text-xs font-bold uppercase tracking-wider text-unisafe-teal">System Operational</span>
          </div>
          
          {/* Notification Bell & Popover */}
          <div ref={dropdownRef} className="relative">
            <button 
              onClick={() => setShowDropdown(!showDropdown)}
              className={`relative p-2 transition-colors rounded-lg ${showDropdown ? 'bg-unisafe-smoke-white text-unisafe-teal' : 'text-unisafe-midnight-blue hover:text-unisafe-teal hover:bg-unisafe-smoke-white/50'}`}
            >
              {unreadCount > 0 && (
                <span className="absolute top-1 right-1 flex h-4 min-w-4 items-center justify-center px-1 bg-unisafe-crimson rounded-full border-2 border-unisafe-white text-[9px] font-bold text-unisafe-white">
                  {unreadCount > 9 ? '9+' : unreadCount}
                </span>
              )}
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg>
            </button>

            {/* Dropdown Panel */}
            {showDropdown && (
              <div className="absolute right-0 mt-2 w-[calc(100vw-2rem)] sm:w-96 bg-unisafe-white rounded-xl shadow-lg border border-unisafe-smoke-white/80 z-50 overflow-hidden animate-in fade-in slide-in-from-top-2">
                <div className="px-4 py-3 border-b border-unisafe-smoke-white/60 flex items-center justify-between bg-unisafe-smoke-white/20">
                  <h3 className="font-bold text-unisafe-midnight-blue">Notifications</h3>
                  {unreadCount > 0 && (
                    <button 
                      onClick={handleMarkAllRead}
                      className="text-xs font-semibold text-unisafe-teal hover:text-unisafe-teal/80 transition-colors"
                    >
                      Mark all as read
                    </button>
                  )}
                </div>
                
                <div className="max-h-[60vh] overflow-y-auto p-2 space-y-1">
                  {recentNotifications.length === 0 ? (
                    <div className="py-8 text-center px-4">
                      <svg className="w-8 h-8 text-unisafe-midnight-blue/20 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" /></svg>
                      <p className="text-sm font-medium text-unisafe-midnight-blue">No new notifications</p>
                    </div>
                  ) : (
                    recentNotifications.map(notif => (
                      <AuthorityNotificationItem 
                        key={notif.id} 
                        notification={notif} 
                        onMarkRead={onMarkRead}
                        onClick={() => {
                          onNotificationClick(notif);
                          setShowDropdown(false);
                        }}
                      />
                    ))
                  )}
                </div>

                {notifications.length > 5 && (
                  <div className="p-2 border-t border-unisafe-smoke-white/60 bg-unisafe-smoke-white/10">
                    <button 
                      onClick={() => {
                        onNotificationClick({ type: 'VIEW_ALL' });
                        setShowDropdown(false);
                      }}
                      className="w-full py-2 text-sm font-bold text-unisafe-midnight-blue hover:text-unisafe-teal bg-unisafe-smoke-white/50 hover:bg-unisafe-smoke-white rounded-lg transition-colors"
                    >
                      View All Notifications
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
          
          {/* User Profile Summary (Mobile hidden) */}
          <div className="hidden sm:flex flex-col items-end">
            <h1 className="text-sm font-bold text-unisafe-midnight-blue tracking-tight">
              {authority?.name || 'Officer'}
            </h1>
            <div className="flex items-center gap-2 mt-0.5">
              <span className={`px-2 py-0.5 text-[10px] font-bold uppercase rounded-sm ${badgeColor}`}>
                {authority?.department || 'AUTHORITY'}
              </span>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
