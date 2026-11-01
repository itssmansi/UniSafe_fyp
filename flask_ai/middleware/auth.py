import functools
from flask import request, jsonify, g, current_app
from database.supabase_client import get_supabase_client


def get_bearer_token():
    """Extract Bearer token from HTTP Authorization header."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header:
        return None
    parts = auth_header.split(" ", 1)
    if len(parts) == 2 and parts[0].strip().lower() == "bearer":
        token = parts[1].strip()
        return token if token else None
    return None


def verify_supabase_token(token: str):
    """
    Validate access token against Supabase Auth.
    Returns: (user, error_message)
    """
    if not token:
        return None, "Authorization token is missing"
    supabase = get_supabase_client()
    try:
        res = supabase.auth.get_user(token)
        user = getattr(res, "user", res)
        if not user or not hasattr(user, "id"):
            return None, "Invalid user in token"
        return user, None
    except Exception as e:
        return None, str(e)


def lookup_authority_profile(user_id: str):
    """
    Look up authority profile by auth_user_id in public.authorities.
    Returns: authority_dict or None
    """
    supabase = get_supabase_client()
    try:
        res = (
            supabase.table("authorities")
            .select("id, name, department, role, user_type, jurisdiction, verification_status, auth_user_id")
            .eq("auth_user_id", user_id)
            .limit(1)
            .execute()
        )
        if res.data and len(res.data) > 0:
            return res.data[0]
    except Exception as e:
        if current_app:
            current_app.logger.warning("Error querying authorities table by auth_user_id: %s", e)

    # Check if user is a citizen in citizens table
    try:
        cit_res = (
            supabase.table("citizens")
            .select("id, name, role, auth_user_id")
            .eq("auth_user_id", user_id)
            .limit(1)
            .execute()
        )
        if cit_res.data and len(cit_res.data) > 0:
            return {
                "id": cit_res.data[0].get("id"),
                "name": cit_res.data[0].get("name"),
                "user_type": "citizen",
                "role": "citizen",
                "department": None
            }
    except Exception:
        pass

    return None


def require_authority(allowed_departments=None, allowed_roles=None):
    """
    Decorator that enforces that the caller has a valid Supabase access token
    and is registered as an authority in public.authorities.
    Optionally enforces department restrictions (e.g., ['POLICE']) and
    role restrictions (e.g., ['Inspector', 'Constable']).
    """
    def decorator(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            token = get_bearer_token()
            is_testing = current_app and current_app.config.get("TESTING")
            require_auth_in_tests = current_app and current_app.config.get("REQUIRE_AUTH_IN_TESTS")

            # Legacy test suite compatibility: only bypass if testing mode is active,
            # strict auth is not specifically requested, and no auth header was provided.
            if is_testing and not require_auth_in_tests and not token:
                g.current_user = type("MockUser", (), {"id": "test-mock-user-id"})()
                g.current_authority = {
                    "id": "11111111-2222-3333-4444-555555555555",
                    "name": "Test Police Officer",
                    "department": "POLICE",
                    "role": "Inspector",
                    "user_type": "authority",
                    "jurisdiction": "Mumbai North"
                }
                return fn(*args, **kwargs)

            if not token:
                return jsonify({
                    "error": "Authentication required. Please provide a valid Bearer token.",
                    "code": "UNAUTHENTICATED"
                }), 401

            user, err = verify_supabase_token(token)
            if err or not user:
                return jsonify({
                    "error": "Invalid or expired authorization token.",
                    "code": "INVALID_TOKEN",
                    "details": err
                }), 401

            profile = lookup_authority_profile(user.id)
            if not profile or profile.get("user_type") != "authority":
                return jsonify({
                    "error": "Access forbidden: only registered authorities may perform this action.",
                    "code": "FORBIDDEN"
                }), 403

            # Department check
            if allowed_departments:
                dept = (profile.get("department") or "").strip().upper()
                allowed_upper = [d.strip().upper() for d in allowed_departments]
                if dept not in allowed_upper:
                    return jsonify({
                        "error": f"Access forbidden: restricted to {', '.join(allowed_departments)} department.",
                        "code": "FORBIDDEN"
                    }), 403

            # Role / Designation check
            if allowed_roles:
                role = (profile.get("role") or "").strip()
                if role not in allowed_roles:
                    return jsonify({
                        "error": f"Access forbidden: restricted to {', '.join(allowed_roles)} designation.",
                        "code": "FORBIDDEN"
                    }), 403

            g.current_user = user
            g.current_authority = profile
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def optional_authority(fn):
    """
    Decorator that inspects Authorization header if present. Populates g.current_user and
    g.current_authority if valid, but does not reject unauthenticated callers.
    Used for public citizen submission (POST /api/sightings) and public listings.
    """
    @functools.wraps(fn)
    def wrapper(*args, **kwargs):
        token = get_bearer_token()
        if token:
            user, err = verify_supabase_token(token)
            if user:
                g.current_user = user
                g.current_authority = lookup_authority_profile(user.id)
            else:
                g.current_user = None
                g.current_authority = None
        else:
            g.current_user = None
            g.current_authority = None
        return fn(*args, **kwargs)
    return wrapper
