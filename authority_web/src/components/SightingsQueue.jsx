import React, { useState, useEffect } from 'react';
import {
  Eye,
  RefreshCw,
  AlertTriangle,
  CheckCircle,
  MapPin,
  Calendar,
  Sparkles,
  ExternalLink
} from 'lucide-react';
import { getSightings } from '../services/api';

export default function SightingsQueue({ onSelectSighting, refreshTrigger }) {
  const [sightings, setSightings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');

  const fetchSightings = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getSightings(filter);
      setSightings(data?.sightings || []);
    } catch (err) {
      console.error('Failed to load sightings:', err);
      setError(err.message || 'Could not fetch sightings queue');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchSightings();
  }, [filter, refreshTrigger]);

  return (
    <div>
      {/* Controls Bar */}
      <div className="controls-bar">
        <div className="controls-left">
          <div className="filter-group">
            <button
              type="button"
              className={`filter-pill ${filter === 'all' ? 'active' : ''}`}
              onClick={() => setFilter('all')}
            >
              All Sightings
            </button>
            <button
              type="button"
              className={`filter-pill ${filter === 'false' ? 'active' : ''}`}
              onClick={() => setFilter('false')}
            >
              Pending Verification
            </button>
            <button
              type="button"
              className={`filter-pill ${filter === 'true' ? 'active' : ''}`}
              onClick={() => setFilter('true')}
            >
              Verified
            </button>
          </div>
        </div>

        <div className="controls-right">
          <button
            type="button"
            className="btn btn-secondary btn-icon"
            onClick={fetchSightings}
            title="Refresh sightings queue"
            disabled={loading}
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          </button>
        </div>
      </div>

      {/* Main Table */}
      <div className="table-container">
        {loading ? (
          <div className="state-container">
            <div className="spinner" />
            <p className="state-title">Loading Citizen Sightings Queue...</p>
          </div>
        ) : error ? (
          <div className="state-container">
            <div className="state-icon-box error">
              <AlertTriangle size={32} />
            </div>
            <p className="state-title">Failed to Load Sightings</p>
            <p className="state-desc">{error}</p>
            <button type="button" className="btn btn-secondary" onClick={fetchSightings}>
              <RefreshCw size={14} /> Retry
            </button>
          </div>
        ) : sightings.length === 0 ? (
          <div className="state-container">
            <div className="state-icon-box empty">
              <Eye size={32} />
            </div>
            <p className="state-title">No Citizen Sightings in Queue</p>
            <p className="state-desc">
              When citizens capture suspected sightings through the mobile app, AI inferences will appear here for verification.
            </p>
          </div>
        ) : (
          <table className="cases-table">
            <thead>
              <tr>
                <th style={{ width: '140px' }}>Sighting ID</th>
                <th>AI Match Status</th>
                <th>Verification</th>
                <th>Location</th>
                <th>Reported On</th>
                <th style={{ width: '110px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {sightings.map((s) => (
                <tr key={s.id} onClick={() => onSelectSighting(s.id)}>
                  <td>
                    <span className="case-code-pill">{s.id.substring(0, 8)}...</span>
                  </td>
                  <td>
                    {s.missing_person_id ? (
                      <div>
                        {s.is_case_resolved ? (
                          <span
                            className={`status-badge ${s.linked_case_status === 'Found' ? 'found' : 'closed'}`}
                            style={{ fontSize: '0.72rem', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                          >
                            <CheckCircle size={11} /> Case Resolved ({s.linked_case_status || 'Found'})
                          </span>
                        ) : (
                          <span
                            style={{
                              display: 'inline-flex',
                              alignItems: 'center',
                              gap: '0.35rem',
                              color: 'var(--color-teal)',
                              fontWeight: 600,
                              fontSize: '0.82rem'
                            }}
                          >
                            <Sparkles size={14} /> Active Case Match
                          </span>
                        )}
                        {s.linked_case_code && (
                          <div style={{ fontSize: '0.72rem', color: 'var(--color-text-muted)', marginTop: '2px' }}>
                            {s.linked_case_code} {s.linked_case_name ? `• ${s.linked_case_name}` : ''}
                          </div>
                        )}
                      </div>
                    ) : (
                      <span style={{ color: 'var(--color-text-muted)', fontSize: '0.82rem' }}>
                        No Case Match
                      </span>
                    )}
                  </td>
                  <td>
                    {s.is_verified ? (
                      <span className="status-badge found">
                        <CheckCircle size={12} /> Verified
                      </span>
                    ) : (
                      <span className="status-badge missing">
                        <Eye size={12} /> Pending Review
                      </span>
                    )}
                  </td>
                  <td>
                    {s.address ? (
                      <div>
                        <span className="location-cell" title={s.address}>
                          <MapPin size={13} style={{ flexShrink: 0 }} />
                          <span style={{ maxWidth: '180px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'inline-block', verticalAlign: 'middle' }}>
                            {s.address}
                          </span>
                        </span>
                        {s.latitude != null && s.longitude != null && (
                          <div style={{ fontSize: '0.72rem', color: 'var(--color-text-light)', marginTop: '2px', paddingLeft: '1.25rem' }}>
                            {Number(s.latitude).toFixed(3)}, {Number(s.longitude).toFixed(3)}
                          </div>
                        )}
                      </div>
                    ) : s.latitude != null && s.longitude != null ? (
                      <span className="location-cell">
                        <MapPin size={13} />
                        {Number(s.latitude).toFixed(3)}, {Number(s.longitude).toFixed(3)}
                      </span>
                    ) : (
                      <span style={{ color: 'var(--color-text-light)', fontSize: '0.8rem' }}>Location not provided</span>
                    )}
                  </td>
                  <td>
                    <span className="date-cell">
                      <Calendar size={13} style={{ display: 'inline', marginRight: '0.25rem' }} />
                      {s.created_at ? new Date(s.created_at).toLocaleString() : 'N/A'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      type="button"
                      className="btn btn-secondary"
                      style={{ padding: '0.35rem 0.65rem', fontSize: '0.78rem' }}
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelectSighting(s.id);
                      }}
                    >
                      <Eye size={13} /> Review
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
