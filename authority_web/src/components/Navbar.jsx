import React from 'react';
import { ShieldCheck, UserCheck, Eye, Search, LogOut } from 'lucide-react';
import { redirectToAuthorityLogin } from '../services/api';

export default function Navbar({
  activeTab = 'missing_persons',
  onTabChange,
  currentOfficer = null,
  onLogout,
  onSignIn = redirectToAuthorityLogin,
}) {
  return (
    <header className="navbar">
      <div className="navbar-container">
        {/* Brand */}
        <div className="brand-wrapper">
          <div className="brand-icon-box">
            <ShieldCheck size={22} strokeWidth={2.2} />
          </div>
          <div className="brand-text-block">
            <span className="brand-name">UniSafe</span>
            <span className="brand-tag">Authority Portal • Police Command</span>
          </div>
        </div>

        {/* Navigation Tabs (Restricted to Police Department) */}
        {(!currentOfficer || (currentOfficer.department || '').trim().toUpperCase() === 'POLICE') ? (
          <nav className="nav-links">
            <button
              type="button"
              className={`nav-tab ${activeTab === 'missing_persons' ? 'active' : ''}`}
              onClick={() => onTabChange && onTabChange('missing_persons')}
            >
              <Search size={16} />
              Missing Persons Dossiers
            </button>

            <button
              type="button"
              className={`nav-tab ${activeTab === 'sightings' ? 'active' : ''}`}
              onClick={() => onTabChange && onTabChange('sightings')}
            >
              <Eye size={16} />
              Sightings Queue
            </button>
          </nav>
        ) : (
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#fca5a5', fontSize: '0.8rem', fontWeight: 600, background: 'rgba(239, 68, 68, 0.1)', padding: '5px 12px', borderRadius: '6px', border: '1px solid rgba(239, 68, 68, 0.25)' }}>
            <span>Police Module Restricted (Civic Authority)</span>
          </div>
        )}

        {/* Right Officer Profile & Session Badge */}
        {currentOfficer ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div className="authority-profile-badge">
              <div className="officer-avatar">
                <UserCheck size={16} />
              </div>
              <div className="officer-info">
                <span className="officer-title">
                  {currentOfficer.role ? `${currentOfficer.role} ` : ''}
                  {currentOfficer.name}
                </span>
                <span className="officer-dept">
                  {currentOfficer.department || 'POLICE'} • {currentOfficer.jurisdiction || 'Law Enforcement'}
                </span>
              </div>
            </div>

            <button
              type="button"
              className="btn btn-secondary"
              onClick={onLogout}
              title="Sign Out of Authority Session"
              style={{
                padding: '7px 10px',
                borderRadius: '8px',
                fontSize: '0.8rem',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                background: 'rgba(239, 68, 68, 0.1)',
                borderColor: 'rgba(239, 68, 68, 0.25)',
                color: '#fca5a5',
              }}
            >
              <LogOut size={14} />
              <span>Logout</span>
            </button>
          </div>
        ) : (
          <button
            type="button"
            className="btn btn-primary"
            onClick={onSignIn || redirectToAuthorityLogin}
            style={{ fontSize: '0.82rem', padding: '7px 14px' }}
          >
            <ShieldCheck size={16} />
            <span>Sign In to Authority Portal</span>
          </button>
        )}
      </div>
    </header>
  );
}
