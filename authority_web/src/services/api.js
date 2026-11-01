/**
 * UniSafe Authority Portal - Flask AI Backend API Client
 *
 * Uses relative `/api` paths handled by the Vite dev proxy (or base URL).
 * Enforces correct headers:
 * - JSON requests use 'Content-Type': 'application/json'
 * - Multipart FormData requests omit 'Content-Type' so the browser attaches boundary
 * - Authenticated requests automatically attach 'Authorization: Bearer <token>'
 */

const API_BASE = '/api';
const TOKEN_KEY = 'unisafe_authority_token';
const OFFICER_KEY = 'unisafe_authority_user';

const FALLBACK_TOKEN_KEYS = [
  'unisafe_authority_token',
  'access_token',
  'token',
  'auth_token',
  'authority_token',
];

const FALLBACK_OFFICER_KEYS = [
  'unisafe_authority_user',
  'authority_user',
  'current_user',
  'user',
];

/**
 * Retrieve the active authority access token from existing portal session storage,
 * Supabase auth tokens, or URL query parameters.
 */
export function getStoredToken() {
  if (typeof window === 'undefined') return null;

  // 1. Check URL parameters (e.g. when navigated from the main authority portal)
  try {
    const urlParams = new URLSearchParams(window.location.search);
    const paramToken = urlParams.get('access_token') || urlParams.get('token');
    if (paramToken && paramToken.trim()) {
      const cleanToken = paramToken.trim();
      setStoredToken(cleanToken);
      // Clean query parameter from address bar without reloading
      urlParams.delete('access_token');
      urlParams.delete('token');
      const cleanQuery = urlParams.toString();
      const cleanUrl =
        window.location.pathname +
        (cleanQuery ? `?${cleanQuery}` : '') +
        window.location.hash;
      window.history.replaceState({}, document.title, cleanUrl);
      return cleanToken;
    }
  } catch {
    // Ignore URL parsing errors
  }

  // 2. Check primary and fallback keys in localStorage and sessionStorage
  for (const key of FALLBACK_TOKEN_KEYS) {
    try {
      const val = localStorage.getItem(key) || sessionStorage.getItem(key);
      if (
        val &&
        typeof val === 'string' &&
        val.trim() &&
        val !== 'null' &&
        val !== 'undefined'
      ) {
        return val.trim();
      }
    } catch {
      // Storage access may fail in restricted sandboxes
    }
  }

  // 3. Inspect Supabase client auth tokens in localStorage (sb-*-auth-token)
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (
        key &&
        ((key.startsWith('sb-') && key.endsWith('-auth-token')) ||
          key === 'supabase.auth.token')
      ) {
        const raw = localStorage.getItem(key);
        if (raw) {
          const parsed = JSON.parse(raw);
          const sbToken =
            parsed?.access_token || parsed?.currentSession?.access_token;
          if (sbToken && typeof sbToken === 'string') {
            return sbToken.trim();
          }
        }
      }
    }
  } catch {
    // Ignore JSON parse errors
  }

  return null;
}

export function setStoredToken(token) {
  try {
    if (token) {
      localStorage.setItem(TOKEN_KEY, token);
    } else {
      localStorage.removeItem(TOKEN_KEY);
      for (const key of FALLBACK_TOKEN_KEYS) {
        localStorage.removeItem(key);
        sessionStorage.removeItem(key);
      }
    }
  } catch (e) {
    console.error('Storage error', e);
  }
}

/**
 * Retrieve cached officer profile from authority portal session
 */
export function getStoredOfficer() {
  if (typeof window === 'undefined') return null;

  for (const key of FALLBACK_OFFICER_KEYS) {
    try {
      const raw = localStorage.getItem(key) || sessionStorage.getItem(key);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') {
          return parsed;
        }
      }
    } catch {
      // Ignore parse errors
    }
  }

  // Check Supabase auth token session user
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (
        key &&
        ((key.startsWith('sb-') && key.endsWith('-auth-token')) ||
          key === 'supabase.auth.token')
      ) {
        const raw = localStorage.getItem(key);
        if (raw) {
          const parsed = JSON.parse(raw);
          if (parsed?.user && typeof parsed.user === 'object') {
            return parsed.user;
          }
        }
      }
    }
  } catch {
    // Ignore parse errors
  }

  return null;
}

export function setStoredOfficer(user) {
  try {
    if (user) {
      localStorage.setItem(OFFICER_KEY, JSON.stringify(user));
    } else {
      localStorage.removeItem(OFFICER_KEY);
      for (const key of FALLBACK_OFFICER_KEYS) {
        localStorage.removeItem(key);
        sessionStorage.removeItem(key);
      }
    }
  } catch (e) {
    console.error('Storage error', e);
  }
}

/**
 * Returns the destination URL for the authority portal single login flow.
 */
export function getAuthorityLoginUrl() {
  if (typeof window !== 'undefined' && window.UNISAFE_AUTHORITY_LOGIN_URL) {
    return window.UNISAFE_AUTHORITY_LOGIN_URL;
  }
  return import.meta.env?.VITE_AUTHORITY_LOGIN_URL || '/login';
}

/**
 * Redirects the unauthenticated user directly to the authority portal's single login page.
 */
export function redirectToAuthorityLogin() {
  if (typeof window === 'undefined') return;
  const loginUrl = getAuthorityLoginUrl();
  const currentPath = window.location.pathname;

  // Prevent infinite reload loop if browser is already at the login URL
  if (currentPath !== loginUrl) {
    const returnUrl = encodeURIComponent(
      window.location.pathname + window.location.search
    );
    const separator = loginUrl.includes('?') ? '&' : '?';
    window.location.href = `${loginUrl}${separator}redirect=${returnUrl}`;
  }
}

export function clearAuthoritySession() {
  setStoredToken(null);
  setStoredOfficer(null);
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('unisafe:auth_changed', { detail: null }));
  }
}

/**
 * Authenticated fetch helper: automatically injects Authorization header when token exists.
 */
function authFetch(url, options = {}) {
  const token = getStoredToken();
  const headers = new Headers(options.headers || {});
  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`);
  }
  return fetch(url, { ...options, headers });
}

/**
 * Helper to handle fetch responses and parse JSON / errors
 */
async function handleResponse(response) {
  const contentType = response.headers.get('content-type') || '';
  let data = null;

  if (contentType.includes('application/json')) {
    try {
      data = await response.json();
    } catch {
      data = null;
    }
  } else {
    data = await response.text();
  }

  if (!response.ok) {
    if (response.status === 401) {
      clearAuthoritySession();
      redirectToAuthorityLogin();
    }

    let errorMessage = 'An error occurred during request';
    if (data && typeof data === 'object' && data.error) {
      errorMessage = data.error;
      if (data.detected_faces !== undefined) {
        errorMessage += ` (Detected faces: ${data.detected_faces})`;
      }
    } else if (typeof data === 'string' && data.trim()) {
      errorMessage = data;
    }
    const error = new Error(errorMessage);
    error.status = response.status;
    error.data = data;
    throw error;
  }

  return data;
}

// ============================================================
// AUTHORITY AUTHENTICATION APIS
// ============================================================

/**
 * Sign in an authority officer using department credentials
 */
export async function loginAuthority(credentials) {
  const response = await fetch(`${API_BASE}/auth/authority-login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(credentials),
  });
  const data = await handleResponse(response);
  if (data?.access_token) {
    setStoredToken(data.access_token);
    setStoredOfficer(data.user);
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('unisafe:auth_changed', { detail: data.user }));
    }
  }
  return data;
}

/**
 * Fetch authenticated authority profile
 */
export async function getCurrentOfficer() {
  const token = getStoredToken();
  if (!token) return null;
  try {
    const response = await authFetch(`${API_BASE}/auth/me`, { method: 'GET' });
    const data = await handleResponse(response);
    if (data?.user) {
      setStoredOfficer(data.user);
    }
    return data?.user;
  } catch {
    return null;
  }
}

/**
 * Sign out authority officer
 */
export async function logoutAuthority() {
  try {
    await authFetch(`${API_BASE}/auth/logout`, { method: 'POST' });
  } catch {
    // Ignore backend logout error
  }
  clearAuthoritySession();
}

// ============================================================
// MISSING PERSONS DOSSIERS APIS
// ============================================================

/**
 * 1. Fetch missing persons list
 * GET /api/missing-persons?status=Missing&limit=50
 */
export async function getMissingPersons(status = 'all', limit = null) {
  const params = new URLSearchParams();
  if (status && status !== 'all') {
    params.set('status', status);
  }
  if (limit && Number(limit) > 0) {
    params.set('limit', String(limit));
  }

  const queryString = params.toString();
  const url = `${API_BASE}/missing-persons${queryString ? `?${queryString}` : ''}`;
  const response = await authFetch(url, { method: 'GET' });
  return handleResponse(response);
}

/**
 * 2. Fetch single missing person case details (with photos and signed URLs)
 * GET /api/missing-persons/<person_id>
 */
export async function getMissingPersonDetail(personId) {
  if (!personId) throw new Error('personId is required');
  const response = await authFetch(`${API_BASE}/missing-persons/${personId}`, {
    method: 'GET',
  });
  return handleResponse(response);
}

/**
 * 3. Register a new missing person report
 * POST /api/missing-persons
 * Payload: FormData (full_name, age, gender, last_seen_date, latitude, longitude, description, missing_person_image)
 * Note: Never set Content-Type header manually for FormData.
 */
export async function createMissingPerson(formData) {
  const response = await authFetch(`${API_BASE}/missing-persons`, {
    method: 'POST',
    body: formData,
  });
  return handleResponse(response);
}

/**
 * 4. Update editable fields of a missing person case
 * PATCH /api/missing-persons/<person_id>
 * Payload: JSON object containing allowed fields (full_name, age, gender, last_seen_date, latitude, longitude, description)
 * Note: Case status is read-only on backend PATCH.
 */
export async function updateMissingPerson(personId, updates) {
  if (!personId) throw new Error('personId is required');
  const response = await authFetch(`${API_BASE}/missing-persons/${personId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(updates),
  });
  return handleResponse(response);
}

/**
 * 4b. Update official case status of a missing person
 * PATCH /api/missing-persons/<person_id>/status
 * Payload: JSON { status: 'Missing'|'Found'|'Closed', verified_confirmation?: boolean, remarks?: string }
 */
export async function updateCaseStatus(personId, status, verifiedConfirmation = false, remarks = '') {
  if (!personId) throw new Error('personId is required');
  if (!status) throw new Error('status is required');

  const response = await authFetch(`${API_BASE}/missing-persons/${personId}/status`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      status,
      verified_confirmation: verifiedConfirmation,
      remarks,
    }),
  });
  return handleResponse(response);
}

/**
 * 5. Add a new reference photo to an existing case
 * POST /api/missing-persons/<person_id>/photos
 * Payload: FormData containing `missing_person_image`
 */
export async function addCasePhoto(personId, formData) {
  if (!personId) throw new Error('personId is required');
  const response = await authFetch(`${API_BASE}/missing-persons/${personId}/photos`, {
    method: 'POST',
    body: formData,
  });
  return handleResponse(response);
}

/**
 * 6. Delete a reference photo from a case
 * DELETE /api/missing-persons/<person_id>/photos
 * Payload: JSON { "embedding_id": "<uuid>" }
 * Backend enforces safeguard: cannot delete the sole remaining photo (409 Conflict)
 */
export async function deleteCasePhoto(personId, embeddingId) {
  if (!personId) throw new Error('personId is required');
  if (!embeddingId) throw new Error('embeddingId is required');
  const response = await authFetch(`${API_BASE}/missing-persons/${personId}/photos`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ embedding_id: embeddingId }),
  });
  return handleResponse(response);
}

// ============================================================
// CITIZEN SIGHTINGS QUEUE APIS
// ============================================================

/**
 * 7. Fetch citizen sightings list
 * GET /api/sightings?is_verified=false&limit=50
 */
export async function getSightings(isVerified = 'all', limit = null) {
  const params = new URLSearchParams();
  if (isVerified && isVerified !== 'all') {
    params.set('is_verified', isVerified);
  }
  if (limit && Number(limit) > 0) {
    params.set('limit', String(limit));
  }

  const queryString = params.toString();
  const url = `${API_BASE}/sightings${queryString ? `?${queryString}` : ''}`;
  const response = await authFetch(url, { method: 'GET' });
  return handleResponse(response);
}

/**
 * 8. Fetch single sighting details (including signed image URL and AI matches)
 * GET /api/sightings/<sighting_id>
 */
export async function getSightingDetail(sightingId) {
  if (!sightingId) throw new Error('sightingId is required');
  const response = await authFetch(`${API_BASE}/sightings/${sightingId}`, {
    method: 'GET',
  });
  return handleResponse(response);
}

/**
 * 9. Rerun face matching for an existing sighting against registered missing persons
 * POST /api/sightings/<sighting_id>/match
 */
export async function findSightingMatches(sightingId) {
  if (!sightingId) throw new Error('sightingId is required');
  const response = await authFetch(`${API_BASE}/sightings/${sightingId}/match`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({}),
  });
  return handleResponse(response);
}

/**
 * 10. Update verification status of a citizen sighting
 * PATCH /api/sightings/<sighting_id>/verify
 * Payload: { action: 'verify' | 'reject', remarks?: string }
 */
export async function updateSightingVerification(sightingId, action, remarks = '') {
  if (!sightingId) throw new Error('sightingId is required');
  const response = await authFetch(`${API_BASE}/sightings/${sightingId}/verify`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ action, remarks }),
  });
  return handleResponse(response);
}
