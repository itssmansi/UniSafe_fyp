import React from 'react';

// SVG Icons
const FileTextIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z" />
    <polyline points="14 2 14 8 20 8" />
    <line x1="16" x2="8" y1="13" y2="13" />
    <line x1="16" x2="8" y1="17" y2="17" />
    <line x1="10" x2="8" y1="9" y2="9" />
  </svg>
);

const AlertTriangleIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" />
    <path d="M12 9v4" />
    <path d="M12 17h.01" />
  </svg>
);

const TrendingUpIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="22 7 13.5 15.5 8.5 10.5 2 17" />
    <polyline points="16 7 22 7 22 13" />
  </svg>
);

const RefreshCwIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
    <path d="M3 3v5h5" />
  </svg>
);

const CheckCircleIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
    <path d="m9 11 3 3L22 4" />
  </svg>
);

const BadgeCheckIcon = () => (
  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z" />
    <path d="m9 12 2 2 4-4" />
  </svg>
);

export default function AuthorityNotificationItem({ notification, onMarkRead, onClick }) {
  const { type, priority, title, body, created_at, is_read } = notification;

  // Determine styles and icons based on type and priority
  let IconComponent = FileTextIcon;
  let colorStyles = 'bg-unisafe-white border-unisafe-smoke-white/50 text-unisafe-midnight-blue';
  let iconBg = 'bg-unisafe-midnight-blue/10 text-unisafe-midnight-blue';

  switch (type) {
    case 'NEW_COMPLAINT':
      IconComponent = FileTextIcon;
      break;
    case 'CRITICAL':
      IconComponent = AlertTriangleIcon;
      break;
    case 'THRESHOLD':
      IconComponent = TrendingUpIcon;
      break;
    case 'STATUS_UPDATE':
    case 'STATUS':
      IconComponent = RefreshCwIcon;
      break;
    case 'RESOLVED':
      IconComponent = CheckCircleIcon;
      break;
    case 'VERIFICATION':
      IconComponent = BadgeCheckIcon;
      break;
    default:
      IconComponent = FileTextIcon;
  }

  if (priority === 'CRITICAL') {
    colorStyles = 'bg-unisafe-crimson/5 border-unisafe-crimson/20';
    iconBg = 'bg-unisafe-crimson/10 text-unisafe-crimson';
  } else if (priority === 'HIGH') {
    colorStyles = 'bg-unisafe-amber/5 border-unisafe-amber/20';
    iconBg = 'bg-unisafe-amber/10 text-unisafe-amber';
  } else if (priority === 'SUCCESS') {
    colorStyles = 'bg-unisafe-teal/5 border-unisafe-teal/20';
    iconBg = 'bg-unisafe-teal/10 text-unisafe-teal';
  }

  if (is_read) {
    colorStyles = 'bg-unisafe-white border-unisafe-smoke-white/50 opacity-60 hover:opacity-100';
  }

  const handleClick = () => {
    if (onClick) onClick(notification);
    // Auto-mark as read if clicked
    if (!is_read && onMarkRead) onMarkRead(notification.id);
  };

  return (
    <div 
      onClick={handleClick}
      className={`p-4 rounded-xl border shadow-sm flex items-start gap-4 transition-all hover:shadow-md cursor-pointer ${colorStyles}`}
    >
      <div className={`p-2 rounded-full shrink-0 ${iconBg}`}>
        <IconComponent />
      </div>
      
      <div className="flex-1 min-w-0">
        <h4 className={`text-sm font-semibold truncate ${priority === 'CRITICAL' && !is_read ? 'text-unisafe-crimson' : 'text-unisafe-midnight-blue'}`}>
          {title}
        </h4>
        <p className="text-sm text-unisafe-dark-midnight-blue/70 mt-1 line-clamp-2">
          {body}
        </p>
        <span className="text-xs text-unisafe-dark-midnight-blue/40 mt-2 block font-medium uppercase tracking-wider">
          {new Date(created_at).toLocaleString([], { hour: '2-digit', minute: '2-digit', month: 'short', day: 'numeric' })}
        </span>
      </div>

      {!is_read && onMarkRead && (
        <button 
          onClick={(e) => {
            e.stopPropagation();
            onMarkRead(notification.id);
          }}
          className="shrink-0 p-2 text-unisafe-dark-midnight-blue/40 hover:text-unisafe-teal hover:bg-unisafe-teal/10 rounded-lg transition-colors"
          title="Mark as read"
        >
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" /></svg>
        </button>
      )}
    </div>
  );
}
