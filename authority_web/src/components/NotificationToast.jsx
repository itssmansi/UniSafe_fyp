import React from 'react';
import { CheckCircle2, AlertCircle, Info, X } from 'lucide-react';

export default function NotificationToast({ notifications = [], onDismiss }) {
  if (!notifications.length) return null;

  return (
    <div className="toast-container" aria-live="polite">
      {notifications.map((n) => {
        const isSuccess = n.type === 'success';
        const isError = n.type === 'error';
        const isWarning = n.type === 'warning';

        return (
          <div
            key={n.id}
            className={`toast ${isSuccess ? 'success' : isError ? 'error' : isWarning ? 'warning' : ''}`}
          >
            {isSuccess && <CheckCircle2 size={18} />}
            {isError && <AlertCircle size={18} />}
            {isWarning && <AlertCircle size={18} />}
            {!isSuccess && !isError && !isWarning && <Info size={18} />}
            <span>{n.message}</span>
            <button
              type="button"
              className="btn-ghost"
              style={{ color: '#FFFFFF', padding: '0 0.2rem', marginLeft: 'auto' }}
              onClick={() => onDismiss(n.id)}
              aria-label="Dismiss notification"
            >
              <X size={14} />
            </button>
          </div>
        );
      })}
    </div>
  );
}
