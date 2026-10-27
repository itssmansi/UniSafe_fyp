import React, { useState, useEffect, useRef } from "react";
import { Bell } from "lucide-react";
import { supabase } from "../../services/supabase";

export default function CitizenNotificationBell() {
  const [notifications, setNotifications] = useState([]);
  const [isOpen, setIsOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const dropdownRef = useRef(null);

  useEffect(() => {
    fetchNotifications();

    // Setup realtime listener for new notifications
    const channel = supabase
      .channel('public:notifications')
      .on('postgres_changes', { 
        event: 'INSERT', 
        schema: 'public', 
        table: 'notifications',
        filter: 'authority_id=is.null' // Only citizen notifications
      }, (payload) => {
        setNotifications(prev => [payload.new, ...prev].slice(0, 10));
        setUnreadCount(prev => prev + 1);
      })
      .subscribe();

    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchNotifications = async () => {
    try {
      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .is('authority_id', null)
        .order('created_at', { ascending: false })
        .limit(10);

      if (error) throw error;
      
      setNotifications(data || []);
      setUnreadCount((data || []).filter(n => !n.is_read).length);
    } catch (err) {
      console.error("Error fetching notifications:", err);
    }
  };

  const handleToggle = () => {
    setIsOpen(!isOpen);
    if (!isOpen && unreadCount > 0) {
      // Mark as read (optimistically)
      setUnreadCount(0);
      setNotifications(prev => prev.map(n => ({ ...n, is_read: true })));
      
      // Update in background
      const unreadIds = notifications.filter(n => !n.is_read).map(n => n.id);
      if (unreadIds.length > 0) {
        supabase.from('notifications').update({ is_read: true }).in('id', unreadIds).then();
      }
    }
  };

  const getIconColor = (title) => {
    const t = (title || "").toLowerCase();
    if (t.includes('resolved') || t.includes('success')) return "text-emerald-500 bg-emerald-50";
    if (t.includes('risk') || t.includes('alert')) return "text-rose-500 bg-rose-50";
    if (t.includes('progress') || t.includes('review')) return "text-amber-500 bg-amber-50";
    return "text-blue-500 bg-blue-50";
  };

  return (
    <div className="relative" ref={dropdownRef}>
      <button 
        onClick={handleToggle}
        className="relative p-2 rounded-full hover:bg-slate-100 transition-colors cursor-pointer flex items-center justify-center"
        aria-label="Notifications"
      >
        <Bell className="w-5 h-5 text-unisafe-midnight-blue" />
        {unreadCount > 0 && (
          <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-rose-500 border-2 border-white"></span>
        )}
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 bg-white rounded-xl shadow-xl shadow-slate-200/50 border border-slate-100 overflow-hidden z-50 animate-in slide-in-from-top-2 fade-in duration-200">
          <div className="p-3.5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
            <h3 className="font-semibold text-slate-900 text-sm">Citizen Notifications</h3>
            {unreadCount > 0 && (
              <span className="text-xs font-medium bg-unisafe-teal text-white px-2 py-0.5 rounded-full">
                {unreadCount} new
              </span>
            )}
          </div>
          
          <div className="max-h-[350px] overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="p-6 text-center text-sm text-slate-500">
                No notifications yet.
              </div>
            ) : (
              <div className="flex flex-col">
                {notifications.map((notif) => (
                  <div 
                    key={notif.id} 
                    className={`p-3.5 border-b border-slate-50 hover:bg-slate-50 transition-colors flex gap-3 ${!notif.is_read ? 'bg-blue-50/30' : ''}`}
                  >
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center shrink-0 ${getIconColor(notif.title)}`}>
                      <Bell className="w-4 h-4" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-slate-900 line-clamp-1">{notif.title}</p>
                      <p className="text-xs text-slate-500 mt-0.5 leading-relaxed">{notif.body}</p>
                      <p className="text-[10px] font-medium text-slate-400 mt-1.5">
                        {new Date(notif.created_at).toLocaleString([], { hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric' })}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
