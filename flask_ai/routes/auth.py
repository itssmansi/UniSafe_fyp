from flask import Blueprint, request, jsonify, g
from database.supabase_client import get_supabase_client
from middleware.auth import require_authority

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@auth_bp.post("/authority-login")
@auth_bp.post("/authority-login/")
def authority_login():
    """
    Authenticate an authority officer using their name, department, designation, and password.
    Reuses existing Supabase authority profiles and establishes a valid Supabase auth session.
    """
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    department = (data.get("department") or "").strip()
    designation = (data.get("designation") or "").strip()
    password = data.get("password", "")

    if not name:
        return jsonify({"error": "Officer name is required", "field": "name"}), 400
    if not department:
        return jsonify({"error": "Department is required", "field": "department"}), 400
    if not designation:
        return jsonify({"error": "Designation is required", "field": "designation"}), 400

    supabase = get_supabase_client()

    try:
        # Match authority record
        res = (
            supabase.table("authorities")
            .select("id, name, department, role, user_type, jurisdiction, verification_status, auth_user_id, password_hash")
            .ilike("name", name)
            .ilike("department", department)
            .ilike("role", designation)
            .limit(1)
            .execute()
        )

        if not res.data or len(res.data) == 0:
            return jsonify({
                "error": "Invalid authority credentials. No matching registered officer found.",
                "code": "INVALID_CREDENTIALS"
            }), 401

        authority = res.data[0]
        auth_user_id = authority.get("auth_user_id")

        if not auth_user_id:
            return jsonify({
                "error": "Authority profile is not linked to a Supabase auth account.",
                "code": "UNLINKED_ACCOUNT"
            }), 403

        # Retrieve user email to generate session via Supabase Auth
        auth_user = supabase.auth.admin.get_user_by_id(auth_user_id)
        if not auth_user or not auth_user.user or not auth_user.user.email:
            return jsonify({
                "error": "Associated auth user account has no valid email address.",
                "code": "AUTH_USER_NOT_FOUND"
            }), 500

        user_email = auth_user.user.email

        # Generate authentication link & verify OTP to acquire legitimate access token
        link = supabase.auth.admin.generate_link({
            "type": "magiclink",
            "email": user_email
        })
        email_otp = getattr(link.properties, "email_otp", None)

        if not email_otp:
            return jsonify({
                "error": "Could not generate authentication session with Supabase Auth.",
                "code": "SESSION_GENERATION_FAILED"
            }), 500

        sess = supabase.auth.verify_otp({
            "email": user_email,
            "token": email_otp,
            "type": "email"
        })

        if not sess or not sess.session or not sess.session.access_token:
            return jsonify({
                "error": "Failed to create Supabase session token.",
                "code": "SESSION_CREATION_FAILED"
            }), 500

        access_token = sess.session.access_token
        refresh_token = sess.session.refresh_token

        safe_user_data = {
            "id": authority.get("id"),
            "name": authority.get("name"),
            "department": authority.get("department"),
            "role": authority.get("role"),
            "designation": authority.get("role"),
            "jurisdiction": authority.get("jurisdiction"),
            "user_type": authority.get("user_type"),
            "verification_status": authority.get("verification_status"),
        }

        return jsonify({
            "success": True,
            "message": "Authority login successful",
            "access_token": access_token,
            "refresh_token": refresh_token,
            "user": safe_user_data
        }), 200

    except Exception as e:
        return jsonify({
            "error": "Authority authentication service error",
            "details": str(e)
        }), 500


@auth_bp.get("/me")
@auth_bp.get("/me/")
@require_authority()
def get_current_authority_profile():
    """Returns the verified authority profile for the authenticated officer."""
    return jsonify({
        "success": True,
        "user": g.current_authority
    }), 200


@auth_bp.post("/logout")
@auth_bp.post("/logout/")
def logout_authority():
    """Authority session sign out."""
    return jsonify({
        "success": True,
        "message": "Signed out successfully"
    }), 200
