import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import MissingPersonsList from './components/MissingPersonsList';
import RegisterModal from './components/RegisterModal';
import CaseDetailModal from './components/CaseDetailModal';
import SightingsQueue from './components/SightingsQueue';
import SightingDetailModal from './components/SightingDetailModal';
import NotificationToast from './components/NotificationToast';
import {
  getStoredOfficer,
  getStoredToken,
  logoutAuthority,
  getCurrentOfficer,
  redirectToAuthorityLogin,
} from './services/api';
import { ShieldCheck, Lock, ShieldAlert, Loader2 } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('missing_persons');
  const [selectedCaseId, setSelectedCaseId] = useState(null);
  const [selectedSightingId, setSelectedSightingId] = useState(null);
  const [isRegisterOpen, setIsRegisterOpen] = useState(false);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Authority Authentication State (reusing existing authority portal session)
  const [currentOfficer, setCurrentOfficer] = useState(() => getStoredOfficer());
  const [isVerifyingAuth, setIsVerifyingAuth] = useState(true);

  // Toast notifications
  const [notifications, setNotifications] = useState([]);

  const addNotification = (message, type = 'success') => {
    const id = Date.now() + Math.random();
    setNotifications((prev) => [...prev, { id, message, type }]);
    setTimeout(() => {
      setNotifications((prev) => prev.filter((n) => n.id !== id));
    }, 4500);
  };

  const dismissNotification = (id) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
  };

  // Sync auth state changes and verify authority portal session on mount
  useEffect(() => {
    let isMounted = true;

    const handleAuthChange = (e) => {
      const officer = e.detail;
      if (isMounted) {
        setCurrentOfficer(officer);
        if (!officer) {
          redirectToAuthorityLogin();
        }
      }
    };

    window.addEventListener('unisafe:auth_changed', handleAuthChange);

    const token = getStoredToken();
    if (!token) {
      if (isMounted) {
        setCurrentOfficer(null);
        setIsVerifyingAuth(false);
        redirectToAuthorityLogin();
      }
      return () => {
        window.removeEventListener('unisafe:auth_changed', handleAuthChange);
      };
    }

    // Verify existing token with backend to resolve trusted authority profile
    getCurrentOfficer()
      .then((officer) => {
        if (isMounted) {
          if (officer) {
            setCurrentOfficer(officer);
          } else {
            setCurrentOfficer(null);
            redirectToAuthorityLogin();
          }
        }
      })
      .catch((err) => {
        console.warn('[UniSafe Auth] Failed to verify authority session:', err);
        if (isMounted) {
          setCurrentOfficer(null);
          redirectToAuthorityLogin();
        }
      })
      .finally(() => {
        if (isMounted) {
          setIsVerifyingAuth(false);
        }
      });

    return () => {
      isMounted = false;
      window.removeEventListener('unisafe:auth_changed', handleAuthChange);
    };
  }, []);

  const handleLogout = async () => {
    await logoutAuthority();
    setCurrentOfficer(null);
    addNotification('Authority session terminated successfully.', 'info');
    redirectToAuthorityLogin();
  };

  const handleRegisterSuccess = (newCase) => {
    addNotification(
      `Case ${newCase.case_code || ''} successfully filed for ${newCase.full_name}. Facial vector indexed.`,
      'success'
    );
    setRefreshTrigger((prev) => prev + 1);
  };

  const handleCaseUpdated = () => {
    setRefreshTrigger((prev) => prev + 1);
  };

  const [sightingRefreshTrigger, setSightingRefreshTrigger] = useState(0);

  const handleSightingUpdated = (sightingId, result) => {
    setSightingRefreshTrigger((prev) => prev + 1);
    if (result?.top_match) {
      addNotification(
        `High similarity match identified for sighting (${(result.top_match.similarity_score * 100).toFixed(1)}%). Sighting queue updated.`,
        'success'
      );
    }
  };

  return (
    <>
      {/* Top Navigation */}
      <Navbar
        activeTab={activeTab}
        onTabChange={setActiveTab}
        currentOfficer={currentOfficer}
        onLogout={handleLogout}
        onSignIn={() => redirectToAuthorityLogin()}
      />

      {/* Main Container */}
      <main className="main-wrapper">
        {/* Header Ribbon matching UniSafe Heatmap & Hotspots Style */}
        <div className="page-header-row">
          <div className="header-title-box">
            <span className="badge-portal">
              <ShieldCheck size={12} />
              Mumbai Police Directorate • Cyber & Forensic AI
            </span>
            <h1>
              {activeTab === 'missing_persons'
                ? 'Missing Persons Dossiers & Biometrics'
                : 'Citizen Sightings Inferences & Matching'}
            </h1>
            <p>
              {activeTab === 'missing_persons'
                ? 'Comprehensive law enforcement case registry powered by 512-dimensional facial recognition vectors and automated sighting cross-referencing.'
                : 'Review citizen sightings flagged by the InsightFace engine with high cosine similarity against active missing person cases.'}
            </p>
          </div>
        </div>

        {/* Tab Content, Unauthenticated Banner, or Access Denied */}
        {isVerifyingAuth ? (
          <div
            style={{
              padding: '80px 24px',
              textAlign: 'center',
              borderRadius: '16px',
              background: 'rgba(15, 23, 42, 0.6)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              marginTop: '20px',
            }}
          >
            <Loader2 size={36} className="animate-spin" style={{ margin: '0 auto 16px auto', color: '#3b82f6' }} />
            <h2 style={{ fontSize: '1.2rem', fontWeight: 600, color: '#f1f5f9', margin: '0 0 8px 0' }}>
              Verifying Authority Session...
            </h2>
            <p style={{ color: '#94a3b8', fontSize: '0.88rem', margin: 0 }}>
              Connecting to UniSafe Authority Command and verifying officer credentials.
            </p>
          </div>
        ) : !currentOfficer ? (
          <div
            style={{
              padding: '60px 24px',
              textAlign: 'center',
              borderRadius: '16px',
              background: 'rgba(15, 23, 42, 0.6)',
              border: '1px solid rgba(255, 255, 255, 0.08)',
              marginTop: '20px',
            }}
          >
            <div
              style={{
                width: '64px',
                height: '64px',
                margin: '0 auto 16px auto',
                borderRadius: '50%',
                background: 'rgba(239, 68, 68, 0.12)',
                color: '#f87171',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                border: '1px solid rgba(239, 68, 68, 0.25)',
              }}
            >
              <Lock size={30} />
            </div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 8px 0' }}>
              Authority Authentication Required
            </h2>
            <p style={{ maxWidth: '520px', margin: '0 auto 24px auto', color: '#94a3b8', fontSize: '0.92rem', lineHeight: 1.5 }}>
              Access to the Missing Persons & Sightings module requires an active UniSafe Authority Portal session. Please sign in through the authority portal.
            </p>
            <button
              type="button"
              className="btn btn-primary"
              onClick={() => redirectToAuthorityLogin()}
              style={{ padding: '10px 22px', fontSize: '0.95rem' }}
            >
              <ShieldCheck size={18} />
              <span>Go to Authority Portal Login</span>
            </button>
          </div>
        ) : (currentOfficer.department || '').trim().toUpperCase() !== 'POLICE' ? (
          <div
            style={{
              padding: '60px 24px',
              textAlign: 'center',
              borderRadius: '16px',
              background: 'rgba(15, 23, 42, 0.75)',
              border: '1px solid rgba(239, 68, 68, 0.35)',
              marginTop: '20px',
            }}
          >
            <div
              style={{
                width: '64px',
                height: '64px',
                margin: '0 auto 16px auto',
                borderRadius: '50%',
                background: 'rgba(239, 68, 68, 0.15)',
                color: '#f87171',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                border: '1px solid rgba(239, 68, 68, 0.35)',
              }}
            >
              <ShieldAlert size={32} />
            </div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 700, color: '#f1f5f9', margin: '0 0 8px 0' }}>
              Access Denied: Police Authorization Required
            </h2>
            <p style={{ maxWidth: '560px', margin: '0 auto 20px auto', color: '#94a3b8', fontSize: '0.92rem', lineHeight: 1.5 }}>
              The Missing Persons Dossiers and Citizen Sightings Verification modules are strictly restricted to verified <strong>Mumbai Police</strong> personnel. Your account is authenticated under <strong>{currentOfficer.department || 'Civic Authority'}</strong> ({currentOfficer.role || 'Officer'}). Civic authority officers cannot view or modify police missing-person records.
            </p>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleLogout}
              style={{ padding: '9px 20px', fontSize: '0.9rem' }}
            >
              Sign Out / Switch to Police Account
            </button>
          </div>
        ) : activeTab === 'missing_persons' ? (
          <MissingPersonsList
            onSelectCase={(id) => setSelectedCaseId(id)}
            onOpenRegister={() => setIsRegisterOpen(true)}
            refreshTrigger={refreshTrigger}
          />
        ) : (
          <SightingsQueue
            onSelectSighting={(id) => setSelectedSightingId(id)}
            refreshTrigger={sightingRefreshTrigger}
          />
        )}
      </main>

      {/* Register Missing Person Modal */}
      <RegisterModal
        isOpen={isRegisterOpen}
        onClose={() => setIsRegisterOpen(false)}
        onSuccess={handleRegisterSuccess}
      />

      {/* Case Details Dossier Modal */}
      <CaseDetailModal
        personId={selectedCaseId}
        isOpen={Boolean(selectedCaseId)}
        onClose={() => setSelectedCaseId(null)}
        onCaseUpdated={handleCaseUpdated}
      />

      {/* Sighting Details Modal */}
      <SightingDetailModal
        sightingId={selectedSightingId}
        isOpen={Boolean(selectedSightingId)}
        onClose={() => setSelectedSightingId(null)}
        onOpenCaseDossier={(caseId) => setSelectedCaseId(caseId)}
        onSightingUpdated={handleSightingUpdated}
      />

      {/* Toast Feedback Notifications */}
      <NotificationToast
        notifications={notifications}
        onDismiss={dismissNotification}
      />
    </>
  );
}
