import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  Search,
  MapPin,
  CheckCircle2,
  AlertCircle,
  Loader2,
  X,
  ExternalLink,
  RotateCcw,
  Sliders,
  Globe,
  Navigation
} from 'lucide-react';

/**
 * AddressSearchSelector
 * 
 * Provides an address and local-place location selector powered by OpenStreetMap Nominatim.
 * 
 * Capabilities:
 * - Local-place and partial address search with query normalization and smart fallbacks.
 * - Prioritizes local results while supporting global search.
 * - Rate-limited to adhere to Nominatim usage policy (maximum 1 request per second).
 * - Debounces user keystrokes and caches results to avoid duplicate requests.
 * - Supports manual coordinate and landmark input without altering backend data contracts.
 * - Confirmed location provides numeric lat/lon and interactive OpenStreetMap preview.
 * - OpenStreetMap attribution: "© OpenStreetMap contributors (ODbL)".
 */

// Common conversational prepositions and prefixes that break Nominatim tokenization
const PREPOSITION_REGEX = /^(near|opp\.?|opposite|behind|next to|in front of|beside|adjacent to|at|close to|off|facing)\s+/i;
const UNIT_REGEX = /^(flat|shop|room|office|gala|plot|bldg|building|block|house|cabin)\s*(no\.?|number)?\s*[\w\d/-]+\s*[,\s-]*/i;

/**
 * Generate fallback query variants for queries with street numbers, unit prefixes,
 * or conversational prepositions.
 */
function getQueryVariants(rawQuery) {
  const orig = rawQuery.trim().replace(/\s+/g, ' ');
  const variants = [orig];

  // 1. Strip conversational prepositions (e.g. "Near Lilavati Hospital" -> "Lilavati Hospital")
  const strippedPrep = orig.replace(PREPOSITION_REGEX, '').trim();
  if (strippedPrep && strippedPrep.toLowerCase() !== orig.toLowerCase()) {
    variants.push(strippedPrep);
  }

  // 2. Strip unit / shop / flat numbers (e.g. "Shop 4, Linking Road" -> "Linking Road")
  const baseTarget = strippedPrep || orig;
  const strippedUnit = baseTarget.replace(UNIT_REGEX, '').trim();
  if (strippedUnit && !variants.some((v) => v.toLowerCase() === strippedUnit.toLowerCase())) {
    variants.push(strippedUnit);
  }

  // 3. If comma-separated, attempt dropping the most specific first token
  if (strippedUnit.includes(',')) {
    const parts = strippedUnit.split(',').map((p) => p.trim()).filter(Boolean);
    if (parts.length >= 2) {
      const combinedTail = parts.slice(1).join(', ');
      if (combinedTail && !variants.some((v) => v.toLowerCase() === combinedTail.toLowerCase())) {
        variants.push(combinedTail);
      }
    }
  }

  return variants;
}

/**
 * Build a structured, human-readable address subtitle distinguishing similar places.
 */
function buildAddressSubtitle(candidate) {
  const addr = candidate.address;
  if (!addr) {
    return candidate.display_name;
  }

  const parts = [];

  // Road or street
  const road = addr.road || addr.pedestrian || addr.street || addr.footway || addr.path;
  if (road && !candidate.name?.toLowerCase().includes(road.toLowerCase())) {
    parts.push(road);
  }

  // Suburb, neighbourhood or locality
  const locality = addr.suburb || addr.neighbourhood || addr.residential || addr.subdistrict;
  if (locality) {
    parts.push(locality);
  }

  // City, town or district
  const city = addr.city || addr.town || addr.municipality || addr.city_district || addr.county;
  if (city) {
    parts.push(city);
  }

  // Postal code
  if (addr.postcode) {
    parts.push(`PIN: ${addr.postcode}`);
  }

  // State
  if (addr.state) {
    parts.push(addr.state);
  }

  // Country
  if (addr.country && addr.country !== 'India') {
    parts.push(addr.country);
  }

  return parts.length > 0 ? parts.join(', ') : candidate.display_name;
}

/**
 * Format category / type badge for candidate card.
 */
function formatCategoryBadge(candidate) {
  const rawType = (candidate.type || candidate.category || candidate.class || 'place').toLowerCase();
  
  const map = {
    secondary: 'Road',
    primary: 'Main Road',
    residential: 'Street',
    tertiary: 'Local Road',
    hospital: 'Hospital / Clinic',
    clinic: 'Health Clinic',
    police: 'Police Station',
    station: 'Transit Station',
    bus_stop: 'Bus Stop',
    apartments: 'Residential Building',
    commercial: 'Commercial / Complex',
    supermarket: 'Market / Grocery',
    mall: 'Shopping Mall',
    shop: 'Local Shop / Store',
    school: 'School / Institution',
    college: 'College / University',
    attraction: 'Landmark / Attraction',
    place_of_worship: 'Place of Worship',
    suburb: 'Neighbourhood / Suburb',
    administrative: 'Administrative Area',
    village: 'Locality / Village'
  };

  return map[rawType] || rawType.replace(/_/g, ' ');
}

export default function AddressSearchSelector({
  onLocationConfirmed,
  onUnconfirmedQueryChange,
  initialLocation = null
}) {
  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [candidates, setCandidates] = useState([]);
  const [searched, setSearched] = useState(false);
  const [searchError, setSearchError] = useState(null);
  const [searchNotice, setSearchNotice] = useState(null);
  const [confirmedLocation, setConfirmedLocation] = useState(initialLocation);

  // Search preferences: default focus to India for accurate local streets and landmarks
  const [focusIndia, setFocusIndia] = useState(true);

  // Manual coordinate entry mode
  const [manualMode, setManualMode] = useState(false);
  const [manualForm, setManualForm] = useState({
    displayName: '',
    lat: '',
    lon: ''
  });
  const [manualError, setManualError] = useState(null);

  // Rate-limiting & request tracking refs
  const lastRequestTimeRef = useRef(0);
  const debounceTimerRef = useRef(null);
  const abortControllerRef = useRef(null);
  const queryCacheRef = useRef(new Map());

  // Cleanup timers on unmount
  useEffect(() => {
    return () => {
      if (debounceTimerRef.current) clearTimeout(debounceTimerRef.current);
      if (abortControllerRef.current) abortControllerRef.current.abort();
    };
  }, []);

  /**
   * Execute single Nominatim fetch respecting rate limits (1 req/sec) and caching.
   */
  const fetchNominatim = useCallback(async (searchQuery, useCountryFilter) => {
    const cacheKey = `${useCountryFilter ? 'IN' : 'GLOBAL'}:${searchQuery.toLowerCase().trim()}`;
    if (queryCacheRef.current.has(cacheKey)) {
      return queryCacheRef.current.get(cacheKey);
    }

    // Rate-limiting guard: ensure at least 1 second between API calls
    const now = Date.now();
    const elapsed = now - lastRequestTimeRef.current;
    if (elapsed < 1000) {
      await new Promise((r) => setTimeout(r, 1000 - elapsed));
    }
    lastRequestTimeRef.current = Date.now();

    // Abort prior in-flight request if any
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    abortControllerRef.current = new AbortController();

    const countryParam = useCountryFilter ? '&countrycodes=in' : '';
    // Request up to 15 results with full address breakdown and POI tags
    const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&q=${encodeURIComponent(
      searchQuery.trim()
    )}&limit=15&addressdetails=1&extratags=1&namedetails=1${countryParam}`;

    const response = await fetch(url, {
      method: 'GET',
      signal: abortControllerRef.current.signal,
      headers: {
        'Accept': 'application/json',
        'Accept-Language': 'en'
      }
    });

    if (response.status === 429) {
      throw new Error('RATE_LIMITED');
    }

    if (!response.ok) {
      throw new Error(`HTTP_${response.status}`);
    }

    const data = await response.json();
    if (!Array.isArray(data)) {
      throw new Error('INVALID_FORMAT');
    }

    queryCacheRef.current.set(cacheKey, data);
    return data;
  }, []);

  /**
   * Search orchestrator: queries exact search, and gracefully tries fallbacks if 0 results.
   */
  const performSearch = useCallback(
    async (rawQuery, countryFilter = focusIndia) => {
      const cleanQuery = rawQuery.trim();
      if (!cleanQuery) return;

      setSearching(true);
      setSearchError(null);
      setSearchNotice(null);
      setSearched(true);
      setCandidates([]);

      try {
        // Step 1: Search exact query
        let results = await fetchNominatim(cleanQuery, countryFilter);

        // Step 2: Fallback query expansion if exact search returns no results
        if (results.length === 0) {
          const variants = getQueryVariants(cleanQuery);
          // Try next fallback variant
          for (let i = 1; i < variants.length; i++) {
            const variant = variants[i];
            const fallbackResults = await fetchNominatim(variant, countryFilter);
            if (fallbackResults.length > 0) {
              results = fallbackResults;
              setSearchNotice(
                `No direct match for "${cleanQuery}". Showing closest matching locations for "${variant}".`
              );
              break;
            }
          }
        }

        // Step 3: If still 0 results with India filter, try global search automatically if it could be outside IN
        if (results.length === 0 && countryFilter) {
          const globalResults = await fetchNominatim(cleanQuery, false);
          if (globalResults.length > 0) {
            results = globalResults;
            setSearchNotice(`Found international matches outside India for "${cleanQuery}".`);
          }
        }

        setCandidates(results);
      } catch (err) {
        if (err.name === 'AbortError') {
          return; // Ignore canceled requests
        }

        console.error('Nominatim search error:', err);
        if (err.message === 'RATE_LIMITED') {
          setSearchError('Search rate limit reached. Please wait a moment before searching again.');
        } else {
          setSearchError('Unable to complete address lookup. Check network connection or try again.');
        }
      } finally {
        setSearching(false);
      }
    },
    [fetchNominatim, focusIndia]
  );

  /**
   * Input change handler with keystroke debouncing.
   */
  const handleQueryChange = (val) => {
    setQuery(val);
    setSearchError(null);
    setSearchNotice(null);

    if (searched && !confirmedLocation) {
      setSearched(false);
      setCandidates([]);
    }

    if (onUnconfirmedQueryChange) {
      onUnconfirmedQueryChange(val.trim().length > 0 && !confirmedLocation);
    }

    // Clear any existing debounce timer
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }

    // Debounce search when user types 3 or more characters
    const trimmed = val.trim();
    if (trimmed.length >= 3 && !confirmedLocation) {
      debounceTimerRef.current = setTimeout(() => {
        performSearch(trimmed);
      }, 650);
    }
  };

  /**
   * Manual Search button / Enter key handler (executes immediately).
   */
  const handleImmediateSearch = (e) => {
    if (e) e.preventDefault();
    if (debounceTimerRef.current) {
      clearTimeout(debounceTimerRef.current);
    }
    performSearch(query);
  };

  /**
   * Confirm candidate from OpenStreetMap list.
   */
  const handleConfirmCandidate = (candidate) => {
    const lat = parseFloat(candidate.lat);
    const lon = parseFloat(candidate.lon);

    if (isNaN(lat) || isNaN(lon)) {
      setSearchError('Candidate location has invalid coordinates.');
      return;
    }

    const shortName = candidate.name || candidate.display_name.split(',')[0].trim();
    const confirmed = {
      displayName: candidate.display_name,
      shortName,
      lat,
      lon,
      type: candidate.type || candidate.category || candidate.class || 'place'
    };

    setConfirmedLocation(confirmed);
    setCandidates([]);
    setSearched(false);
    setQuery('');
    setSearchError(null);
    setSearchNotice(null);
    setManualMode(false);

    if (onLocationConfirmed) {
      onLocationConfirmed(confirmed);
    }
    if (onUnconfirmedQueryChange) {
      onUnconfirmedQueryChange(false);
    }
  };

  /**
   * Confirm manually entered coordinates.
   */
  const handleConfirmManualLocation = (e) => {
    if (e) e.preventDefault();
    setManualError(null);

    const name = manualForm.displayName.trim();
    const lat = parseFloat(manualForm.lat);
    const lon = parseFloat(manualForm.lon);

    if (!name) {
      setManualError('Please provide a landmark, street or address description.');
      return;
    }
    if (isNaN(lat) || lat < -90 || lat > 90) {
      setManualError('Latitude must be a valid number between -90.0 and 90.0.');
      return;
    }
    if (isNaN(lon) || lon < -180 || lon > 180) {
      setManualError('Longitude must be a valid number between -180.0 and 180.0.');
      return;
    }

    const confirmed = {
      displayName: name,
      shortName: name.split(',')[0].trim(),
      lat,
      lon,
      type: 'manual_coordinates'
    };

    setConfirmedLocation(confirmed);
    setManualMode(false);
    setCandidates([]);
    setSearched(false);
    setQuery('');

    if (onLocationConfirmed) {
      onLocationConfirmed(confirmed);
    }
    if (onUnconfirmedQueryChange) {
      onUnconfirmedQueryChange(false);
    }
  };

  /**
   * Reset confirmed location to search or edit again.
   */
  const handleClearLocation = () => {
    setConfirmedLocation(null);
    setCandidates([]);
    setSearched(false);
    setQuery('');
    setSearchError(null);
    setSearchNotice(null);
    setManualMode(false);

    if (onLocationConfirmed) {
      onLocationConfirmed(null);
    }
    if (onUnconfirmedQueryChange) {
      onUnconfirmedQueryChange(false);
    }
  };

  /**
   * Switch into manual coordinate adjustment with current confirmed coordinates prefilled.
   */
  const handleStartCoordinateAdjustment = () => {
    if (confirmedLocation) {
      setManualForm({
        displayName: confirmedLocation.displayName,
        lat: String(confirmedLocation.lat),
        lon: String(confirmedLocation.lon)
      });
      setConfirmedLocation(null);
    }
    setManualMode(true);
    setCandidates([]);
    setSearched(false);
  };

  return (
    <div className="address-selector-container">
      {/* 1. Confirmed Location Card */}
      {confirmedLocation ? (
        <div className="confirmed-location-card">
          <div className="confirmed-location-header">
            <div>
              <div className="confirmed-location-title-box">
                <CheckCircle2 size={16} />
                <span>Confirmed Last Seen Location</span>
                {confirmedLocation.type === 'manual_coordinates' && (
                  <span
                    style={{
                      fontSize: '0.68rem',
                      background: 'rgba(59, 130, 246, 0.1)',
                      color: 'var(--color-midnight)',
                      padding: '0.1rem 0.4rem',
                      borderRadius: '4px',
                      marginLeft: '0.4rem'
                    }}
                  >
                    Custom Coordinates
                  </span>
                )}
              </div>
              <p className="confirmed-address-text">{confirmedLocation.displayName}</p>
            </div>
            <div style={{ display: 'flex', gap: '0.4rem' }}>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                onClick={handleStartCoordinateAdjustment}
                title="Fine-tune latitude & longitude"
              >
                <Sliders size={13} /> Adjust GPS
              </button>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ padding: '0.35rem 0.65rem', fontSize: '0.75rem' }}
                onClick={handleClearLocation}
                title="Change or re-search address"
              >
                <RotateCcw size={13} /> Change
              </button>
            </div>
          </div>

          {/* Resolved Coordinates Strip */}
          <div className="coordinates-strip">
            <span className="coordinate-pill">
              <strong>Latitude:</strong> {confirmedLocation.lat.toFixed(5)}°{' '}
              {confirmedLocation.lat >= 0 ? 'N' : 'S'}
            </span>
            <span className="coordinate-pill">
              <strong>Longitude:</strong> {confirmedLocation.lon.toFixed(5)}°{' '}
              {confirmedLocation.lon >= 0 ? 'E' : 'W'}
            </span>
            <a
              href={`https://www.openstreetmap.org/?mlat=${confirmedLocation.lat}&mlon=${confirmedLocation.lon}#map=16/${confirmedLocation.lat}/${confirmedLocation.lon}`}
              target="_blank"
              rel="noreferrer noopener"
              className="btn btn-ghost"
              style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem', color: 'var(--color-midnight)' }}
            >
              <ExternalLink size={12} /> Open in OSM
            </a>
          </div>

          {/* Interactive OpenStreetMap preview iframe */}
          <div style={{ position: 'relative', width: '100%', height: '180px' }}>
            <iframe
              title="OpenStreetMap Location Preview"
              className="map-preview-frame"
              loading="lazy"
              src={`https://www.openstreetmap.org/export/embed.html?bbox=${(
                confirmedLocation.lon - 0.008
              ).toFixed(5)}%2C${(confirmedLocation.lat - 0.008).toFixed(5)}%2C${(
                confirmedLocation.lon + 0.008
              ).toFixed(5)}%2C${(confirmedLocation.lat + 0.008).toFixed(
                5
              )}&layer=mapnik&marker=${confirmedLocation.lat.toFixed(5)}%2C${confirmedLocation.lon.toFixed(5)}`}
            />
          </div>

          {/* Attribution Notice */}
          <div className="map-attribution">
            <span>
              Geocoding & Maps: ©{' '}
              <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noreferrer">
                OpenStreetMap contributors
              </a>{' '}
              (ODbL)
            </span>
            <span>Numeric coordinates automatically attached for Flask API</span>
          </div>
        </div>
      ) : manualMode ? (
        /* 2. Manual Coordinate & Custom Place Input Mode */
        <div className="manual-coordinates-box" style={{ padding: '0.85rem', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', background: '#F8FAFC' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.65rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 600, fontSize: '0.82rem', color: 'var(--color-dark)' }}>
              <Navigation size={15} style={{ color: 'var(--color-midnight)' }} />
              <span>Direct GPS Coordinates & Custom Landmark</span>
            </div>
            <button
              type="button"
              className="btn btn-ghost"
              style={{ fontSize: '0.75rem', padding: '0.2rem 0.5rem' }}
              onClick={() => {
                setManualMode(false);
                setManualError(null);
              }}
            >
              Back to Address Search
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <div>
              <label className="form-label" style={{ fontSize: '0.75rem' }}>
                Location / Address Description <span className="required-star">*</span>
              </label>
              <input
                type="text"
                className="form-input"
                placeholder="e.g. Near Shop 4, Linking Road, Khar West"
                value={manualForm.displayName}
                onChange={(e) => setManualForm({ ...manualForm, displayName: e.target.value })}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem' }}>
              <div>
                <label className="form-label" style={{ fontSize: '0.75rem' }}>
                  Latitude (e.g. 19.0657) <span className="required-star">*</span>
                </label>
                <input
                  type="number"
                  step="any"
                  className="form-input"
                  placeholder="19.0657"
                  value={manualForm.lat}
                  onChange={(e) => setManualForm({ ...manualForm, lat: e.target.value })}
                />
              </div>
              <div>
                <label className="form-label" style={{ fontSize: '0.75rem' }}>
                  Longitude (e.g. 72.8340) <span className="required-star">*</span>
                </label>
                <input
                  type="number"
                  step="any"
                  className="form-input"
                  placeholder="72.8340"
                  value={manualForm.lon}
                  onChange={(e) => setManualForm({ ...manualForm, lon: e.target.value })}
                />
              </div>
            </div>

            {manualError && (
              <div className="alert-banner error" style={{ padding: '0.4rem 0.6rem', fontSize: '0.75rem', marginTop: '0.2rem' }}>
                <AlertCircle size={14} className="shrink-0" />
                <span>{manualError}</span>
              </div>
            )}

            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '0.35rem' }}>
              <button
                type="button"
                className="btn btn-secondary"
                style={{ fontSize: '0.75rem', padding: '0.35rem 0.75rem' }}
                onClick={() => setManualMode(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn-primary"
                style={{ fontSize: '0.75rem', padding: '0.35rem 0.85rem' }}
                onClick={handleConfirmManualLocation}
              >
                <CheckCircle2 size={13} /> Confirm Coordinates
              </button>
            </div>
          </div>
        </div>
      ) : (
        /* 3. Address Search Mode */
        <div className="address-search-wrapper">
          <div className="address-search-box">
            <div className="address-search-input-wrapper">
              <MapPin size={15} className="search-icon" />
              <input
                type="text"
                className="address-input form-input"
                style={{ paddingLeft: '2.3rem', paddingRight: '2.2rem' }}
                placeholder="Search local street, shop, neighbourhood, hospital, landmark, or station..."
                value={query}
                onChange={(e) => handleQueryChange(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleImmediateSearch();
                  }
                }}
              />
              {query && (
                <button
                  type="button"
                  className="address-clear-btn"
                  onClick={() => handleQueryChange('')}
                  title="Clear search"
                >
                  <X size={14} />
                </button>
              )}
            </div>

            <button
              type="button"
              className="btn btn-primary"
              style={{ whiteSpace: 'nowrap' }}
              onClick={handleImmediateSearch}
              disabled={searching || !query.trim()}
            >
              {searching ? (
                <>
                  <Loader2 size={14} className="animate-spin" /> Searching...
                </>
              ) : (
                <>
                  <Search size={14} /> Search
                </>
              )}
            </button>
          </div>

          {/* Quick controls: Region focus & Direct GPS option */}
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              marginTop: '0.35rem',
              fontSize: '0.73rem',
              color: 'var(--color-text-muted)'
            }}
          >
            <label style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={focusIndia}
                onChange={(e) => {
                  setFocusIndia(e.target.checked);
                  if (query.trim()) {
                    performSearch(query.trim(), e.target.checked);
                  }
                }}
              />
              <span style={{ display: 'inline-flex', alignItems: 'center', gap: '0.2rem' }}>
                <Globe size={12} /> Focus Local / India
              </span>
            </label>

            <button
              type="button"
              className="btn-link"
              style={{
                fontSize: '0.73rem',
                color: 'var(--color-midnight)',
                background: 'transparent',
                border: 'none',
                cursor: 'pointer',
                textDecoration: 'underline'
              }}
              onClick={() => {
                setManualForm({
                  displayName: query.trim() || '',
                  lat: '',
                  lon: ''
                });
                setManualMode(true);
              }}
            >
              Enter GPS coordinates manually
            </button>
          </div>

          {/* Informative Search Notice (Fallback expansion alert) */}
          {searchNotice && (
            <div
              className="alert-banner warning"
              style={{ marginTop: '0.5rem', padding: '0.45rem 0.75rem', fontSize: '0.74rem' }}
            >
              <AlertCircle size={14} className="shrink-0" />
              <span>{searchNotice}</span>
            </div>
          )}

          {/* Error Message */}
          {searchError && (
            <div className="alert-banner error" style={{ marginTop: '0.5rem', padding: '0.45rem 0.75rem' }}>
              <AlertCircle size={15} className="shrink-0" />
              <p style={{ fontSize: '0.75rem' }}>{searchError}</p>
            </div>
          )}

          {/* No results message with actionable suggestions */}
          {searched && !searching && candidates.length === 0 && !searchError && (
            <div className="alert-banner warning" style={{ marginTop: '0.65rem' }}>
              <AlertCircle size={16} className="shrink-0" />
              <div style={{ fontSize: '0.76rem' }}>
                <strong>No Locations Found for "{query}":</strong>
                <p style={{ marginTop: '0.2rem' }}>
                  OpenStreetMap could not find an exact match. Suggestions:
                </p>
                <ul style={{ paddingLeft: '1.2rem', marginTop: '0.25rem' }}>
                  <li>Try searching just the street or area name (e.g. "Linking Road, Bandra" or "Dadar West").</li>
                  <li>Remove shop/flat numbers or room prefixes (e.g. search "Galaxy Apartments").</li>
                  {focusIndia && (
                    <li>
                      <button
                        type="button"
                        onClick={() => {
                          setFocusIndia(false);
                          performSearch(query, false);
                        }}
                        style={{
                          background: 'none',
                          border: 'none',
                          color: 'var(--color-midnight)',
                          textDecoration: 'underline',
                          cursor: 'pointer',
                          padding: 0,
                          fontSize: 'inherit'
                        }}
                      >
                        Click here to search worldwide without India restriction
                      </button>
                    </li>
                  )}
                  <li>
                    <button
                      type="button"
                      onClick={() => {
                        setManualForm({
                          displayName: query,
                          lat: '',
                          lon: ''
                        });
                        setManualMode(true);
                      }}
                      style={{
                        background: 'none',
                        border: 'none',
                        color: 'var(--color-midnight)',
                        textDecoration: 'underline',
                        cursor: 'pointer',
                        padding: 0,
                        fontSize: 'inherit'
                      }}
                    >
                      Enter exact GPS coordinates manually
                    </button>
                  </li>
                </ul>
              </div>
            </div>
          )}

          {/* Candidate Results List */}
          {candidates.length > 0 && (
            <div className="address-candidates-list" style={{ marginTop: '0.65rem', maxHeight: '280px' }}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '0.35rem 0.5rem',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  color: 'var(--color-dark)',
                  textTransform: 'uppercase',
                  letterSpacing: '0.04em'
                }}
              >
                <span>Select & Confirm Location ({candidates.length} matches):</span>
                <span style={{ fontSize: '0.68rem', fontWeight: 500, color: 'var(--color-text-muted)' }}>
                  OSM Nominatim
                </span>
              </div>

              {candidates.map((cand) => {
                const title = cand.name || cand.display_name.split(',')[0].trim();
                const subtitle = buildAddressSubtitle(cand);
                const badge = formatCategoryBadge(cand);
                const lat = parseFloat(cand.lat);
                const lon = parseFloat(cand.lon);

                return (
                  <div key={cand.place_id} className="address-candidate-item">
                    <div className="address-candidate-info">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', flexWrap: 'wrap' }}>
                        <span className="address-candidate-badge">{badge}</span>
                        {cand.address?.postcode && (
                          <span
                            style={{
                              fontSize: '0.65rem',
                              padding: '0.1rem 0.35rem',
                              background: '#E2E8F0',
                              color: '#334155',
                              borderRadius: '3px',
                              fontWeight: 600
                            }}
                          >
                            {cand.address.postcode}
                          </span>
                        )}
                      </div>
                      <p className="address-candidate-title">{title}</p>
                      <p className="address-candidate-sub">{subtitle}</p>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          color: 'var(--color-text-light)',
                          marginTop: '0.2rem',
                          display: 'block',
                          fontFamily: 'monospace'
                        }}
                      >
                        GPS: {lat.toFixed(5)}°, {lon.toFixed(5)}°
                      </span>
                    </div>

                    <button
                      type="button"
                      className="btn btn-primary"
                      style={{
                        fontSize: '0.75rem',
                        padding: '0.35rem 0.75rem',
                        whiteSpace: 'nowrap',
                        alignSelf: 'center'
                      }}
                      onClick={() => handleConfirmCandidate(cand)}
                    >
                      Select & Confirm
                    </button>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
