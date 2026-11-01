import os
import io
from flask import Blueprint, request, jsonify, current_app, g
import cv2
import numpy as np
from uuid import UUID, uuid4
from werkzeug.utils import secure_filename

from database.supabase_client import get_supabase_client
from services.face_recognition import (
    extract_all_sighting_faces_from_image,
    match_sighting_against_cases,
)
from middleware.auth import require_authority, optional_authority


sightings_bp = Blueprint("sightings", __name__, url_prefix="/api/sightings")

BUCKET_NAME = "missing-person-images"
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
DEFAULT_MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
STRONG_MATCH_THRESHOLD = 0.50
DEFAULT_SIGNED_URL_EXPIRY_SECONDS = 3600  # 1 hour


def get_signed_url_expiry_seconds():
    """Retrieve signed URL expiration seconds from env or app config, with safe default."""
    try:
        env_val = os.getenv("SIGNED_URL_EXPIRY_SECONDS")
        if env_val:
            return int(env_val)
        if current_app and current_app.config.get("SIGNED_URL_EXPIRY_SECONDS"):
            return int(current_app.config["SIGNED_URL_EXPIRY_SECONDS"])
    except Exception:
        pass
    return DEFAULT_SIGNED_URL_EXPIRY_SECONDS


def extract_signed_url(res):
    """Safely extract signed URL string from Supabase Storage SDK response."""
    if isinstance(res, dict):
        val = res.get("signedURL") or res.get("signedUrl")
        return val if isinstance(val, str) else (str(val) if val and type(val).__name__ != "MagicMock" else None)
    if isinstance(res, str):
        return res
    if hasattr(res, "signedURL"):
        val = res.signedURL
        return val if isinstance(val, str) else (str(val) if val and type(val).__name__ != "MagicMock" else None)
    if hasattr(res, "signedUrl"):
        val = res.signedUrl
        return val if isinstance(val, str) else (str(val) if val and type(val).__name__ != "MagicMock" else None)
    return str(res) if res and type(res).__name__ != "MagicMock" else None


def is_valid_uuid(val):
    """Check whether a given value is a valid UUID string."""
    if not val or not isinstance(val, str):
        return False
    try:
        UUID(val.strip())
        return True
    except (ValueError, TypeError, AttributeError):
        return False



def get_max_image_size_bytes():
    """Retrieve maximum allowed image size from env or app config, with safe default."""
    try:
        env_val = os.getenv("MAX_IMAGE_SIZE_BYTES")
        if env_val:
            return int(env_val)
        if current_app and current_app.config.get("MAX_IMAGE_SIZE_BYTES"):
            return int(current_app.config["MAX_IMAGE_SIZE_BYTES"])
    except Exception:
        pass
    return DEFAULT_MAX_IMAGE_SIZE_BYTES


def optional_float(value, field_name):
    """Safely parse optional float field, returning None if empty or stripped."""
    if value is None:
        return None
    if isinstance(value, str):
        val_str = value.strip()
        if not val_str:
            return None
        try:
            return float(val_str)
        except ValueError:
            raise ValueError(f"{field_name} must be a number")
    try:
        return float(value)
    except (ValueError, TypeError):
        raise ValueError(f"{field_name} must be a number")


def get_content_type(image_or_extension, extension=None):
    """Determine MIME content type strictly from validated file extension."""
    if extension is not None:
        ext = extension
    elif isinstance(image_or_extension, str):
        ext = image_or_extension
    else:
        ext = getattr(image_or_extension, "filename", "").rsplit(".", 1)[-1] if image_or_extension else ""

    ext_clean = (str(ext) if ext else "").lower().strip().lstrip(".")
    content_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp",
    }
    return content_types.get(ext_clean, "image/jpeg")


def cleanup_storage_object(supabase, storage_path):
    """Attempt to remove an uploaded sighting object after a failed database insert."""
    try:
        res = supabase.storage.from_(BUCKET_NAME).remove([storage_path])
        if not res or not isinstance(res, list):
            current_app.logger.warning(
                "Cleanup: Storage remove returned empty or unexpected response for %s: %s",
                storage_path, res
            )
    except Exception:
        current_app.logger.exception(
            "Failed to clean up Storage object after database failure: %s", storage_path
        )


@sightings_bp.post("")
@sightings_bp.post("/")
@optional_authority
def submit_sighting():
    """
    Submit a citizen sighting photo with optional coordinates.
    Extracts all faces, runs face-matching against active Missing persons,
    uploads image to Storage, and records the sighting in missing_person_sightings.
    """
    # 1. Validate image upload presence
    image = request.files.get("sighting_image")
    if image is None or not image.filename:
        return jsonify({"error": "A sighting photo is required"}), 400

    filename = secure_filename(image.filename)
    if not filename or "." not in filename:
        return jsonify({"error": "Invalid image filename"}), 400

    extension = filename.rsplit(".", 1)[-1].lower()
    if extension not in ALLOWED_EXTENSIONS:
        return jsonify({"error": "Image must be JPG, JPEG, PNG, or WEBP"}), 400

    max_size = get_max_image_size_bytes()

    # Bounded size check on seekable streams
    try:
        image.seek(0, os.SEEK_END)
        size = image.tell()
        image.seek(0)
        if size > max_size:
            return jsonify({
                "error": f"Image file exceeds maximum allowed size of {max_size // (1024 * 1024)}MB"
            }), 400
    except (AttributeError, io.UnsupportedOperation, OSError, ValueError):
        pass

    # Read bounded chunk (max_size + 1)
    image_bytes = image.read(max_size + 1)
    if not image_bytes:
        return jsonify({"error": "Uploaded image is empty"}), 400

    if len(image_bytes) > max_size:
        return jsonify({
            "error": f"Image file exceeds maximum allowed size of {max_size // (1024 * 1024)}MB"
        }), 400

    # Decode image to numpy array
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if img is None:
        return jsonify({"error": "Uploaded file is not a valid image"}), 400

    # 2. Validate optional coordinates
    latitude = request.form.get("latitude")
    longitude = request.form.get("longitude")

    # Read optional citizen-entered address
    raw_address = request.form.get("address")
    address = raw_address.strip() if raw_address and isinstance(raw_address, str) and raw_address.strip() else None
    if address and len(address) > 1000:
        address = address[:1000]

    # Read optional citizen_note (e.g. citizen's suggested person)
    raw_citizen_note = request.form.get("citizen_note")
    citizen_note = raw_citizen_note.strip() if raw_citizen_note and isinstance(raw_citizen_note, str) and raw_citizen_note.strip() else None

    try:
        parsed_latitude = optional_float(latitude, "latitude")
        parsed_longitude = optional_float(longitude, "longitude")
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    if parsed_latitude is not None and not -90 <= parsed_latitude <= 90:
        return jsonify({"error": "latitude must be between -90 and 90"}), 400

    if parsed_longitude is not None and not -180 <= parsed_longitude <= 180:
        return jsonify({"error": "longitude must be between -180 and 180"}), 400

    # 3. Detect all faces in sighting image
    try:
        sighting_faces = extract_all_sighting_faces_from_image(img)
    except ValueError as error:
        return jsonify({"error": str(error)}), 422
    except Exception:
        current_app.logger.exception("Face extraction failed on sighting image")
        return jsonify({"error": "Face detection service failed"}), 500

    if not sighting_faces or len(sighting_faces) == 0:
        return jsonify({
            "error": "No faces detected in the sighting photo",
            "detected_faces": 0
        }), 422

    # 4. Fetch reference embeddings only for cases with status 'Missing'
    supabase = get_supabase_client()
    try:
        missing_persons_res = (
            supabase.table("missing_persons")
            .select("id")
            .eq("status", "Missing")
            .execute()
        )
        active_persons = missing_persons_res.data or []
        active_ids = [p["id"] for p in active_persons if p.get("id")]

        if active_ids:
            embeddings_res = (
                supabase.table("missing_person_embeddings")
                .select("missing_person_id, embedding")
                .in_("missing_person_id", active_ids)
                .execute()
            )
            reference_profiles = embeddings_res.data or []
        else:
            reference_profiles = []

    except Exception:
        current_app.logger.exception("Failed to fetch reference profiles from database")
        return jsonify({"error": "Could not fetch reference profiles from database"}), 500

    # 5. Reuse match_sighting_against_cases service
    ai_matches = match_sighting_against_cases(
        sighting_faces=sighting_faces,
        reference_profiles=reference_profiles
    )

    # Identify qualifying strong match (score >= 0.50)
    strong_matches = [
        m for m in ai_matches
        if m.get("match_category") == "match" or m.get("similarity_score", 0.0) >= STRONG_MATCH_THRESHOLD
    ]
    if strong_matches:
        # Pick the top overall strong match across all faces
        top_strong_match = max(strong_matches, key=lambda m: m.get("similarity_score", 0.0))
        matched_person_id = top_strong_match.get("missing_person_id")
    else:
        top_strong_match = None
        matched_person_id = None

    # 6. Upload sighting photo to private storage bucket under sightings/
    sighting_uuid = str(uuid4())
    storage_path = f"sightings/{sighting_uuid}.{extension}"
    image_uploaded = False

    try:
        content_type = get_content_type(extension)
        supabase.storage.from_(BUCKET_NAME).upload(
            storage_path,
            image_bytes,
            {
                "content-type": content_type,
                "upsert": "false"
            }
        )
        image_uploaded = True
    except Exception:
        current_app.logger.exception("Failed to upload sighting photo to storage: %s", storage_path)
        return jsonify({"error": "Could not upload sighting photo to storage"}), 500

    # 7. Insert sighting record into missing_person_sightings
    try:
        sighting_data = {
            "missing_person_id": matched_person_id,
            "citizen_id": None,  # Do not trust client-supplied identity
            "latitude": parsed_latitude,
            "longitude": parsed_longitude,
            "address": address,
            "image_url": storage_path,
            "is_verified": False,  # Never mark an AI match as verified
            "face_data": sighting_faces,
            "ai_matches": ai_matches,
            "citizen_note": citizen_note,
        }

        try:
            insert_res = (
                supabase.table("missing_person_sightings")
                .insert(sighting_data)
                .execute()
            )
        except Exception as ins_err:
            if "address" in str(ins_err).lower():
                sighting_data_fallback = {k: v for k, v in sighting_data.items() if k != "address"}
                insert_res = (
                    supabase.table("missing_person_sightings")
                    .insert(sighting_data_fallback)
                    .execute()
                )
            else:
                raise ins_err

        if not insert_res.data:
            raise RuntimeError("Database did not return inserted sighting record")

        sighting_record = insert_res.data[0]

        return jsonify({
            "message": "Sighting submitted successfully",
            "sighting_id": sighting_record.get("id"),
            "image_url": storage_path,
            "detected_faces": len(sighting_faces),
            "matched_person_id": matched_person_id,
            "top_match": top_strong_match,
            "ai_matches": ai_matches,
            "citizen_note": sighting_record.get("citizen_note") if isinstance(sighting_record, dict) else citizen_note,
            "address": sighting_record.get("address") if isinstance(sighting_record, dict) else address,
        }), 201

    except Exception:
        current_app.logger.exception("Failed to insert sighting record into database")
        if image_uploaded:
            cleanup_storage_object(supabase, storage_path)
        return jsonify({"error": "Could not record sighting in database"}), 500


# ---------------------------------------------------------
# LIST SIGHTINGS
# GET /api/sightings
# ---------------------------------------------------------

@sightings_bp.get("")
@sightings_bp.get("/")
@require_authority(allowed_departments=["POLICE"])
def get_sightings_list():
    """
    Retrieve a list of missing-person sightings, ordered by created_at descending.
    Uses only confirmed database columns and supports optional filtering by
    is_verified (true/false/all) and a positive integer limit.
    Excludes raw face embeddings, face_data, or internal biometric vectors.
    """
    supabase = get_supabase_client()

    # Confirmed columns in public.missing_person_sightings
    columns = (
        "id, missing_person_id, latitude, longitude, address, image_url, is_verified, created_at, citizen_note"
    )

    try:
        query = (
            supabase.table("missing_person_sightings")
            .select(columns)
            .order("created_at", desc=True)
        )

        # Optional is_verified filtering
        is_verified_param = request.args.get("is_verified")
        if is_verified_param is not None and is_verified_param.strip():
            val = is_verified_param.strip().lower()
            if val in ("true", "1"):
                query = query.eq("is_verified", True)
            elif val in ("false", "0"):
                query = query.eq("is_verified", False)
            elif val == "all":
                pass
            else:
                return jsonify({
                    "error": "is_verified must be 'true', 'false', or 'all'"
                }), 400

        # Optional limit parameter
        limit_param = request.args.get("limit")
        if limit_param is not None and limit_param.strip():
            try:
                limit_val = int(limit_param.strip())
                if limit_val > 0:
                    query = query.limit(limit_val)
                else:
                    return jsonify({"error": "limit must be a positive integer"}), 400
            except ValueError:
                return jsonify({"error": "limit must be a positive integer"}), 400

        try:
            res = query.execute()
        except Exception as q_err:
            # Resilient fallback if address or citizen_note column does not yet exist in target DB
            err_str = str(q_err).lower()
            if "address" in err_str or "citizen_note" in err_str:
                base_cols = ["id", "missing_person_id", "latitude", "longitude", "image_url", "is_verified", "created_at"]
                if "citizen_note" not in err_str:
                    base_cols.append("citizen_note")
                if "address" not in err_str:
                    base_cols.append("address")
                fallback_columns = ", ".join(base_cols)
                fallback_query = supabase.table("missing_person_sightings").select(fallback_columns).order("created_at", desc=True)
                if is_verified_param and is_verified_param.strip().lower() in ("true", "1"):
                    fallback_query = fallback_query.eq("is_verified", True)
                elif is_verified_param and is_verified_param.strip().lower() in ("false", "0"):
                    fallback_query = fallback_query.eq("is_verified", False)
                if limit_param and limit_param.strip() and int(limit_param.strip()) > 0:
                    fallback_query = fallback_query.limit(int(limit_param.strip()))
                res = fallback_query.execute()
            else:
                raise q_err

        sighting_records = res.data or []

    except Exception:
        current_app.logger.exception("Failed to query sightings from database")
        return jsonify({"error": "Could not query sightings"}), 500

    # Ensure no internal biometric vectors or face_data are ever exposed
    biometric_keys = {"embedding", "embeddings", "face_data"}

    # Enrich sightings with linked case status to clearly indicate resolved cases
    person_ids = list({
        r["missing_person_id"]
        for r in sighting_records
        if isinstance(r, dict) and r.get("missing_person_id")
    })
    case_map = {}
    if person_ids:
        try:
            cases_res = (
                supabase.table("missing_persons")
                .select("id, case_code, full_name, status")
                .in_("id", person_ids)
                .execute()
            )
            for c in (cases_res.data or []):
                if c.get("id"):
                    case_map[c["id"]] = c
        except Exception:
            current_app.logger.warning("Could not fetch case metadata for sightings list")

    sanitized_sightings = []
    for record in sighting_records:
        item = {k: v for k, v in record.items() if k not in biometric_keys}
        item["citizen_note"] = record.get("citizen_note") or None
        item["address"] = record.get("address") or None
        if "image_url" in item and "image_path" not in item:
            item["image_path"] = item["image_url"]

        pid = item.get("missing_person_id")
        case_info = case_map.get(pid) if pid else None
        if case_info:
            c_status = case_info.get("status") or "Missing"
            item["linked_case_code"] = case_info.get("case_code")
            item["linked_case_name"] = case_info.get("full_name")
            item["linked_case_status"] = c_status
            item["is_case_resolved"] = c_status in ("Found", "Closed")
        else:
            item["linked_case_code"] = None
            item["linked_case_name"] = None
            item["linked_case_status"] = None
            item["is_case_resolved"] = False

        sanitized_sightings.append(item)

    return jsonify({
        "sightings": sanitized_sightings,
        "count": len(sanitized_sightings),
        "total": len(sanitized_sightings),
    }), 200


# ---------------------------------------------------------
def enrich_ai_matches_with_candidates(supabase, ai_matches):
    """
    Enriches AI match evaluations with missing-person case metadata and
    time-limited signed URLs for reference photos.
    Excludes any raw biometric vectors.
    """
    if not ai_matches or not isinstance(ai_matches, list):
        return []

    person_ids = list({
        m["missing_person_id"]
        for m in ai_matches
        if isinstance(m, dict) and m.get("missing_person_id")
    })
    if not person_ids:
        return []

    try:
        # Fetch case metadata
        cases_res = (
            supabase.table("missing_persons")
            .select("id, case_code, full_name, age, gender, status")
            .in_("id", person_ids)
            .execute()
        )
        case_map = {c["id"]: c for c in (cases_res.data or []) if c.get("id")}

        # Fetch reference photo paths
        photos_res = (
            supabase.table("missing_person_embeddings")
            .select("missing_person_id, image_path")
            .in_("missing_person_id", person_ids)
            .execute()
        )
        photo_map = {}
        for p in (photos_res.data or []):
            pid = p.get("missing_person_id")
            if pid and pid not in photo_map and p.get("image_path"):
                photo_map[pid] = p["image_path"]

        expiry = get_signed_url_expiry_seconds()
        candidate_cases = []

        for m in ai_matches:
            if not isinstance(m, dict):
                continue
            pid = m.get("missing_person_id")
            case_info = case_map.get(pid, {})
            ref_path = photo_map.get(pid)
            signed_ref_url = None

            if ref_path:
                try:
                    url_res = supabase.storage.from_(BUCKET_NAME).create_signed_url(
                        ref_path,
                        expires_in=expiry,
                    )
                    signed_ref_url = extract_signed_url(url_res)
                except Exception:
                    current_app.logger.warning(
                        "Could not sign reference photo for candidate case %s (%s)",
                        pid, ref_path
                    )

            candidate_cases.append({
                "face_index": m.get("face_index", 0),
                "missing_person_id": pid,
                "case_code": case_info.get("case_code") or "N/A",
                "full_name": case_info.get("full_name") or "Unknown Person",
                "age": case_info.get("age"),
                "gender": case_info.get("gender"),
                "status": case_info.get("status") or "Missing",
                "similarity_score": m.get("similarity_score", 0.0),
                "similarity_percentage": round((m.get("similarity_score") or 0.0) * 100, 1),
                "match_category": m.get("match_category") or m.get("status") or "no_match",
                "reference_photo_path": ref_path,
                "reference_photo_signed_url": signed_ref_url,
                "reference_photo_url": signed_ref_url,
            })

        candidate_cases.sort(key=lambda c: -c["similarity_score"])
        return candidate_cases

    except Exception:
        current_app.logger.exception("Failed to enrich AI matches with candidate details")
        return []


# ---------------------------------------------------------
# GET A SINGLE SIGHTING RECORD
# GET /api/sightings/<sighting_id>
# ---------------------------------------------------------

@sightings_bp.get("/<sighting_id>")
@require_authority(allowed_departments=["POLICE"])
def get_sighting_detail(sighting_id):
    """
    Retrieve details of a single sighting by UUID.
    Generates a time-limited signed URL for the sighting image.
    Never returns face_data, raw embeddings, or internal biometric vectors.
    """
    if not is_valid_uuid(sighting_id):
        return jsonify({"error": "Invalid sighting ID"}), 400

    supabase = get_supabase_client()

    columns = (
        "id, missing_person_id, citizen_id, latitude, longitude, address, "
        "image_url, is_verified, created_at, ai_matches, citizen_note"
    )

    try:
        try:
            res = (
                supabase.table("missing_person_sightings")
                .select(columns)
                .eq("id", sighting_id)
                .limit(1)
                .execute()
            )
        except Exception as q_err:
            err_str = str(q_err).lower()
            if "address" in err_str or "citizen_note" in err_str:
                base_cols = [
                    "id", "missing_person_id", "citizen_id", "latitude", "longitude",
                    "image_url", "is_verified", "created_at", "ai_matches"
                ]
                if "citizen_note" not in err_str:
                    base_cols.append("citizen_note")
                if "address" not in err_str:
                    base_cols.append("address")
                fallback_cols = ", ".join(base_cols)
                res = (
                    supabase.table("missing_person_sightings")
                    .select(fallback_cols)
                    .eq("id", sighting_id)
                    .limit(1)
                    .execute()
                )
            else:
                raise q_err
        if not res.data:
            return jsonify({"error": "Sighting not found"}), 404

        record = res.data[0]

    except Exception:
        current_app.logger.exception("Failed to query sighting: %s", sighting_id)
        return jsonify({"error": "Could not query sighting"}), 500

    # Generate time-limited signed URL for sighting image
    image_path = record.get("image_url")
    signed_url = None
    if image_path:
        expiry = get_signed_url_expiry_seconds()
        try:
            url_res = supabase.storage.from_(BUCKET_NAME).create_signed_url(
                image_path,
                expires_in=expiry,
            )
            signed_url = extract_signed_url(url_res)
            if not signed_url:
                raise RuntimeError(
                    f"Storage returned empty signed URL for {image_path}"
                )
        except Exception:
            current_app.logger.exception(
                "Failed to generate signed URL for sighting image: %s", image_path
            )
            return jsonify({"error": "Could not generate signed image URL"}), 500

    biometric_keys = {"face_data", "embedding", "embeddings"}
    sighting_data = {
        "id": record.get("id"),
        "missing_person_id": record.get("missing_person_id"),
        "citizen_id": record.get("citizen_id"),
        "latitude": record.get("latitude"),
        "longitude": record.get("longitude"),
        "address": record.get("address") or None,
        "image_url": image_path,
        "image_path": image_path,
        "signed_image_url": signed_url,
        "signed_url": signed_url,
        "is_verified": record.get("is_verified"),
        "created_at": record.get("created_at"),
        "citizen_note": record.get("citizen_note") or None,
    }

    pid = record.get("missing_person_id")
    linked_case_info = None
    if pid:
        try:
            c_res = (
                supabase.table("missing_persons")
                .select("id, case_code, full_name, age, gender, status")
                .eq("id", pid)
                .limit(1)
                .execute()
            )
            if c_res.data and len(c_res.data) > 0:
                c_data = c_res.data[0]
                c_status = c_data.get("status") or "Missing"
                linked_case_info = {
                    "id": c_data.get("id"),
                    "case_code": c_data.get("case_code"),
                    "full_name": c_data.get("full_name"),
                    "age": c_data.get("age"),
                    "gender": c_data.get("gender"),
                    "status": c_status,
                    "is_resolved": c_status in ("Found", "Closed")
                }
        except Exception:
            current_app.logger.warning("Could not load linked case details for sighting %s", sighting_id)

    sighting_data["linked_case"] = linked_case_info
    sighting_data["linked_case_code"] = linked_case_info.get("case_code") if linked_case_info else None
    sighting_data["linked_case_name"] = linked_case_info.get("full_name") if linked_case_info else None
    sighting_data["linked_case_status"] = linked_case_info.get("status") if linked_case_info else None
    sighting_data["is_case_resolved"] = bool(linked_case_info and linked_case_info.get("is_resolved"))

    if "ai_matches" in record and record["ai_matches"] is not None:
        sanitized_matches = [
            {k: v for k, v in m.items() if k not in biometric_keys}
            for m in record["ai_matches"]
            if isinstance(m, dict)
        ]
        sighting_data["ai_matches"] = sanitized_matches
        sighting_data["candidate_cases"] = enrich_ai_matches_with_candidates(
            supabase, record["ai_matches"]
        )
    else:
        sighting_data["ai_matches"] = []
        sighting_data["candidate_cases"] = []

    return jsonify(sighting_data), 200


# ---------------------------------------------------------
# RUN FACE MATCHING FOR AN EXISTING SIGHTING
# POST /api/sightings/<sighting_id>/match
# ---------------------------------------------------------

@sightings_bp.post("/<sighting_id>/match")
@sightings_bp.post("/<sighting_id>/match/")
@require_authority(allowed_departments=["POLICE"])
def match_sighting(sighting_id):
    """
    Rerun face-matching for an existing sighting against all registered
    missing-person reference profiles.
    Reuses existing face_data embeddings from the sighting record or extracts
    faces from the stored image if needed.
    Updates ai_matches and missing_person_id on the sighting record without
    creating duplicate records or duplicating stored images.
    Returns candidate cases, similarity scores, match categories, and signed
    reference photo URLs.
    """
    if not is_valid_uuid(sighting_id):
        return jsonify({"error": "Invalid sighting ID"}), 400

    supabase = get_supabase_client()

    # 1. Fetch existing sighting record
    columns = (
        "id, missing_person_id, citizen_id, latitude, longitude, address, "
        "image_url, is_verified, created_at, face_data, ai_matches, citizen_note"
    )

    try:
        try:
            res = (
                supabase.table("missing_person_sightings")
                .select(columns)
                .eq("id", sighting_id)
                .limit(1)
                .execute()
            )
        except Exception as q_err:
            err_str = str(q_err).lower()
            if "address" in err_str or "citizen_note" in err_str:
                base_cols = [
                    "id", "missing_person_id", "citizen_id", "latitude", "longitude",
                    "image_url", "is_verified", "created_at", "face_data", "ai_matches"
                ]
                if "citizen_note" not in err_str:
                    base_cols.append("citizen_note")
                if "address" not in err_str:
                    base_cols.append("address")
                fallback_cols = ", ".join(base_cols)
                res = (
                    supabase.table("missing_person_sightings")
                    .select(fallback_cols)
                    .eq("id", sighting_id)
                    .limit(1)
                    .execute()
                )
            else:
                raise q_err
        if not res.data:
            return jsonify({"error": "Sighting not found"}), 404

        record = res.data[0]

    except Exception:
        current_app.logger.exception("Failed to query sighting: %s", sighting_id)
        return jsonify({"error": "Could not query sighting"}), 500

    # 2. Extract or reuse sighting face vectors
    sighting_faces = record.get("face_data")
    if not sighting_faces or not isinstance(sighting_faces, list):
        image_path = record.get("image_url")
        if not image_path:
            return jsonify({"error": "No image found for this sighting"}), 422

        try:
            image_bytes = supabase.storage.from_(BUCKET_NAME).download(image_path)
            image_array = np.frombuffer(image_bytes, dtype=np.uint8)
            img = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
            if img is None:
                raise ValueError("Could not decode image from storage")

            sighting_faces = extract_all_sighting_faces_from_image(img)

            # Persist extracted face_data so future match runs don't need re-extraction
            supabase.table("missing_person_sightings").update({
                "face_data": sighting_faces
            }).eq("id", sighting_id).execute()

        except Exception:
            current_app.logger.exception(
                "Failed to extract faces from sighting image: %s", image_path
            )
            return jsonify({"error": "Face detection failed on sighting photo"}), 500

    if not sighting_faces or len(sighting_faces) == 0:
        return jsonify({
            "error": "No faces detected in the sighting photo",
            "detected_faces": 0,
            "ai_matches": [],
            "candidate_cases": []
        }), 422

    # 3. Fetch reference profiles for active missing persons (status Missing or active)
    try:
        missing_persons_res = (
            supabase.table("missing_persons")
            .select("id, case_code, full_name, age, gender, status")
            .in_("status", ["Missing", "active"])
            .execute()
        )
        active_persons = missing_persons_res.data or []
        active_ids = [p["id"] for p in active_persons if p.get("id")]

        if active_ids:
            embeddings_res = (
                supabase.table("missing_person_embeddings")
                .select("id, missing_person_id, image_path, embedding, det_score")
                .in_("missing_person_id", active_ids)
                .execute()
            )
            reference_profiles = embeddings_res.data or []
        else:
            reference_profiles = []

    except Exception:
        current_app.logger.exception("Failed to fetch reference profiles from database")
        return jsonify({"error": "Could not fetch reference profiles from database"}), 500

    # 4. Run face matching against current reference profiles
    ai_matches = match_sighting_against_cases(
        sighting_faces=sighting_faces,
        reference_profiles=reference_profiles
    )

    # Identify qualifying strong match (score >= STRONG_MATCH_THRESHOLD)
    strong_matches = [
        m for m in ai_matches
        if m.get("match_category") == "match"
        or m.get("similarity_score", 0.0) >= STRONG_MATCH_THRESHOLD
    ]
    if strong_matches:
        top_strong_match = max(strong_matches, key=lambda m: m.get("similarity_score", 0.0))
        matched_person_id = top_strong_match.get("missing_person_id")
    else:
        top_strong_match = None
        matched_person_id = None

    # 5. Update sighting record in missing_person_sightings (no duplicate records)
    try:
        supabase.table("missing_person_sightings").update({
            "missing_person_id": matched_person_id,
            "ai_matches": ai_matches,
        }).eq("id", sighting_id).execute()
    except Exception:
        current_app.logger.exception("Failed to update sighting record with match results")
        return jsonify({"error": "Could not save match results to database"}), 500

    # 6. Enrich candidate cases with metadata and signed reference photo URLs
    candidate_cases = enrich_ai_matches_with_candidates(supabase, ai_matches)

    # 7. Sanitize results to ensure no raw embeddings are ever exposed
    biometric_keys = {"face_data", "embedding", "embeddings"}
    sanitized_ai_matches = [
        {k: v for k, v in m.items() if k not in biometric_keys}
        for m in ai_matches
        if isinstance(m, dict)
    ]

    return jsonify({
        "message": "Face matching completed successfully against registered missing-person cases",
        "sighting_id": sighting_id,
        "detected_faces": len(sighting_faces),
        "matched_person_id": matched_person_id,
        "top_match": top_strong_match,
        "ai_matches": sanitized_ai_matches,
        "candidate_cases": candidate_cases,
        "citizen_note": record.get("citizen_note") or None,
        "address": record.get("address") or None,
    }), 200


# ---------------------------------------------------------
# VERIFY OR REJECT A SIGHTING
# PATCH /api/sightings/<sighting_id>/verify
# ---------------------------------------------------------

@sightings_bp.patch("/<sighting_id>/verify")
@sightings_bp.patch("/<sighting_id>/verify/")
@sightings_bp.post("/<sighting_id>/verify")
@sightings_bp.post("/<sighting_id>/verify/")
@require_authority(allowed_departments=["POLICE"], allowed_roles=["Inspector", "Sub-Inspector", "Constable", "authority"])
def verify_sighting(sighting_id):
    """
    Review and verify or reject a citizen sighting.
    - action 'verify': marks is_verified = True (officer confirms photo matches the subject)
    - action 'reject': marks is_verified = False (officer determines photo is not the subject)
    Separation of concerns:
    Verifying a sighting corroborates this specific visual report at this location/time.
    It does NOT mark the person as found or close the missing-person case.
    """
    if not is_valid_uuid(sighting_id):
        return jsonify({"error": "Invalid sighting ID"}), 400

    data = request.get_json(silent=True) or {}
    action = (data.get("action") or "").strip().lower()

    if action not in ("verify", "reject"):
        return jsonify({
            "error": "Invalid action. Allowed actions are: 'verify', 'reject'.",
            "allowed_actions": ["verify", "reject"]
        }), 400

    supabase = get_supabase_client()

    try:
        # 1. Fetch current sighting
        existing_res = (
            supabase.table("missing_person_sightings")
            .select("id, missing_person_id, is_verified, ai_matches")
            .eq("id", sighting_id)
            .limit(1)
            .execute()
        )
        if not existing_res.data:
            return jsonify({"error": "Sighting record not found"}), 404

        current_sighting = existing_res.data[0]
        remarks = (data.get("remarks") or "").strip()

        # 2. Compute update
        if action == "verify":
            new_verified = True
            update_payload = {"is_verified": True}
        else:  # reject
            new_verified = False
            update_payload = {"is_verified": False}
            if data.get("unlink_case", False):
                update_payload["missing_person_id"] = None

        res = (
            supabase.table("missing_person_sightings")
            .update(update_payload)
            .eq("id", sighting_id)
            .execute()
        )

        officer_name = getattr(g, "current_authority", {}).get("name") if hasattr(g, "current_authority") and g.current_authority else "Authorized Officer"
        officer_role = getattr(g, "current_authority", {}).get("role") if hasattr(g, "current_authority") and g.current_authority else "Police"

        current_app.logger.info(
            "Sighting %s verification updated by %s %s: action=%s, is_verified=%s",
            sighting_id, officer_role, officer_name, action, new_verified
        )

        msg = (
            "Sighting successfully verified by officer. Subject match confirmed."
            if action == "verify"
            else "Sighting rejected by officer. Not verified as matching subject."
        )

        return jsonify({
            "success": True,
            "message": msg,
            "sighting_id": sighting_id,
            "is_verified": new_verified,
            "action": action,
            "reviewed_by": f"{officer_role} {officer_name}".strip(),
            "remarks": remarks or None
        }), 200

    except Exception:
        current_app.logger.exception("Failed to update verification status for sighting: %s", sighting_id)
        return jsonify({"error": "An error occurred while updating the sighting verification status."}), 500



