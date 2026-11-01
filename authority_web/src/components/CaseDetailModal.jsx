import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  User,
  Calendar,
  MapPin,
  FileText,
  Clock,
  Trash2,
  Plus,
  Edit2,
  Check,
  AlertCircle,
  ShieldAlert,
  ShieldCheck,
  Loader2,
  ArrowRight,
  Image as ImageIcon
} from 'lucide-react';
import {
  getMissingPersonDetail,
  updateMissingPerson,
  updateCaseStatus,
  addCasePhoto,
  deleteCasePhoto
} from '../services/api';

export default function CaseDetailModal({ personId, isOpen, onClose, onCaseUpdated }) {
  const [caseData, setCaseData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState(null);
  const [actionSuccess, setActionSuccess] = useState(null);

  // Edit Mode state
  const [isEditing, setIsEditing] = useState(false);
  const [editForm, setEditForm] = useState({
    full_name: '',
    age: '',
    gender: '',
    last_seen_date: '',
    latitude: '',
    longitude: '',
    description: ''
  });
  const [savingEdit, setSavingEdit] = useState(false);

  // Change Status Dialog State
  const [isStatusModalOpen, setIsStatusModalOpen] = useState(false);
  const [selectedNewStatus, setSelectedNewStatus] = useState('');
  const [verifiedConfirmation, setVerifiedConfirmation] = useState(false);
  const [statusRemarks, setStatusRemarks] = useState('');
  const [savingStatus, setSavingStatus] = useState(false);
  const [statusDialogError, setStatusDialogError] = useState(null);

  // Add Photo state
  const [uploadingPhoto, setUploadingPhoto] = useState(false);
  const photoInputRef = useRef(null);

  // Load details
  const loadCase = async () => {
    if (!personId) return;
    setLoading(true);
    setErrorMessage(null);
    try {
      const data = await getMissingPersonDetail(personId);
      setCaseData(data);
      setEditForm({
        full_name: data.full_name || '',
        age: data.age !== null && data.age !== undefined ? String(data.age) : '',
        gender: data.gender || '',
        last_seen_date: data.last_seen_date ? data.last_seen_date.substring(0, 16) : '',
        latitude: data.latitude !== null && data.latitude !== undefined ? String(data.latitude) : '',
        longitude: data.longitude !== null && data.longitude !== undefined ? String(data.longitude) : '',
        description: data.description || ''
      });
    } catch (err) {
      console.error('Failed to load case:', err);
      setErrorMessage(err.message || 'Failed to load case details');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      const originalOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  }, [isOpen]);

  useEffect(() => {
    if (isOpen && personId) {
      setIsEditing(false);
      setIsStatusModalOpen(false);
      setActionSuccess(null);
      loadCase();
    }
  }, [isOpen, personId]);

  if (!isOpen) return null;

  // Status Dialog Handlers
  const handleOpenStatusModal = () => {
    setSelectedNewStatus('');
    setVerifiedConfirmation(false);
    setStatusRemarks('');
    setStatusDialogError(null);
    setIsStatusModalOpen(true);
  };

  const handleCloseStatusModal = () => {
    if (savingStatus) return;
    setIsStatusModalOpen(false);
    setStatusDialogError(null);
  };

  const handleStatusSubmit = async (e) => {
    e.preventDefault();
    if (!selectedNewStatus) {
      setStatusDialogError('Please select a target status.');
      return;
    }
    if (selectedNewStatus.toLowerCase() === caseData?.status?.toLowerCase()) {
      setStatusDialogError(`The case is already marked as "${caseData?.status}". Please select a different status.`);
      return;
    }
    if (selectedNewStatus === 'Found' && !verifiedConfirmation) {
      setStatusDialogError('Officer verification confirmation is required before marking a missing person as Found.');
      return;
    }

    setSavingStatus(true);
    setStatusDialogError(null);

    try {
      const res = await updateCaseStatus(
        personId,
        selectedNewStatus,
        verifiedConfirmation,
        statusRemarks.trim()
      );

      // Update local case state
      setCaseData((prev) => ({
        ...prev,
        status: res.status || selectedNewStatus
      }));

      setActionSuccess(
        `Case status successfully updated from "${res.previous_status || caseData?.status}" to "${res.status}".`
      );
      setIsStatusModalOpen(false);

      // Refresh parent lists and status counts
      if (onCaseUpdated) {
        onCaseUpdated();
      }
    } catch (err) {
      console.error('Status update failed:', err);
      setStatusDialogError(err.message || 'Failed to update case status.');
    } finally {
      setSavingStatus(false);
    }
  };

  // Handle Save Edit
  const handleSaveEdit = async (e) => {
    e.preventDefault();
    setSavingEdit(true);
    setErrorMessage(null);
    setActionSuccess(null);

    const payload = {};
    if (editForm.full_name.trim()) payload.full_name = editForm.full_name.trim();
    payload.age = editForm.age.trim() !== '' ? parseInt(editForm.age, 10) : null;
    payload.gender = editForm.gender ? editForm.gender : null;
    if (editForm.last_seen_date) {
      try {
        payload.last_seen_date = new Date(editForm.last_seen_date).toISOString();
      } catch {
        payload.last_seen_date = null;
      }
    } else {
      payload.last_seen_date = null;
    }
    payload.latitude = editForm.latitude.trim() !== '' ? parseFloat(editForm.latitude) : null;
    payload.longitude = editForm.longitude.trim() !== '' ? parseFloat(editForm.longitude) : null;
    payload.description = editForm.description.trim() ? editForm.description.trim() : null;

    try {
      await updateMissingPerson(personId, payload);
      setActionSuccess('Case information successfully updated.');
      setIsEditing(false);
      await loadCase();
      if (onCaseUpdated) onCaseUpdated();
    } catch (err) {
      console.error('Update failed:', err);
      setErrorMessage(err.message || 'Failed to update case details.');
    } finally {
      setSavingEdit(false);
    }
  };

  // Handle Add Photo
  const handlePhotoSelect = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploadingPhoto(true);
    setErrorMessage(null);
    setActionSuccess(null);

    const formData = new FormData();
    formData.append('missing_person_image', file);

    try {
      await addCasePhoto(personId, formData);
      setActionSuccess('Reference photo added and facial embedding indexed successfully.');
      await loadCase();
      if (onCaseUpdated) onCaseUpdated();
    } catch (err) {
      console.error('Photo upload failed:', err);
      setErrorMessage(err.message || 'Could not upload reference photo.');
    } finally {
      setUploadingPhoto(false);
      if (photoInputRef.current) photoInputRef.current.value = '';
    }
  };

  // Handle Delete Photo
  const handleDeletePhoto = async (embeddingId) => {
    if (!window.confirm('Are you sure you want to remove this reference photo?')) return;

    setErrorMessage(null);
    setActionSuccess(null);

    try {
      await deleteCasePhoto(personId, embeddingId);
      setActionSuccess('Reference photo removed from case dossier.');
      await loadCase();
      if (onCaseUpdated) onCaseUpdated();
    } catch (err) {
      console.error('Delete photo failed:', err);
      setErrorMessage(err.message || 'Failed to delete photo.');
    }
  };

  const getStatusClass = (status) => {
    switch (status?.toLowerCase()) {
      case 'missing':
        return 'missing';
      case 'found':
        return 'found';
      default:
        return 'closed';
    }
  };

  return (
    <>
      <div className="modal-backdrop" onClick={onClose} role="dialog" aria-modal="true">
        <div className="modal-dialog wide" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-header">
          <div className="modal-header-titles">
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem' }}>
              <span className="case-code-pill">{caseData?.case_code || 'Loading...'}</span>
              <span className={`status-badge ${getStatusClass(caseData?.status)}`}>
                <span className="pulse-dot" />
                {caseData?.status || 'Unknown'}
              </span>
            </div>
            <h2 className="modal-title" style={{ marginTop: '0.25rem' }}>
              {caseData?.full_name || 'Case Dossier'}
            </h2>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            {caseData && (
              <button
                type="button"
                className="btn btn-secondary"
                style={{ fontSize: '0.8rem', padding: '0.45rem 0.85rem' }}
                onClick={handleOpenStatusModal}
                title="Change case status"
              >
                <ShieldAlert size={14} /> Change Status
              </button>
            )}
            <button type="button" className="btn-ghost btn-icon" onClick={onClose}>
              <X size={18} />
            </button>
          </div>
        </div>

        {/* Body */}
        <div className="modal-body">
          {loading ? (
            <div className="state-container">
              <div className="spinner" />
              <p className="state-title">Retrieving Case Dossier & Secure Photo Signatures...</p>
            </div>
          ) : (
            <>
              {errorMessage && (
                <div className="alert-banner error">
                  <AlertCircle size={18} className="shrink-0" />
                  <div>
                    <strong>Action Alert:</strong>
                    <p>{errorMessage}</p>
                  </div>
                </div>
              )}

              {actionSuccess && (
                <div className="alert-banner success">
                  <Check size={18} className="shrink-0" />
                  <div>
                    <p>{actionSuccess}</p>
                  </div>
                </div>
              )}

              <div className="dossier-grid">
                {/* Left Column: Personal Attributes */}
                <div className="dossier-card">
                  <div className="dossier-card-title">
                    <span>Dossier Information</span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '0.45rem' }}>
                      {!isEditing ? (
                        <>
                          <button
                            type="button"
                            className="btn btn-secondary"
                            style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                            onClick={handleOpenStatusModal}
                            title="Update case status (Missing / Found / Closed)"
                          >
                            <ShieldAlert size={13} /> Change Status
                          </button>
                          <button
                            type="button"
                            className="btn btn-secondary"
                            style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                            onClick={() => setIsEditing(true)}
                          >
                            <Edit2 size={13} /> Edit Details
                          </button>
                        </>
                      ) : (
                        <button
                          type="button"
                          className="btn btn-ghost"
                          style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                          onClick={() => setIsEditing(false)}
                        >
                          Cancel
                        </button>
                      )}
                    </div>
                  </div>

                  {!isEditing ? (
                    <div>
                      <div className="dossier-row">
                        <span className="dossier-label">Case Identifier</span>
                        <span className="dossier-value">{caseData?.case_code}</span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Full Name</span>
                        <span className="dossier-value">{caseData?.full_name}</span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Age</span>
                        <span className="dossier-value">{caseData?.age ? `${caseData.age} years` : 'Unrecorded'}</span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Gender</span>
                        <span className="dossier-value">{caseData?.gender || 'Unspecified'}</span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Status</span>
                        <span className="dossier-value" style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                          <span className={`status-badge ${getStatusClass(caseData?.status)}`}>
                            {caseData?.status}
                          </span>
                          <button
                            type="button"
                            className="btn btn-secondary"
                            style={{ padding: '0.2rem 0.5rem', fontSize: '0.72rem', height: 'auto', lineHeight: 1 }}
                            onClick={handleOpenStatusModal}
                            title="Change case status"
                          >
                            <ShieldAlert size={11} /> Change
                          </button>
                        </span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Last Seen Date</span>
                        <span className="dossier-value">
                          {caseData?.last_seen_date
                            ? new Date(caseData.last_seen_date).toLocaleString()
                            : 'Unrecorded'}
                        </span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Coordinates</span>
                        <span className="dossier-value">
                          {caseData?.latitude && caseData?.longitude
                            ? `${caseData.latitude.toFixed(4)}, ${caseData.longitude.toFixed(4)}`
                            : 'Unrecorded'}
                        </span>
                      </div>
                      <div className="dossier-row">
                        <span className="dossier-label">Filed On</span>
                        <span className="dossier-value">
                          {caseData?.created_at
                            ? new Date(caseData.created_at).toLocaleDateString()
                            : 'Unknown'}
                        </span>
                      </div>
                      <div style={{ marginTop: '1rem', paddingTop: '0.75rem', borderTop: '1px solid var(--color-border)' }}>
                        <span className="dossier-label" style={{ display: 'block', marginBottom: '0.35rem' }}>
                          Distinguishing Features & Narrative
                        </span>
                        <p style={{ fontSize: '0.82rem', color: 'var(--color-text-main)', lineHeight: 1.5 }}>
                          {caseData?.description || 'No descriptive features recorded for this case.'}
                        </p>
                      </div>
                    </div>
                  ) : (
                    /* Edit Form */
                    <form onSubmit={handleSaveEdit}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.85rem' }}>
                        <div className="form-group">
                          <label className="form-label">Full Name *</label>
                          <input
                            type="text"
                            className="form-input"
                            value={editForm.full_name}
                            onChange={(e) => setEditForm({ ...editForm, full_name: e.target.value })}
                            required
                          />
                        </div>

                        <div className="form-group">
                          <label className="form-label">Age</label>
                          <input
                            type="number"
                            min="0"
                            max="120"
                            className="form-input"
                            value={editForm.age}
                            onChange={(e) => setEditForm({ ...editForm, age: e.target.value })}
                          />
                        </div>

                        <div className="form-group">
                          <label className="form-label">Gender</label>
                          <select
                            className="form-select"
                            value={editForm.gender}
                            onChange={(e) => setEditForm({ ...editForm, gender: e.target.value })}
                          >
                            <option value="">Select Gender</option>
                            <option value="Male">Male</option>
                            <option value="Female">Female</option>
                            <option value="Other">Other</option>
                            <option value="Unspecified">Unspecified</option>
                          </select>
                        </div>

                        <div className="form-group">
                          <label className="form-label">Last Seen Date & Time</label>
                          <input
                            type="datetime-local"
                            className="form-input"
                            value={editForm.last_seen_date}
                            onChange={(e) => setEditForm({ ...editForm, last_seen_date: e.target.value })}
                          />
                        </div>

                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem' }}>
                          <div className="form-group">
                            <label className="form-label">Latitude</label>
                            <input
                              type="number"
                              step="any"
                              className="form-input"
                              value={editForm.latitude}
                              onChange={(e) => setEditForm({ ...editForm, latitude: e.target.value })}
                            />
                          </div>
                          <div className="form-group">
                            <label className="form-label">Longitude</label>
                            <input
                              type="number"
                              step="any"
                              className="form-input"
                              value={editForm.longitude}
                              onChange={(e) => setEditForm({ ...editForm, longitude: e.target.value })}
                            />
                          </div>
                        </div>

                        <div className="form-group">
                          <label className="form-label">Description</label>
                          <textarea
                            className="form-textarea"
                            value={editForm.description}
                            onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                          />
                        </div>

                        <div className="alert-banner warning" style={{ padding: '0.5rem 0.75rem', fontSize: '0.72rem' }}>
                          <AlertCircle size={14} className="shrink-0" />
                          <span>Status changes (e.g. Found / Closed) are restricted by court/jurisdiction protocol and not modified here.</span>
                        </div>

                        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '0.5rem' }}>
                          <button
                            type="button"
                            className="btn btn-secondary"
                            onClick={() => setIsEditing(false)}
                            disabled={savingEdit}
                          >
                            Cancel
                          </button>
                          <button
                            type="submit"
                            className="btn btn-primary"
                            disabled={savingEdit}
                          >
                            {savingEdit ? 'Saving...' : 'Save Changes'}
                          </button>
                        </div>
                      </div>
                    </form>
                  )}
                </div>

                {/* Right Column: Reference Photos Management */}
                <div className="dossier-card">
                  <div className="dossier-card-title">
                    <span>
                      Reference Biometric Photos ({caseData?.photos?.length || 0})
                    </span>
                    <button
                      type="button"
                      className="btn btn-primary"
                      style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                      onClick={() => photoInputRef.current?.click()}
                      disabled={uploadingPhoto}
                    >
                      {uploadingPhoto ? (
                        <>
                          <Loader2 size={12} className="animate-spin" /> Indexing...
                        </>
                      ) : (
                        <>
                          <Plus size={13} /> Add Photo
                        </>
                      )}
                    </button>
                    <input
                      type="file"
                      ref={photoInputRef}
                      accept="image/jpeg,image/png,image/webp"
                      style={{ display: 'none' }}
                      onChange={handlePhotoSelect}
                    />
                  </div>

                  <p style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', marginBottom: '0.75rem' }}>
                    Photos are securely stored in the private Storage bucket. Time-limited signed URLs are generated
                    on-the-fly. Each photo must contain exactly one face.
                  </p>

                  <div className="photos-gallery-grid">
                    {caseData?.photos?.map((photo, index) => (
                      <div key={photo.embedding_id || index} className="photo-card">
                        <img
                          src={photo.signed_url}
                          alt={`Reference ${index + 1}`}
                          className="photo-card-img"
                          loading="lazy"
                        />
                        <div className="photo-card-overlay">
                          <span className="score-badge" title="InsightFace detection score">
                            {photo.detection_score
                              ? `${(photo.detection_score * 100).toFixed(0)}% Match`
                              : 'Indexed'}
                          </span>
                          <button
                            type="button"
                            className="btn-delete-photo"
                            title="Delete this reference photo"
                            onClick={() => handleDeletePhoto(photo.embedding_id)}
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>
                    ))}

                    {/* Dropzone card */}
                    <div
                      className="add-photo-dropzone"
                      onClick={() => photoInputRef.current?.click()}
                    >
                      <Plus size={24} />
                      <span>{uploadingPhoto ? 'Extracting Face...' : 'Add Another Photo'}</span>
                      <span style={{ fontSize: '0.68rem', color: 'var(--color-text-light)' }}>
                        Multi-angle photos improve sighting match accuracy
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="modal-footer" style={{ justifyContent: 'space-between' }}>
          <div>
            <button
              type="button"
              className="btn btn-secondary"
              onClick={handleOpenStatusModal}
              disabled={loading || !caseData}
            >
              <ShieldAlert size={14} /> Change Status
            </button>
          </div>
          <button type="button" className="btn btn-primary" onClick={onClose}>
            Close Dossier
          </button>
        </div>
      </div>
    </div>

    {/* Change Status Modal Dialog */}
      {isStatusModalOpen && (
        <div
          className="modal-backdrop"
          style={{ zIndex: 60 }}
          onClick={handleCloseStatusModal}
          role="dialog"
          aria-modal="true"
        >
          <div
            className="modal-dialog status-change-dialog"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header">
              <div className="modal-header-titles">
                <span className="case-code-pill" style={{ width: 'fit-content', marginBottom: '0.25rem' }}>
                  {caseData?.case_code || 'CASE'}
                </span>
                <h3 className="modal-title">Change Case Status</h3>
                <span className="modal-subtitle">
                  Update official law enforcement status for <strong>{caseData?.full_name}</strong>
                </span>
              </div>
              <button
                type="button"
                className="btn-ghost btn-icon"
                onClick={handleCloseStatusModal}
                disabled={savingStatus}
              >
                <X size={18} />
              </button>
            </div>

            <form onSubmit={handleStatusSubmit} className="modal-form">
              <div className="modal-body">
                {statusDialogError && (
                  <div className="alert-banner error" style={{ marginBottom: '1rem' }}>
                    <AlertCircle size={18} className="shrink-0" />
                    <div>
                      <strong>Validation Error:</strong>
                      <p>{statusDialogError}</p>
                    </div>
                  </div>
                )}

                {/* Transition Banner */}
                <div className="status-transition-banner">
                  <div className="transition-step">
                    <span className="transition-label">Current Status</span>
                    <span className={`status-badge ${getStatusClass(caseData?.status)}`}>
                      <span className="pulse-dot" />
                      {caseData?.status}
                    </span>
                  </div>
                  <ArrowRight size={18} color="var(--color-text-light)" />
                  <div className="transition-step" style={{ alignItems: 'flex-end' }}>
                    <span className="transition-label">Target Status</span>
                    {selectedNewStatus ? (
                      <span className={`status-badge ${getStatusClass(selectedNewStatus)}`}>
                        <span className="pulse-dot" />
                        {selectedNewStatus}
                      </span>
                    ) : (
                      <span style={{ fontSize: '0.8rem', color: 'var(--color-text-light)', fontStyle: 'italic' }}>
                        Select below
                      </span>
                    )}
                  </div>
                </div>

                <div className="form-group" style={{ marginBottom: '0.5rem' }}>
                  <label className="form-label">
                    Select New Case Status <span className="required-star">*</span>
                  </label>
                  <p className="form-hint" style={{ marginBottom: '0.65rem' }}>
                    Choose the new operational classification according to official investigative protocols.
                  </p>
                </div>

                {/* Status Choices List */}
                <div className="status-choice-list">
                  {/* Option 1: Missing */}
                  <div
                    className={`status-choice-card status-missing ${
                      selectedNewStatus === 'Missing' ? 'is-selected' : ''
                    } ${caseData?.status?.toLowerCase() === 'missing' ? 'is-current' : ''}`}
                    onClick={() => {
                      if (caseData?.status?.toLowerCase() !== 'missing') {
                        setSelectedNewStatus('Missing');
                        setStatusDialogError(null);
                      }
                    }}
                  >
                    <div className="status-radio-indicator">
                      {selectedNewStatus === 'Missing' && <div className="status-radio-dot" />}
                    </div>
                    <div className="status-choice-info">
                      <div className="status-choice-header">
                        <span className="status-choice-title">Active Missing</span>
                        {caseData?.status?.toLowerCase() === 'missing' && (
                          <span className="status-current-tag">Current</span>
                        )}
                        <span className="status-badge missing" style={{ marginLeft: 'auto' }}>
                          Missing
                        </span>
                      </div>
                      <p className="status-choice-desc">
                        Active investigation and field search operations ongoing. System cross-references all citizen sightings with 512-D face vectors.
                      </p>
                    </div>
                  </div>

                  {/* Option 2: Found */}
                  <div
                    className={`status-choice-card status-found ${
                      selectedNewStatus === 'Found' ? 'is-selected' : ''
                    } ${caseData?.status?.toLowerCase() === 'found' ? 'is-current' : ''}`}
                    onClick={() => {
                      if (caseData?.status?.toLowerCase() !== 'found') {
                        setSelectedNewStatus('Found');
                        setStatusDialogError(null);
                      }
                    }}
                  >
                    <div className="status-radio-indicator">
                      {selectedNewStatus === 'Found' && <div className="status-radio-dot" />}
                    </div>
                    <div className="status-choice-info">
                      <div className="status-choice-header">
                        <span className="status-choice-title">Located & Identified</span>
                        {caseData?.status?.toLowerCase() === 'found' && (
                          <span className="status-current-tag">Current</span>
                        )}
                        <span className="status-badge found" style={{ marginLeft: 'auto' }}>
                          Found
                        </span>
                      </div>
                      <p className="status-choice-desc">
                        Missing individual has been physically found, verified, and accounted for. Requires official officer confirmation before saving.
                      </p>
                    </div>
                  </div>

                  {/* Option 3: Closed */}
                  <div
                    className={`status-choice-card status-closed ${
                      selectedNewStatus === 'Closed' ? 'is-selected' : ''
                    } ${caseData?.status?.toLowerCase() === 'closed' ? 'is-current' : ''}`}
                    onClick={() => {
                      if (caseData?.status?.toLowerCase() !== 'closed') {
                        setSelectedNewStatus('Closed');
                        setStatusDialogError(null);
                      }
                    }}
                  >
                    <div className="status-radio-indicator">
                      {selectedNewStatus === 'Closed' && <div className="status-radio-dot" />}
                    </div>
                    <div className="status-choice-info">
                      <div className="status-choice-header">
                        <span className="status-choice-title">Closed / Concluded</span>
                        {caseData?.status?.toLowerCase() === 'closed' && (
                          <span className="status-current-tag">Current</span>
                        )}
                        <span className="status-badge closed" style={{ marginLeft: 'auto' }}>
                          Closed
                        </span>
                      </div>
                      <p className="status-choice-desc">
                        Investigation formally concluded or archived per jurisdictional and department guidelines. Active sighting alerts discontinued.
                      </p>
                    </div>
                  </div>
                </div>

                {/* Mandatory Officer Verification Safeguard when Marking Found */}
                {selectedNewStatus === 'Found' && (
                  <div className="safeguard-box">
                    <div className="safeguard-title-row">
                      <ShieldAlert size={18} className="shrink-0" />
                      <span>Protocol Safeguard: Officer Verification Required</span>
                    </div>
                    <p className="safeguard-desc">
                      AI facial match scores, similarity percentages, or citizen sighting submissions alone
                      <strong> MUST NOT</strong> be used to mark a person as Found. Direct physical verification by
                      authorized police officers or legal guardians is legally required.
                    </p>
                    <label className="safeguard-checkbox-label">
                      <input
                        type="checkbox"
                        checked={verifiedConfirmation}
                        onChange={(e) => {
                          setVerifiedConfirmation(e.target.checked);
                          if (e.target.checked && statusDialogError) {
                            setStatusDialogError(null);
                          }
                        }}
                      />
                      <span>
                        I confirm that the missing person&apos;s identity and physical safety have been officially verified by an officer in the field.
                      </span>
                    </label>
                  </div>
                )}

                {/* Optional Officer Remarks */}
                <div className="form-group" style={{ marginTop: '0.85rem' }}>
                  <label className="form-label">
                    Officer Remarks & Disposition Notes (Optional)
                  </label>
                  <textarea
                    className="form-textarea"
                    placeholder="Enter case disposition details (e.g., Safely reunited with parents at Santacruz Police Station; Medical clearance obtained)..."
                    value={statusRemarks}
                    onChange={(e) => setStatusRemarks(e.target.value)}
                    style={{ minHeight: '65px' }}
                    disabled={savingStatus}
                  />
                  <span className="form-hint">
                    Remarks are recorded with the status update and stored with the official record.
                  </span>
                </div>
              </div>

              {/* Status Dialog Footer */}
              <div className="modal-footer">
                <button
                  type="button"
                  className="btn btn-secondary"
                  onClick={handleCloseStatusModal}
                  disabled={savingStatus}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={
                    savingStatus ||
                    !selectedNewStatus ||
                    selectedNewStatus.toLowerCase() === caseData?.status?.toLowerCase() ||
                    (selectedNewStatus === 'Found' && !verifiedConfirmation)
                  }
                >
                  {savingStatus ? (
                    <>
                      <Loader2 size={14} className="animate-spin" /> Updating Status...
                    </>
                  ) : (
                    <>
                      <Check size={14} /> Confirm & Update Status
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
