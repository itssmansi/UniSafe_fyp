import React, { useState, useEffect, useMemo } from 'react';
import {
  Search,
  Plus,
  RefreshCw,
  UserCheck,
  AlertTriangle,
  FolderOpen,
  MapPin,
  Calendar,
  Eye,
  CheckCircle,
  Clock,
  ChevronRight
} from 'lucide-react';
import { getMissingPersons } from '../services/api';

export default function MissingPersonsList({
  onSelectCase,
  onOpenRegister,
  refreshTrigger
}) {
  const [cases, setCases] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const fetchCases = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await getMissingPersons(statusFilter);
      setCases(data?.missing_persons || []);
    } catch (err) {
      console.error('Failed to load missing persons:', err);
      setError(err.message || 'Could not connect to the missing-persons registry');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCases();
  }, [statusFilter, refreshTrigger]);

  // Client-side search filtering by name or case code
  const filteredCases = useMemo(() => {
    if (!searchQuery.trim()) return cases;
    const query = searchQuery.toLowerCase().trim();
    return cases.filter((c) => {
      const nameMatch = c.full_name?.toLowerCase().includes(query);
      const codeMatch = c.case_code?.toLowerCase().includes(query);
      const descMatch = c.description?.toLowerCase().includes(query);
      return nameMatch || codeMatch || descMatch;
    });
  }, [cases, searchQuery]);

  // Summary Metrics
  const metrics = useMemo(() => {
    const total = cases.length;
    const missing = cases.filter((c) => c.status?.toLowerCase() === 'missing').length;
    const found = cases.filter((c) => c.status?.toLowerCase() === 'found').length;
    const closed = cases.filter((c) => c.status?.toLowerCase() === 'closed').length;
    return { total, missing, found, closed };
  }, [cases]);

  const getStatusBadge = (status) => {
    const s = status?.toLowerCase();
    if (s === 'missing') {
      return (
        <span className="status-badge missing">
          <span className="pulse-dot" /> Missing
        </span>
      );
    }
    if (s === 'found') {
      return (
        <span className="status-badge found">
          <span className="pulse-dot" /> Found
        </span>
      );
    }
    return (
      <span className="status-badge closed">
        <span className="pulse-dot" /> {status || 'Closed'}
      </span>
    );
  };

  return (
    <div>
      {/* KPI Stats Ribbon */}
      <div className="kpi-grid">
        <div className="kpi-card midnight">
          <div className="kpi-icon-container">
            <FolderOpen size={24} />
          </div>
          <div>
            <div className="kpi-label">Registered Dossiers</div>
            <div className="kpi-value">{metrics.total}</div>
            <div className="kpi-sub">Total cataloged in registry</div>
          </div>
        </div>

        <div className="kpi-card amber">
          <div className="kpi-icon-container">
            <AlertTriangle size={24} />
          </div>
          <div>
            <div className="kpi-label">Active Missing Cases</div>
            <div className="kpi-value">{metrics.missing}</div>
            <div className="kpi-sub">Actively matched with sightings</div>
          </div>
        </div>

        <div className="kpi-card teal">
          <div className="kpi-icon-container">
            <CheckCircle size={24} />
          </div>
          <div>
            <div className="kpi-label">Located & Identified</div>
            <div className="kpi-value">{metrics.found}</div>
            <div className="kpi-sub">Resolved via AI or field verification</div>
          </div>
        </div>

        <div className="kpi-card dark">
          <div className="kpi-icon-container">
            <Clock size={24} />
          </div>
          <div>
            <div className="kpi-label">Closed / Archived</div>
            <div className="kpi-value">{metrics.closed}</div>
            <div className="kpi-sub">Concluded official records</div>
          </div>
        </div>
      </div>

      {/* Controls & Filter Bar */}
      <div className="controls-bar">
        <div className="controls-left">
          {/* Search Bar */}
          <div className="search-box">
            <Search size={16} />
            <input
              type="text"
              className="search-input"
              placeholder="Search by name, case code (MP-...), or keyword..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          {/* Status Filters */}
          <div className="filter-group">
            <button
              type="button"
              className={`filter-pill ${statusFilter === 'all' ? 'active' : ''}`}
              onClick={() => setStatusFilter('all')}
            >
              All Cases
            </button>
            <button
              type="button"
              className={`filter-pill ${statusFilter === 'Missing' ? 'active' : ''}`}
              onClick={() => setStatusFilter('Missing')}
            >
              Active Missing
            </button>
            <button
              type="button"
              className={`filter-pill ${statusFilter === 'Found' ? 'active' : ''}`}
              onClick={() => setStatusFilter('Found')}
            >
              Found
            </button>
            <button
              type="button"
              className={`filter-pill ${statusFilter === 'Closed' ? 'active' : ''}`}
              onClick={() => setStatusFilter('Closed')}
            >
              Closed
            </button>
          </div>
        </div>

        {/* Right Action Buttons */}
        <div className="controls-right">
          <button
            type="button"
            className="btn btn-secondary btn-icon"
            onClick={fetchCases}
            title="Refresh case registry"
            disabled={loading}
          >
            <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          </button>

          <button
            type="button"
            className="btn btn-primary"
            onClick={onOpenRegister}
          >
            <Plus size={16} /> Register Missing Person
          </button>
        </div>
      </div>

      {/* Main Table / State Container */}
      <div className="table-container">
        {loading ? (
          <div className="state-container">
            <div className="spinner" />
            <p className="state-title">Loading Missing Person Dossiers...</p>
            <p className="state-desc">Fetching registered records from the Flask AI backend service</p>
          </div>
        ) : error ? (
          <div className="state-container">
            <div className="state-icon-box error">
              <AlertTriangle size={32} />
            </div>
            <p className="state-title">Backend Connection Error</p>
            <p className="state-desc">{error}</p>
            <button type="button" className="btn btn-secondary" onClick={fetchCases}>
              <RefreshCw size={14} /> Retry Connection
            </button>
          </div>
        ) : filteredCases.length === 0 ? (
          <div className="state-container">
            <div className="state-icon-box empty">
              <FolderOpen size={32} />
            </div>
            <p className="state-title">No Missing Person Cases Found</p>
            <p className="state-desc">
              {searchQuery
                ? `No matching records found for "${searchQuery}". Try adjusting your search query.`
                : 'There are currently no missing person dossiers registered in this category.'}
            </p>
            <button type="button" className="btn btn-primary" onClick={onOpenRegister}>
              <Plus size={16} /> Register First Case
            </button>
          </div>
        ) : (
          <table className="cases-table">
            <thead>
              <tr>
                <th style={{ width: '130px' }}>Case Code</th>
                <th>Subject Dossier</th>
                <th>Status</th>
                <th>Last Seen Incident</th>
                <th>Registered Date</th>
                <th style={{ width: '100px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredCases.map((c) => (
                <tr key={c.id} onClick={() => onSelectCase(c.id)}>
                  <td>
                    <span className="case-code-pill">{c.case_code || 'MP-PENDING'}</span>
                  </td>
                  <td>
                    <div className="person-primary-cell">
                      <span className="person-name">{c.full_name}</span>
                      <span className="person-demographics">
                        {c.age ? `${c.age} yrs` : 'Age N/A'} • {c.gender || 'Unspecified'}
                      </span>
                    </div>
                  </td>
                  <td>{getStatusBadge(c.status)}</td>
                  <td>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '0.2rem' }}>
                      <span className="date-cell">
                        <Calendar size={13} style={{ display: 'inline', marginRight: '0.25rem' }} />
                        {c.last_seen_date ? new Date(c.last_seen_date).toLocaleDateString() : 'Unspecified'}
                      </span>
                      {c.latitude && c.longitude && (
                        <span className="location-cell">
                          <MapPin size={13} />
                          {c.latitude.toFixed(3)}, {c.longitude.toFixed(3)}
                        </span>
                      )}
                    </div>
                  </td>
                  <td>
                    <span className="date-cell">
                      {c.created_at ? new Date(c.created_at).toLocaleDateString() : 'N/A'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <button
                      type="button"
                      className="btn btn-secondary"
                      style={{ padding: '0.35rem 0.65rem', fontSize: '0.78rem' }}
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelectCase(c.id);
                      }}
                    >
                      <Eye size={13} /> View
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
