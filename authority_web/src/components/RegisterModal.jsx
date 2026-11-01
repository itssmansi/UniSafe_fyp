import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Upload,
  User,
  Calendar,
  MapPin,
  FileText,
  AlertCircle,
  Image as ImageIcon,
  CheckCircle2,
  Loader2
} from 'lucide-react';
import { createMissingPerson } from '../services/api';
import AddressSearchSelector from './AddressSearchSelector';

export default function RegisterModal({ isOpen, onClose, onSuccess }) {
  const [fullName, setFullName] = useState('');
  const [age, setAge] = useState('');
  const [gender, setGender] = useState('');
  const [lastSeenDate, setLastSeenDate] = useState('');
  const [description, setDescription] = useState('');
  const [selectedFile, setSelectedFile] = useState(null);
  const [filePreview, setFilePreview] = useState(null);

  // Address-based location resolution
  const [confirmedLocation, setConfirmedLocation] = useState(null);
  const [hasUnconfirmedSearch, setHasUnconfirmedSearch] = useState(false);

  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState(null);
  const fileInputRef = useRef(null);

  // Prevent background page from scrolling while modal is open
  useEffect(() => {
    if (isOpen) {
      const originalOverflow = document.body.style.overflow;
      document.body.style.overflow = 'hidden';
      return () => {
        document.body.style.overflow = originalOverflow;
      };
    }
  }, [isOpen]);

  // Reset form when opened
  useEffect(() => {
    if (isOpen) {
      setFullName('');
      setAge('');
      setGender('');
      setLastSeenDate('');
      setDescription('');
      setSelectedFile(null);
      setFilePreview(null);
      setConfirmedLocation(null);
      setHasUnconfirmedSearch(false);
      setErrorMessage(null);
      setLoading(false);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleFileChange = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate size (10MB)
    if (file.size > 10 * 1024 * 1024) {
      setErrorMessage('Selected image exceeds the 10 MB limit.');
      return;
    }

    setErrorMessage(null);
    setSelectedFile(file);

    const reader = new FileReader();
    reader.onload = () => {
      setFilePreview(reader.result);
    };
    reader.readAsDataURL(file);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setErrorMessage(null);

    // Client-side validations
    if (!fullName.trim()) {
      setErrorMessage('Full name is required.');
      return;
    }

    if (!selectedFile) {
      setErrorMessage('A reference photograph is required for biometric facial indexing.');
      return;
    }

    // Check if officer typed an address search but did not confirm a candidate
    if (hasUnconfirmedSearch) {
      setErrorMessage(
        'You entered an address search without selecting and confirming a location. Please select one of the matching search results, or clear the address search.'
      );
      return;
    }

    if (age && (Number(age) < 0 || Number(age) > 150)) {
      setErrorMessage('Age must be between 0 and 150.');
      return;
    }

    const formData = new FormData();
    formData.append('full_name', fullName.trim());
    if (age) formData.append('age', age.trim());
    if (gender) formData.append('gender', gender);

    if (lastSeenDate) {
      try {
        const iso = new Date(lastSeenDate).toISOString();
        formData.append('last_seen_date', iso);
      } catch {
        formData.append('last_seen_date', lastSeenDate);
      }
    }

    // Automatically resolve numeric coordinates from confirmed address
    if (confirmedLocation) {
      formData.append('latitude', String(confirmedLocation.lat));
      formData.append('longitude', String(confirmedLocation.lon));
    }

    // Append description and include full address text if available
    let finalDescription = description.trim();
    if (confirmedLocation?.displayName) {
      const locNotice = `Last Seen Address: ${confirmedLocation.displayName}`;
      finalDescription = finalDescription
        ? `${finalDescription}\n\n${locNotice}`
        : locNotice;
    }
    if (finalDescription) {
      formData.append('description', finalDescription);
    }

    formData.append('missing_person_image', selectedFile);

    setLoading(true);

    try {
      const response = await createMissingPerson(formData);
      onSuccess(response);
      onClose();
    } catch (err) {
      console.error('Registration failed:', err);
      setErrorMessage(err.message || 'Failed to register missing person report.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={onClose} role="dialog" aria-modal="true">
      <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
        {/* Fixed Header */}
        <div className="modal-header">
          <div className="modal-header-titles">
            <h2 className="modal-title">Register Missing Person</h2>
            <span className="modal-subtitle">
              Create an official law-enforcement dossier & extract biometric facial embedding
            </span>
          </div>
          <button
            type="button"
            className="btn-ghost btn-icon"
            onClick={onClose}
            aria-label="Close dialog"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable Form Body with Fixed Footer */}
        <form onSubmit={handleSubmit} id="register-form" className="modal-form">
          <div className="modal-body">
            {errorMessage && (
              <div className="alert-banner error">
                <AlertCircle size={18} className="shrink-0" />
                <div>
                  <strong>Registration Error:</strong>
                  <p>{errorMessage}</p>
                </div>
              </div>
            )}

            <div className="alert-banner info">
              <AlertCircle size={18} className="shrink-0" />
              <div>
                <strong>Biometric Facial Requirement:</strong>
                <p>
                  The uploaded reference photograph must contain <strong>exactly one detectable face</strong>.
                  InsightFace will extract a 512-dimensional vector for AI matching against citizen sightings.
                </p>
              </div>
            </div>

            <div className="form-grid">
              {/* Full Name */}
              <div className="form-group col-span-2">
                <label className="form-label">
                  <User size={14} /> Full Legal Name <span className="required-star">*</span>
                </label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="e.g. Aarav Sharma"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  required
                />
              </div>

              {/* Age */}
              <div className="form-group">
                <label className="form-label">Age (Years)</label>
                <input
                  type="number"
                  min="0"
                  max="150"
                  className="form-input"
                  placeholder="e.g. 24"
                  value={age}
                  onChange={(e) => setAge(e.target.value)}
                />
              </div>

              {/* Gender */}
              <div className="form-group">
                <label className="form-label">Gender</label>
                <select
                  className="form-select"
                  value={gender}
                  onChange={(e) => setGender(e.target.value)}
                >
                  <option value="">Select Gender</option>
                  <option value="Male">Male</option>
                  <option value="Female">Female</option>
                  <option value="Other">Other</option>
                  <option value="Unspecified">Unspecified</option>
                </select>
              </div>

              {/* Last Seen Date */}
              <div className="form-group col-span-2">
                <label className="form-label">
                  <Calendar size={14} /> Last Seen Date & Time
                </label>
                <input
                  type="datetime-local"
                  className="form-input"
                  value={lastSeenDate}
                  onChange={(e) => setLastSeenDate(e.target.value)}
                />
              </div>

              {/* Address-based Location Selector */}
              <div className="form-group col-span-2">
                <label className="form-label">
                  <MapPin size={14} /> Last Seen Address / Landmark
                </label>
                <AddressSearchSelector
                  onLocationConfirmed={(loc) => setConfirmedLocation(loc)}
                  onUnconfirmedQueryChange={(unconfirmed) => setHasUnconfirmedSearch(unconfirmed)}
                  initialLocation={confirmedLocation}
                />
              </div>

              {/* Description & Narrative */}
              <div className="form-group col-span-2">
                <label className="form-label">
                  <FileText size={14} /> Distinguishing Features & Incident Context
                </label>
                <textarea
                  className="form-textarea"
                  placeholder="Clothing worn, height, physical scars, incident circumstances..."
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </div>

              {/* Photo Upload Dropzone */}
              <div className="form-group col-span-2">
                <label className="form-label">
                  <ImageIcon size={14} /> Reference Photograph <span className="required-star">*</span>
                </label>

                <div
                  className={`upload-dropzone ${selectedFile ? 'has-file' : ''}`}
                  onClick={() => fileInputRef.current?.click()}
                >
                  <input
                    type="file"
                    ref={fileInputRef}
                    accept="image/jpeg,image/png,image/webp"
                    style={{ display: 'none' }}
                    onChange={handleFileChange}
                  />

                  <div className="upload-icon-box">
                    {selectedFile ? <CheckCircle2 size={24} color="#10B981" /> : <Upload size={24} />}
                  </div>

                  <p className="upload-title">
                    {selectedFile ? 'Reference Photo Selected' : 'Click or Drag & Drop Reference Photo'}
                  </p>
                  <p className="upload-subtitle">
                    JPG, JPEG, PNG, or WEBP up to 10 MB (Clear frontal lighting recommended)
                  </p>

                  {filePreview && (
                    <div className="file-preview-strip" onClick={(e) => e.stopPropagation()}>
                      <img src={filePreview} alt="Preview" className="preview-thumb" />
                      <div className="preview-details">
                        <p className="preview-filename">{selectedFile?.name}</p>
                        <p className="preview-filesize">
                          {(selectedFile?.size / (1024 * 1024)).toFixed(2)} MB • Ready for AI embedding
                        </p>
                      </div>
                      <button
                        type="button"
                        className="btn-ghost"
                        onClick={() => {
                          setSelectedFile(null);
                          setFilePreview(null);
                        }}
                      >
                        <X size={16} />
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Fixed Footer */}
          <div className="modal-footer">
            <button
              type="button"
              className="btn btn-secondary"
              onClick={onClose}
              disabled={loading}
            >
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-primary"
              disabled={loading}
            >
              {loading ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Extracting Biometrics & Indexing...
                </>
              ) : (
                'Register Case Dossier'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
