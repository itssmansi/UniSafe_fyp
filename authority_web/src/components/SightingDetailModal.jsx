import React, { useState, useEffect } from 'react';
import {
  X,
  AlertCircle,
  Eye,
  CheckCircle,
  Sparkles,
  ExternalLink,
  User,
  RefreshCw,
  Loader2,
  RotateCcw
} from 'lucide-react';
import { getSightingDetail, findSightingMatches, updateSightingVerification } from '../services/api';

export default function SightingDetailModal({
  sightingId,
  isOpen,
  onClose,
  onOpenCaseDossier,
  onSightingUpdated
}) {
  const [sighting, setSighting] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [imageError, setImageError] = useState(false);

  // Find Matches states
  const [matchingLoading, setMatchingLoading] = useState(false);
  const [matchingError, setMatchingError] = useState(null);
  const [matchingSuccess, setMatchingSuccess] = useState(null);

  // Officer Verification Action states
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState(null);
  const [actionSuccess, setActionSuccess] = useState(null);

  useEffect(() => {
    if (isOpen) {
      const originalOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  }, [isOpen]);

  const fetchSighting = () => {
    if (!sightingId) return;
    setLoading(true);
    setError(null);
    setImageError(false);
    setMatchingError(null);
    setMatchingSuccess(null);
    setActionError(null);
    setActionSuccess(null);

    getSightingDetail(sightingId)
      .then((data) => setSighting(data))
      .catch((err) => {
        console.error('[UniSafe Sighting Preview] Failed to retrieve sighting details:', {
          sightingId,
          errorMessage: err.message,
          status: err.status,
          errorData: err.data,
          error: err,
        });
        setError(err.message || 'Could not fetch sighting details');
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    if (isOpen && sightingId) {
      fetchSighting();
    }
  }, [isOpen, sightingId]);

  const handleFindMatches = async () => {
    if (!sightingId || matchingLoading) return;
    setMatchingLoading(true);
    setMatchingError(null);
    setMatchingSuccess(null);

    try {
      console.log(`[UniSafe Face Matching] Initiating face matching for sighting ID: ${sightingId}...`);
      const result = await findSightingMatches(sightingId);
      console.log('[UniSafe Face Matching] Matching response received:', result);

      // Update local sighting record with fresh inferences
      setSighting((prev) => ({
        ...prev,
        missing_person_id: result.matched_person_id,
        ai_matches: result.ai_matches || [],
        candidate_cases: result.candidate_cases || [],
      }));

      const topMatch = result.top_match;
      if (topMatch) {
        setMatchingSuccess(
          `Face match found with ${(topMatch.similarity_score * 100).toFixed(1)}% similarity!`
        );
      } else {
        const hasCandidates = result.candidate_cases && result.candidate_cases.length > 0;
        setMatchingSuccess(
          hasCandidates
            ? `Matching evaluated ${result.candidate_cases.length} registered candidate profile(s).`
            : 'Matching evaluated against active missing-person reference profiles.'
        );
      }

      if (onSightingUpdated) {
        onSightingUpdated(sightingId, result);
      }
    } catch (err) {
      console.error('[UniSafe Face Matching] Face matching failed for sighting:', {
        sightingId,
        errorMessage: err.message,
        status: err.status,
        errorData: err.data,
        error: err,
      });
      setMatchingError(
        err.message || 'Face matching service failed. Please check server logs.'
      );
    } finally {
      setMatchingLoading(false);
    }
  };

  const handleVerificationAction = async (action) => {
    if (!sightingId) return;
    setActionLoading(true);
    setActionError(null);
    setActionSuccess(null);

    try {
      const res = await updateSightingVerification(sightingId, action);
      setActionSuccess(res.message || `Sighting ${action === 'verify' ? 'verified' : 'rejected'} successfully.`);
      setSighting((prev) => ({
        ...prev,
        is_verified: res.is_verified,
        missing_person_id: res.is_verified ? prev?.missing_person_id : (action === 'reject' ? null : prev?.missing_person_id)
      }));
      if (onSightingUpdated) {
        onSightingUpdated(sightingId, res);
      }
    } catch (err) {
      console.error('Failed to update sighting verification:', err);
      setActionError(err.message || 'Failed to update verification status.');
    } finally {
      setActionLoading(false);
    }
  };

  if (!isOpen) return null;

  // Derive candidate cases list from either enriched candidate_cases or raw ai_matches
  const candidateCases = sighting?.candidate_cases || [];

  return (
    <div className="modal-backdrop" onClick={onClose} role="dialog" aria-modal="true">
      <div className="modal-dialog wide" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="modal-header">
          <div className="modal-header-titles">
            <span className="case-code-pill" style={{ width: 'fit-content', marginBottom: '0.25rem' }}>
              Sighting Review: {sighting?.id ? sighting.id.substring(0, 8) + '...' : 'Loading'}
            </span>
            <h2 className="modal-title">Citizen Sighting Verification Station</h2>
          </div>
          <button type="button" className="btn-ghost btn-icon" onClick={onClose} title="Close Modal">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="modal-body">
          {loading ? (
            <div className="state-container">
              <div className="spinner" />
              <p className="state-title">Retrieving Sighting Image & AI Comparison Vector...</p>
            </div>
          ) : error ? (
            <div className="alert-banner error" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: '0.75rem', padding: '1.25rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <AlertCircle size={20} className="shrink-0" />
                <strong style={{ fontSize: '0.95rem' }}>Sighting Record Unavailable</strong>
              </div>
              <p style={{ margin: 0, fontSize: '0.88rem', lineHeight: 1.5 }}>
                {error.includes('signed image URL')
                  ? 'Could not generate a secure signed URL for the sighting image from Supabase Storage. The image file may be missing from the private storage bucket or storage credentials could not be verified.'
                  : error}
              </p>
              <p style={{ margin: 0, fontSize: '0.78rem', color: '#B91C1C' }}>
                Full diagnostic information and error details have been logged to the developer console.
              </p>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ marginTop: '0.25rem', padding: '0.4rem 0.85rem', fontSize: '0.82rem' }}
                onClick={fetchSighting}
              >
                <RefreshCw size={14} /> Retry Loading Sighting
              </button>
            </div>
          ) : (
            <div className="dossier-grid">
              {/* Sighting Photo Card */}
              <div className="dossier-card">
                <div className="dossier-card-title">
                  <span>Citizen Uploaded Photo</span>
                  {sighting?.is_verified ? (
                    <span className="status-badge found">
                      <CheckCircle size={12} /> Verified
                    </span>
                  ) : (
                    <span className="status-badge missing">
                      <Eye size={12} /> Pending Review
                    </span>
                  )}
                </div>

                {sighting?.signed_image_url && !imageError ? (
                  <img
                    src={sighting.signed_image_url}
                    alt="Sighting Subject"
                    onError={(e) => {
                      console.error('[UniSafe Image Preview] Sighting image failed to load from signed URL:', {
                        signedUrl: sighting.signed_image_url,
                        imagePath: sighting.image_path,
                        event: e,
                      });
                      setImageError(true);
                    }}
                    style={{
                      width: '100%',
                      maxHeight: '320px',
                      objectFit: 'contain',
                      borderRadius: 'var(--radius-md)',
                      background: '#0F172A',
                      border: '1px solid var(--color-border)',
                      display: 'block',
                    }}
                  />
                ) : (
                  <div
                    className="state-container"
                    style={{
                      padding: '2.5rem 1.5rem',
                      background: '#F8FAFC',
                      borderRadius: 'var(--radius-md)',
                      border: '1px dashed var(--color-border)',
                    }}
                  >
                    <AlertCircle size={28} color="var(--color-amber)" />
                    <p style={{ color: 'var(--color-text-muted)', fontSize: '0.88rem', marginTop: '0.5rem', fontWeight: 600 }}>
                      Sighting Image Preview Unavailable
                    </p>
                    <p style={{ color: 'var(--color-text-light)', fontSize: '0.78rem', marginTop: '0.25rem', textAlign: 'center' }}>
                      {imageError
                        ? 'Image failed to render in the browser. Signed URL may have expired.'
                        : 'Signed image URL is missing or storage object could not be resolved.'}
                    </p>
                    {sighting?.image_path && (
                      <span style={{ fontSize: '0.72rem', color: 'var(--color-text-light)', fontFamily: 'monospace', marginTop: '0.5rem' }}>
                        Path: {sighting.image_path}
                      </span>
                    )}
                  </div>
                )}

                <div style={{ marginTop: '1rem' }}>
                  {sighting?.address && (
                    <div className="dossier-row">
                      <span className="dossier-label">Address</span>
                      <span className="dossier-value" style={{ wordBreak: 'break-word' }}>
                        {sighting.address}
                      </span>
                    </div>
                  )}
                  {sighting?.latitude != null && sighting?.longitude != null && (
                    <div className="dossier-row">
                      <span className="dossier-label">Coordinates</span>
                      <span className="dossier-value">
                        {`${Number(sighting.latitude).toFixed(4)}, ${Number(sighting.longitude).toFixed(4)}`}
                      </span>
                    </div>
                  )}
                  {!sighting?.address && (sighting?.latitude == null || sighting?.longitude == null) && (
                    <div className="dossier-row">
                      <span className="dossier-label">Location</span>
                      <span className="dossier-value">Location not provided</span>
                    </div>
                  )}
                  <div className="dossier-row">
                    <span className="dossier-label">Timestamp</span>
                    <span className="dossier-value">
                      {sighting?.created_at ? new Date(sighting.created_at).toLocaleString() : 'N/A'}
                    </span>
                  </div>
                  <div className="dossier-row">
                    <span className="dossier-label">Verification</span>
                    <span className="dossier-value" style={{ color: sighting?.is_verified ? 'var(--color-teal)' : 'var(--color-amber)' }}>
                      {sighting?.is_verified ? 'Officer Verified' : 'AI Inference Only (Unverified)'}
                    </span>
                  </div>
                </div>

                {/* Citizen Suggested Person Banner (Informational Only - Not an AI Match) */}
                {sighting?.citizen_note && (
                  <div
                    style={{
                      marginTop: '1rem',
                      padding: '0.85rem 1rem',
                      borderRadius: 'var(--radius-md)',
                      background: '#F1F5F9',
                      border: '1px solid #CBD5E1',
                      display: 'flex',
                      gap: '0.65rem',
                      alignItems: 'flex-start',
                    }}
                  >
                    <User size={18} color="#475569" style={{ marginTop: '0.15rem', flexShrink: 0 }} />
                    <div>
                      <div style={{ fontSize: '0.75rem', fontWeight: 700, color: '#334155', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
                        Citizen Suggestion (Unverified)
                      </div>
                      <p style={{ margin: '0.25rem 0 0', fontSize: '0.84rem', color: '#1E293B', lineHeight: 1.45 }}>
                        {sighting.citizen_note}
                      </p>
                      <span style={{ display: 'inline-block', marginTop: '0.35rem', fontSize: '0.72rem', color: '#64748B', fontStyle: 'italic' }}>
                        Note: Citizen opinion only — not an AI match or confirmed identification.
                      </span>
                    </div>
                  </div>
                )}

                {/* Officer Review & Verification Action Panel */}
                <div
                  style={{
                    marginTop: '1.25rem',
                    padding: '1rem',
                    borderRadius: 'var(--radius-md)',
                    background: '#F8FAFC',
                    border: '1px solid var(--color-border)',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.45rem' }}>
                    <span style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--color-dark)' }}>
                      Officer Verification Decision
                    </span>
                    {sighting?.is_verified ? (
                      <span className="status-badge found" style={{ fontSize: '0.68rem' }}>
                        <CheckCircle size={10} /> Verified
                      </span>
                    ) : (
                      <span className="status-badge missing" style={{ fontSize: '0.68rem' }}>
                        <Eye size={10} /> Pending
                      </span>
                    )}
                  </div>

                  <p style={{ fontSize: '0.74rem', color: 'var(--color-text-muted)', marginBottom: '0.75rem', lineHeight: 1.4 }}>
                    Corroborate whether this citizen photograph depicts the subject at this location.
                    <br />
                    <em style={{ color: 'var(--color-text-light)' }}>
                      Verifying a sighting confirms visual evidence. Declaring a person found requires an explicit case status update.
                    </em>
                  </p>

                  {actionError && (
                    <div className="alert-banner error" style={{ padding: '0.4rem 0.6rem', fontSize: '0.75rem', marginBottom: '0.5rem' }}>
                      <AlertCircle size={14} className="shrink-0" />
                      <span>{actionError}</span>
                    </div>
                  )}

                  {actionSuccess && (
                    <div className="alert-banner success" style={{ padding: '0.4rem 0.6rem', fontSize: '0.75rem', marginBottom: '0.5rem' }}>
                      <CheckCircle size={14} className="shrink-0" />
                      <span>{actionSuccess}</span>
                    </div>
                  )}

                  <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {!sighting?.is_verified ? (
                      <>
                        <button
                          type="button"
                          className="btn btn-primary"
                          style={{ fontSize: '0.78rem', padding: '0.4rem 0.75rem', flex: 1, whiteSpace: 'nowrap' }}
                          onClick={() => handleVerificationAction('verify')}
                          disabled={actionLoading}
                        >
                          {actionLoading ? <Loader2 size={13} className="animate-spin" /> : <CheckCircle size={13} />}
                          <span>Verify Sighting</span>
                        </button>
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ fontSize: '0.78rem', padding: '0.4rem 0.75rem', flex: 1, borderColor: '#fca5a5', color: '#b91c1c', whiteSpace: 'nowrap' }}
                          onClick={() => handleVerificationAction('reject')}
                          disabled={actionLoading}
                        >
                          <X size={13} />
                          <span>Reject Match</span>
                        </button>
                      </>
                    ) : (
                      <button
                        type="button"
                        className="btn btn-secondary"
                        style={{ fontSize: '0.78rem', padding: '0.4rem 0.75rem', width: '100%' }}
                        onClick={() => handleVerificationAction('reject')}
                        disabled={actionLoading}
                      >
                        {actionLoading ? <Loader2 size={13} className="animate-spin" /> : <RotateCcw size={13} />}
                        <span>Revoke Verification (Mark Unverified)</span>
                      </button>
                    )}
                  </div>
                </div>
              </div>

              {/* AI Match Comparison Card */}
              <div className="dossier-card">
                <div className="dossier-card-title" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.5rem' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '0.45rem' }}>
                    <Sparkles size={16} color="#D97706" /> AI Facial Match Candidates
                  </span>
                  <button
                    type="button"
                    className="btn btn-primary"
                    style={{ padding: '0.35rem 0.75rem', fontSize: '0.8rem', whiteSpace: 'nowrap' }}
                    onClick={handleFindMatches}
                    disabled={matchingLoading}
                    title="Rerun face matching against currently registered missing persons"
                  >
                    <Sparkles size={14} className={matchingLoading ? 'animate-spin' : ''} />
                    {matchingLoading ? 'Scanning Cases...' : 'Find Matches'}
                  </button>
                </div>

                {/* Match Banner: Active / Loading / Error states */}
                {matchingLoading ? (
                  <div
                    className="state-container"
                    style={{
                      padding: '1.5rem',
                      background: 'var(--color-midnight-light)',
                      borderRadius: 'var(--radius-md)',
                      marginBottom: '1rem',
                      border: '1px solid rgba(30, 58, 95, 0.15)'
                    }}
                  >
                    <div className="spinner" />
                    <p className="state-title" style={{ marginTop: '0.5rem', fontSize: '0.9rem', color: 'var(--color-midnight)' }}>
                      Comparing Facial Vectors Against Registered Cases...
                    </p>
                    <p style={{ fontSize: '0.78rem', color: 'var(--color-text-muted)', margin: 0 }}>
                      Evaluating 512-D InsightFace ArcFace cosine embeddings against active reference profiles.
                    </p>
                  </div>
                ) : matchingError ? (
                  <div className="alert-banner error" style={{ marginBottom: '1rem' }}>
                    <AlertCircle size={18} className="shrink-0" />
                    <div>
                      <strong>Face Matching Failed</strong>
                      <p style={{ marginTop: '0.2rem', fontSize: '0.82rem' }}>{matchingError}</p>
                      <button
                        type="button"
                        className="btn btn-secondary"
                        style={{ marginTop: '0.4rem', padding: '0.25rem 0.6rem', fontSize: '0.75rem' }}
                        onClick={handleFindMatches}
                      >
                        <RefreshCw size={12} /> Retry Matching
                      </button>
                    </div>
                  </div>
                ) : matchingSuccess ? (
                  <div className="alert-banner success" style={{ marginBottom: '1rem' }}>
                    <CheckCircle size={18} className="shrink-0" />
                    <div>
                      <strong>Face Matching Complete</strong>
                      <p style={{ marginTop: '0.2rem', fontSize: '0.82rem' }}>{matchingSuccess}</p>
                    </div>
                  </div>
                ) : null}

                {/* Linked High-Confidence Case Banner */}
                {sighting?.missing_person_id ? (
                  sighting?.is_case_resolved ? (
                    <div className="alert-banner" style={{ marginBottom: '1rem', background: '#F1F5F9', borderColor: '#CBD5E1', color: '#334155' }}>
                      <CheckCircle size={18} className="shrink-0" color="#64748B" />
                      <div>
                        <strong>Historical Sighting — Linked Case Resolved ({sighting?.linked_case?.status || 'Found'})</strong>
                        <p style={{ marginTop: '0.2rem', fontSize: '0.84rem', color: '#475569' }}>
                          This sighting is linked to Case <strong>{sighting.linked_case?.case_code || ''} ({sighting.linked_case?.full_name || 'Subject'})</strong>, which was resolved as <strong>{sighting.linked_case?.status || 'Found'}</strong>. The historical sighting record is archived, and no active search operations are required.
                        </p>
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ marginTop: '0.5rem', padding: '0.35rem 0.75rem', fontSize: '0.78rem' }}
                          onClick={() => {
                            onClose();
                            if (onOpenCaseDossier) onOpenCaseDossier(sighting.missing_person_id);
                          }}
                        >
                          <ExternalLink size={13} /> View Resolved Case Dossier
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="alert-banner success" style={{ marginBottom: '1rem' }}>
                      <CheckCircle size={18} className="shrink-0" />
                      <div>
                        <strong>Active Case Match Identified</strong>
                        <p style={{ marginTop: '0.2rem', fontSize: '0.84rem' }}>
                          The AI engine identified a high cosine similarity match (&ge; 50%) with active case <strong>{sighting.linked_case?.case_code || ''} {sighting.linked_case?.full_name ? `(${sighting.linked_case.full_name})` : ''}</strong>.
                        </p>
                        <button
                          type="button"
                          className="btn btn-secondary"
                          style={{ marginTop: '0.5rem', padding: '0.35rem 0.75rem', fontSize: '0.78rem' }}
                          onClick={() => {
                            onClose();
                            if (onOpenCaseDossier) onOpenCaseDossier(sighting.missing_person_id);
                          }}
                        >
                          <ExternalLink size={13} /> Open Linked Case Dossier
                        </button>
                      </div>
                    </div>
                  )
                ) : (
                  <div className="alert-banner info" style={{ marginBottom: '1rem' }}>
                    <AlertCircle size={18} className="shrink-0" />
                    <div>
                      <strong>No Strong Confirmed Case Match</strong>
                      <p style={{ fontSize: '0.84rem', marginTop: '0.15rem' }}>
                        Face vectors did not meet the strong match threshold (&ge; 0.50). Click <strong>Find Matches</strong> to cross-reference against updated registered dossiers.
                      </p>
                    </div>
                  </div>
                )}

                {/* Candidate Cases List */}
                <h4 style={{ fontSize: '0.85rem', fontWeight: 700, marginBottom: '0.65rem', color: 'var(--color-dark)' }}>
                  Candidate Cases & Evaluated Profiles ({candidateCases.length || sighting?.ai_matches?.length || 0})
                </h4>

                {candidateCases.length > 0 ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', maxHeight: '360px', overflowY: 'auto' }}>
                    {candidateCases.map((c, idx) => {
                      const isHigh = c.similarity_score >= 0.50 || c.match_category === 'match';
                      const isPotential =
                        (c.similarity_score >= 0.35 && c.similarity_score < 0.50) ||
                        c.match_category === 'potential_match';

                      return (
                        <div
                          key={idx}
                          style={{
                            padding: '0.85rem',
                            borderRadius: 'var(--radius-md)',
                            border: `1px solid ${isHigh ? 'var(--color-teal-border)' : isPotential ? 'var(--color-amber-border)' : 'var(--color-border)'}`,
                            background: isHigh ? 'var(--color-teal-bg)' : isPotential ? 'var(--color-amber-bg)' : '#FFFFFF',
                            display: 'flex',
                            gap: '0.85rem',
                            alignItems: 'center',
                            transition: 'all 0.15s ease-in-out'
                          }}
                        >
                          {/* Reference Photo Preview */}
                          <div style={{ flexShrink: 0 }}>
                            {c.reference_photo_url ? (
                              <img
                                src={c.reference_photo_url}
                                alt={c.full_name || 'Candidate Reference'}
                                style={{
                                  width: '54px',
                                  height: '54px',
                                  objectFit: 'cover',
                                  borderRadius: 'var(--radius-md)',
                                  border: '1px solid var(--color-border)',
                                  background: '#0F172A'
                                }}
                              />
                            ) : (
                              <div
                                style={{
                                  width: '54px',
                                  height: '54px',
                                  borderRadius: 'var(--radius-md)',
                                  background: 'var(--bg-subtle)',
                                  border: '1px solid var(--color-border)',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center'
                                }}
                              >
                                <User size={22} color="var(--color-text-muted)" />
                              </div>
                            )}
                          </div>

                          {/* Candidate Case Info */}
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: '0.45rem', flexWrap: 'wrap' }}>
                              <span className="case-code-pill" style={{ fontSize: '0.72rem', padding: '0.15rem 0.45rem' }}>
                                {c.case_code || 'Case'}
                              </span>
                              <strong style={{ fontSize: '0.9rem', color: 'var(--color-dark)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                {c.full_name || 'Unknown Subject'}
                              </strong>
                            </div>

                            <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', marginTop: '0.2rem' }}>
                              {c.age ? `Age ${c.age}` : 'Age unknown'}{c.gender ? ` • ${c.gender}` : ''}
                              <span style={{ marginLeft: '0.45rem', color: 'var(--color-text-light)' }}>
                                (vs. Sighting Face #{c.face_index + 1})
                              </span>
                            </div>

                            <div style={{ marginTop: '0.45rem' }}>
                              <button
                                type="button"
                                className="btn btn-secondary"
                                style={{ padding: '0.25rem 0.6rem', fontSize: '0.74rem' }}
                                onClick={() => {
                                  onClose();
                                  if (onOpenCaseDossier) onOpenCaseDossier(c.missing_person_id);
                                }}
                              >
                                <ExternalLink size={12} /> View Case Dossier
                              </button>
                            </div>
                          </div>

                          {/* Similarity Metric Badge */}
                          <div style={{ textAlign: 'right', flexShrink: 0 }}>
                            <span
                              style={{
                                fontSize: '1.25rem',
                                fontWeight: 800,
                                color: isHigh ? 'var(--color-teal)' : isPotential ? 'var(--color-amber)' : 'var(--color-text-muted)'
                              }}
                            >
                              {(c.similarity_score * 100).toFixed(1)}%
                            </span>
                            <div style={{ fontSize: '0.68rem', textTransform: 'capitalize', fontWeight: 600, color: isHigh ? 'var(--color-teal)' : isPotential ? 'var(--color-amber)' : 'var(--color-text-light)' }}>
                              {isHigh ? 'Strong Match' : isPotential ? 'Potential Match' : 'Low Similarity'}
                            </div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : sighting?.ai_matches && sighting.ai_matches.length > 0 ? (
                  // Fallback if candidate_cases not yet enriched
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.65rem' }}>
                    {sighting.ai_matches.map((m, idx) => {
                      const isHigh = m.similarity_score >= 0.50;
                      const isPotential = m.similarity_score >= 0.35 && m.similarity_score < 0.50;

                      return (
                        <div
                          key={idx}
                          style={{
                            padding: '0.75rem',
                            borderRadius: 'var(--radius-md)',
                            border: '1px solid var(--color-border)',
                            background: isHigh ? 'var(--color-teal-bg)' : isPotential ? 'var(--color-amber-bg)' : '#F8FAFC',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'space-between'
                          }}
                        >
                          <div>
                            <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>
                              Face #{m.face_index + 1} vs. Case {m.missing_person_id ? m.missing_person_id.substring(0, 8) + '...' : 'Unknown'}
                            </span>
                            <div style={{ fontSize: '0.82rem', fontWeight: 700, color: 'var(--color-dark)', marginTop: '0.15rem' }}>
                              Status: <span style={{ textTransform: 'capitalize' }}>{m.match_category || m.status}</span>
                            </div>
                          </div>

                          <div style={{ textAlign: 'right' }}>
                            <span
                              style={{
                                fontSize: '1.1rem',
                                fontWeight: 800,
                                color: isHigh ? 'var(--color-teal)' : isPotential ? 'var(--color-amber)' : 'var(--color-text-muted)'
                              }}
                            >
                              {(m.similarity_score * 100).toFixed(1)}%
                            </span>
                            <div style={{ fontSize: '0.68rem', color: 'var(--color-text-light)' }}>Cosine Score</div>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="state-container" style={{ padding: '1.5rem', background: '#F8FAFC', borderRadius: 'var(--radius-md)' }}>
                    <p style={{ fontSize: '0.84rem', color: 'var(--color-text-muted)', margin: 0 }}>
                      No facial comparisons have been evaluated for this sighting record yet. Click <strong>Find Matches</strong> to run AI matching against registered cases.
                    </p>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="modal-footer" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-light)' }}>
            AI facial match candidates require human review and corroboration by an officer.
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Close
            </button>
            <button
              type="button"
              className="btn btn-primary"
              onClick={handleFindMatches}
              disabled={matchingLoading || loading}
            >
              <Sparkles size={15} className={matchingLoading ? 'animate-spin' : ''} />
              {matchingLoading ? 'Running Face Matching...' : 'Find Matches'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

