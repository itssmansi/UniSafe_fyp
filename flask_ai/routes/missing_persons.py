import os
import io
from flask import Blueprint, request, jsonify, current_app, g
import cv2
import numpy as np
from datetime import datetime
from uuid import UUID
from werkzeug.utils import secure_filename

from database.supabase_client import get_supabase_client
from services.face_recognition import extract_reference_face_from_image
from middleware.auth import require_authority, optional_authority


missing_person_bp = Blueprint(
    "missing_persons",
    __name__,
    url_prefix="/api/missing-persons"
)

BUCKET_NAME = "missing-person-images"
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
EXPECTED_EMBEDDING_SIZE = 512
DEFAULT_MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB
DEFAULT_SIGNED_URL_EXPIRY_SECONDS = 3600  # 1 hour


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


def get_signed_url_expiry_seconds():
    """Retrieve signed URL expiration seconds from env or config with safe default."""
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
        return res.get("signedURL") or res.get("signedUrl")
    if isinstance(res, str):
        return res
    if hasattr(res, "signedURL"):
        return res.signedURL
    if hasattr(res, "signedUrl"):
        return res.signedUrl
    return str(res) if res else None


def is_valid_uuid(val):
    """Check whether a given value is a valid UUID string."""
    if not val or not isinstance(val, str):
        return False
    try:
        UUID(val.strip())
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def optional_float(value, field_name):
    if value is None or not value.strip():
        return None

    try:
        return float(value)
    except ValueError:
        raise ValueError(f"{field_name} must be a number")


def validate_uploaded_image(image):
    """Validate an uploaded image and extract exactly one face embedding."""

    if image is None or not image.filename:
        return None, None, None, None, (
            jsonify({"error": "A reference photo is required"}), 400
        )

    filename = secure_filename(image.filename)

    if not filename or "." not in filename:
        return None, None, None, None, (
            jsonify({"error": "Invalid image filename"}), 400
        )

    extension = filename.rsplit(".", 1)[-1].lower()

    if extension not in ALLOWED_EXTENSIONS:
        return None, None, None, None, (
            jsonify({
                "error": "Image must be JPG, JPEG, PNG, or WEBP"
            }), 400
        )

    max_size = get_max_image_size_bytes()

    # Check size without loading entire file into memory if stream supports seeking
    try:
        image.seek(0, os.SEEK_END)
        size = image.tell()
        image.seek(0)
        if size > max_size:
            return None, None, None, None, (
                jsonify({
                    "error": f"Image file exceeds maximum allowed size of {max_size // (1024 * 1024)}MB"
                }), 400
            )
    except (AttributeError, io.UnsupportedOperation, OSError, ValueError):
        pass

    # Read bounded chunk (max_size + 1) to prevent unbounded memory usage on non-seekable streams
    image_bytes = image.read(max_size + 1)

    if not image_bytes:
        return None, None, None, None, (
            jsonify({"error": "Uploaded image is empty"}), 400
        )

    if len(image_bytes) > max_size:
        return None, None, None, None, (
            jsonify({
                "error": f"Image file exceeds maximum allowed size of {max_size // (1024 * 1024)}MB"
            }), 400
        )

    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(image_array, cv2.IMREAD_COLOR)

    if img is None:
        return None, None, None, None, (
            jsonify({"error": "Uploaded file is not a valid image"}), 400
        )

    try:
        embedding, det_score, face_count = (
            extract_reference_face_from_image(img)
        )
    except ValueError as error:
        return None, None, None, None, (
            jsonify({"error": str(error)}), 422
        )

    if face_count != 1:
        return None, None, None, None, (
            jsonify({
                "error": (
                    "Photo must contain exactly one detectable face"
                ),
                "detected_faces": face_count
            }), 422
        )

    if len(embedding) != EXPECTED_EMBEDDING_SIZE:
        current_app.logger.error(
            "Unexpected embedding size: %s", len(embedding)
        )
        return None, None, None, None, (
            jsonify({"error": "Unexpected face embedding size"}), 500
        )

    return (
        image_bytes,
        filename,
        embedding,
        float(det_score),
        None
    )


def serialize_embedding(embedding):
    """Convert a numeric embedding to pgvector-compatible text."""
    return "[" + ",".join(str(float(value)) for value in embedding) + "]"


def get_content_type(image, extension):
    if image.content_type:
        return image.content_type

    content_types = {
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "png": "image/png",
        "webp": "image/webp"
    }
    return content_types[extension]


def cleanup_storage_object(supabase, storage_path):
    """Attempt to remove an uploaded object after a failed database write."""
    try:
        res = supabase.storage.from_(BUCKET_NAME).remove([storage_path])
        if not res or not isinstance(res, list):
            current_app.logger.warning(
                "Cleanup: Storage remove returned empty or unexpected response for %s: %s",
                storage_path, res
            )
    except Exception:
        current_app.logger.exception(
            "Failed to clean up Storage object: %s", storage_path
        )


# ---------------------------------------------------------
# CREATE A NEW MISSING-PERSON REPORT
# POST /api/missing-persons
# ---------------------------------------------------------

@missing_person_bp.post("")
@require_authority(allowed_departments=["POLICE"])
def create_missing_person_report():

    # 0. Validate officer jurisdiction from authenticated context
    authority = getattr(g, "current_authority", None) or {}
    officer_jurisdiction = (authority.get("jurisdiction") or "").strip()

    if not officer_jurisdiction:
        return jsonify({
            "error": "Access denied: Officer account has no assigned jurisdiction."
        }), 403

    # Do not allow client to register under another station's jurisdiction
    client_jurisdiction = request.form.get("jurisdiction", "").strip()
    if client_jurisdiction and client_jurisdiction.lower() != officer_jurisdiction.lower():
        return jsonify({
            "error": f"Jurisdiction mismatch: Cannot register case for '{client_jurisdiction}'. Your assigned station is '{officer_jurisdiction}'."
        }), 403

    # 1. Read person details
    full_name = request.form.get("full_name", "").strip()
    age = request.form.get("age")
    gender = request.form.get("gender")
    last_seen_date = request.form.get("last_seen_date")
    latitude = request.form.get("latitude")
    longitude = request.form.get("longitude")
    description = request.form.get("description")

    if not full_name:
        return jsonify({"error": "full_name is required"}), 400

    # Validate last_seen_date if provided
    parsed_last_seen = None
    if last_seen_date and last_seen_date.strip():
        try:
            parsed_last_seen = datetime.fromisoformat(
                last_seen_date.strip().replace("Z", "+00:00")
            ).isoformat()
        except ValueError:
            return jsonify({
                "error": "Invalid last_seen_date. Use ISO 8601 format."
            }), 400

    # 2. Validate the reference image and extract its embedding
    image = request.files.get("missing_person_image")

    (
        image_bytes,
        filename,
        embedding,
        det_score,
        error_response
    ) = validate_uploaded_image(image)

    if error_response:
        return error_response

    extension = filename.rsplit(".", 1)[-1].lower()

    # 3. Validate form values
    try:
        parsed_age = int(age) if age and age.strip() else None
        parsed_latitude = optional_float(latitude, "latitude")
        parsed_longitude = optional_float(longitude, "longitude")
    except ValueError as error:
        return jsonify({"error": str(error)}), 400

    if parsed_age is not None and not 0 <= parsed_age <= 150:
        return jsonify({
            "error": "age must be between 0 and 150"
        }), 400

    if parsed_latitude is not None and not -90 <= parsed_latitude <= 90:
        return jsonify({
            "error": "latitude must be between -90 and 90"
        }), 400

    if parsed_longitude is not None and not -180 <= parsed_longitude <= 180:
        return jsonify({
            "error": "longitude must be between -180 and 180"
        }), 400

    supabase = get_supabase_client()
    person_id = None
    storage_path = None
    image_uploaded = False

    try:
        # 4. Create the person record.
        # The database trigger generates the case_code.
        person_data = {
            "full_name": full_name,
            "age": parsed_age,
            "gender": gender or None,
            "last_seen_date": parsed_last_seen,
            "latitude": parsed_latitude,
            "longitude": parsed_longitude,
            "description": description or None,
            "status": "Missing",
            "jurisdiction": officer_jurisdiction
        }

        response = (
            supabase.table("missing_persons")
            .insert(person_data)
            .execute()
        )

        if not response.data:
            raise RuntimeError("Person record was not returned")

        person = response.data[0]
        person_id = person["id"]
        case_code = person.get("case_code")

        if not case_code:
            raise RuntimeError(
                "Database did not return the generated case code"
            )

        # 5. Upload the first photo to the person's folder
        storage_path = (
            f"missing_people/{case_code}/photo_1.{extension}"
        )

        supabase.storage.from_(BUCKET_NAME).upload(
            storage_path,
            image_bytes,
            {
                "content-type": get_content_type(image, extension),
                "upsert": "false"
            }
        )
        image_uploaded = True

        # 6. Save the face embedding
        supabase.table("missing_person_embeddings").insert({
            "missing_person_id": person_id,
            "image_path": storage_path,
            "embedding": serialize_embedding(embedding),
            "det_score": det_score
        }).execute()

        return jsonify({
            "message": "Missing-person report created successfully",
            "person_id": person_id,
            "case_code": case_code,
            "full_name": full_name,
            "jurisdiction": officer_jurisdiction,
            "image_path": storage_path,
            "face_count": 1,
            "detection_score": det_score
        }), 201

    except Exception:
        current_app.logger.exception(
            "Failed to create missing-person report"
        )

        # Remove only the object created by this request
        if image_uploaded and storage_path:
            cleanup_storage_object(supabase, storage_path)

        # Remove only the person created by this request
        if person_id:
            try:
                (
                    supabase.table("missing_persons")
                    .delete()
                    .eq("id", person_id)
                    .execute()
                )
            except Exception:
                current_app.logger.exception(
                    "Failed to clean up person record: %s", person_id
                )

        return jsonify({
            "error": "Could not create the missing-person report"
        }), 500


# ---------------------------------------------------------
# ADD A PHOTO TO AN EXISTING PERSON
# POST /api/missing-persons/<person_id>/photos
# ---------------------------------------------------------

@missing_person_bp.post("/<person_id>/photos")
@require_authority(allowed_departments=["POLICE"])
def add_missing_person_photo(person_id):
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID"
        }), 400

    supabase = get_supabase_client()

    # 1. Find the existing person.
    # This endpoint must NOT insert into missing_persons.
    try:
        response = (
            supabase.table("missing_persons")
            .select("id, full_name, case_code, jurisdiction")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )

        if not response.data:
            return jsonify({
                "error": "Missing-person record not found"
            }), 404

        person = response.data[0]
        case_code = person.get("case_code")
        case_jurisdiction = (person.get("jurisdiction") or "").strip()

        if not case_code:
            return jsonify({
                "error": "Person has no case code"
            }), 500

        authority = getattr(g, "current_authority", None) or {}
        officer_jurisdiction = (authority.get("jurisdiction") or "").strip()
        if not officer_jurisdiction:
            return jsonify({
                "error": "Access forbidden: Officer account has no assigned jurisdiction."
            }), 403
        if not case_jurisdiction:
            return jsonify({
                "error": "Access forbidden: Case has no assigned jurisdiction."
            }), 403
        if case_jurisdiction.lower() != officer_jurisdiction.lower():
            return jsonify({
                "error": f"Access forbidden: Case belongs to '{case_jurisdiction}' jurisdiction, not '{officer_jurisdiction}'."
            }), 403

    except Exception:
        current_app.logger.exception(
            "Failed to fetch missing-person record"
        )
        return jsonify({
            "error": "Could not fetch missing-person record"
        }), 500

    # 2. Validate the additional photo
    image = request.files.get("missing_person_image")

    (
        image_bytes,
        filename,
        embedding,
        det_score,
        error_response
    ) = validate_uploaded_image(image)

    if error_response:
        return error_response

    extension = filename.rsplit(".", 1)[-1].lower()
    storage_path = f"missing_people/{case_code}/{filename}"

    # 3. Reject a path already registered for this person
    try:
        existing = (
            supabase.table("missing_person_embeddings")
            .select("id")
            .eq("missing_person_id", person["id"])
            .eq("image_path", storage_path)
            .limit(1)
            .execute()
        )
    except Exception:
        current_app.logger.exception(
            "Failed to check existing photo"
        )
        return jsonify({
            "error": "Could not check existing photo"
        }), 500

    if existing.data:
        return jsonify({
            "error": (
                "This photo filename is already registered "
                "for this person"
            )
        }), 409

    image_uploaded = False

    try:
        # 4. Upload to the existing person's Storage folder.
        # upsert=false prevents overwriting an existing object.
        supabase.storage.from_(BUCKET_NAME).upload(
            storage_path,
            image_bytes,
            {
                "content-type": get_content_type(image, extension),
                "upsert": "false"
            }
        )
        image_uploaded = True
    except Exception as upload_error:
        current_app.logger.exception(
            "Failed to upload reference photo: %s", storage_path
        )
        err_str = str(upload_error).lower()
        if "already exists" in err_str or "duplicate" in err_str or "409" in err_str:
            return jsonify({
                "error": "A photo with this filename already exists in storage for this case"
            }), 409
        return jsonify({
            "error": "Could not upload reference photo to storage"
        }), 500

    try:
        # 5. Attach the embedding to the EXISTING person ID
        supabase.table("missing_person_embeddings").insert({
            "missing_person_id": person["id"],
            "image_path": storage_path,
            "embedding": serialize_embedding(embedding),
            "det_score": det_score
        }).execute()

        return jsonify({
            "message": "Reference photo added successfully",
            "person_id": person["id"],
            "case_code": case_code,
            "full_name": person["full_name"],
            "image_path": storage_path,
            "face_count": 1,
            "detection_score": det_score
        }), 201

    except Exception:
        current_app.logger.exception(
            "Failed to add reference photo embedding"
        )

        # If the database insert fails, attempt to remove
        # only the Storage object uploaded by this request.
        if image_uploaded:
            cleanup_storage_object(supabase, storage_path)

        return jsonify({
            "error": "Could not add reference photo"
        }), 500


def fetch_person_photos_with_signed_urls(supabase, person_id):
    """
    Query missing_person_embeddings for the given person_id and generate
    time-limited signed URLs from the private Storage bucket.
    Excludes raw 512-D face embedding vectors.

    Returns:
        tuple (photos, error_response):
            photos: list of photo dicts on success, or None on error
            error_response: (jsonify_response, status_code) on error, or None on success
    """
    try:
        photos_res = (
            supabase.table("missing_person_embeddings")
            .select("id, image_path, det_score, created_at")
            .eq("missing_person_id", person_id)
            .order("created_at")
            .execute()
        )
        photo_records = photos_res.data or []
    except Exception:
        current_app.logger.exception(
            "Failed to query reference photos for case: %s", person_id
        )
        return None, (
            jsonify({"error": "Could not query reference photos"}),
            500,
        )

    expiry = get_signed_url_expiry_seconds()
    photos = []

    for record in photo_records:
        image_path = record.get("image_path")
        if not image_path:
            continue

        try:
            url_res = supabase.storage.from_(BUCKET_NAME).create_signed_url(
                image_path,
                expires_in=expiry
            )
            signed_url = extract_signed_url(url_res)
            if not signed_url:
                raise RuntimeError(
                    f"Storage returned empty signed URL for {image_path}"
                )
        except Exception:
            current_app.logger.exception(
                "Failed to generate signed URL for reference photo: %s",
                image_path
            )
            return None, (
                jsonify({"error": "Could not generate signed photo URLs"}),
                500,
            )

        photos.append({
            "embedding_id": record.get("id"),
            "image_path": image_path,
            "signed_url": signed_url,
            "detection_score": record.get("det_score"),
            "created_at": record.get("created_at"),
        })

    return photos, None


# ---------------------------------------------------------
# LIST MISSING-PERSON CASES
# GET /api/missing-persons
# ---------------------------------------------------------

@missing_person_bp.get("")
@missing_person_bp.get("/")
@optional_authority
def get_missing_persons_list():
    """
    Retrieve a list of missing-person cases using confirmed database columns.
    Supports optional status filtering (e.g. ?status=Missing, ?status=all).
    Excludes any raw biometric embedding vectors or internal face data.
    """
    supabase = get_supabase_client()

    # Confirmed columns in public.missing_persons
    columns = (
        "id, case_code, full_name, age, gender, "
        "last_seen_date, latitude, longitude, description, status, jurisdiction, created_at"
    )

    try:
        query = (
            supabase.table("missing_persons")
            .select(columns)
            .order("created_at", desc=True)
        )

        # Optional status filtering
        status_param = request.args.get("status")
        if status_param is not None:
            status_clean = status_param.strip()
            if status_clean and status_clean.lower() != "all":
                query = query.eq("status", status_clean)

        # Jurisdiction filtering / station scoping
        jurisdiction_param = request.args.get("jurisdiction")
        authority = getattr(g, "current_authority", None) or {}
        officer_jurisdiction = (authority.get("jurisdiction") or "").strip()
        dept = (authority.get("department") or "").strip().upper()

        if dept == "POLICE" and officer_jurisdiction:
            # Authenticated police officers can only view cases within their assigned station
            query = query.ilike("jurisdiction", officer_jurisdiction)
        elif jurisdiction_param is not None:
            jurisdiction_clean = jurisdiction_param.strip()
            if jurisdiction_clean and jurisdiction_clean.lower() != "all":
                query = query.ilike("jurisdiction", jurisdiction_clean)

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

        person_res = query.execute()
        case_records = person_res.data or []

    except Exception:
        current_app.logger.exception(
            "Failed to query missing-person cases from database"
        )
        return jsonify({
            "error": "Could not query missing-person cases"
        }), 500

    # Fetch associated reference photos for cases
    photos_by_person = {}
    person_ids = [r.get("id") for r in case_records if r.get("id")]
    if person_ids:
        try:
            emb_builder = supabase.table("missing_person_embeddings").select(
                "id, missing_person_id, image_path, created_at"
            )
            if hasattr(emb_builder, "in_"):
                emb_query = emb_builder.in_("missing_person_id", person_ids)
            else:
                emb_query = emb_builder
            if hasattr(emb_query, "order"):
                emb_query = emb_query.order("created_at")
            emb_res = emb_query.execute()
            emb_data = emb_res.data or []
            for emb in emb_data:
                if isinstance(emb, dict):
                    pid = emb.get("missing_person_id")
                    if pid and pid in person_ids:
                        photos_by_person.setdefault(pid, []).append(emb)
        except Exception:
            current_app.logger.warning(
                "Could not query reference photos for missing persons list",
                exc_info=True
            )

    expiry = get_signed_url_expiry_seconds()
    paths_to_sign = []
    for pid, p_list in photos_by_person.items():
        for p in p_list:
            img_path = p.get("image_path")
            if img_path and img_path not in paths_to_sign:
                paths_to_sign.append(img_path)

    path_to_signed_url = {}
    if paths_to_sign:
        try:
            storage_bucket = supabase.storage.from_(BUCKET_NAME)
            if hasattr(storage_bucket, "create_signed_urls"):
                batch_res = storage_bucket.create_signed_urls(paths_to_sign, expires_in=expiry)
                for item in (batch_res or []):
                    if isinstance(item, dict) and item.get("path"):
                        s_url = extract_signed_url(item)
                        if s_url:
                            path_to_signed_url[item["path"]] = s_url

            for p_path in paths_to_sign:
                if p_path not in path_to_signed_url:
                    try:
                        s_res = storage_bucket.create_signed_url(p_path, expires_in=expiry)
                        s_url = extract_signed_url(s_res)
                        if s_url:
                            path_to_signed_url[p_path] = s_url
                    except Exception:
                        pass
        except Exception:
            current_app.logger.warning(
                "Could not generate signed URLs for missing persons list photos",
                exc_info=True
            )

    # Ensure no internal biometric vectors are ever exposed
    biometric_keys = {"embedding", "embeddings", "face_data"}
    sanitized_cases = []
    for record in case_records:
        rec_id = record.get("id")
        p_photos = photos_by_person.get(rec_id, [])
        primary_photo_path = p_photos[0].get("image_path") if p_photos else None
        photo_url = path_to_signed_url.get(primary_photo_path) if primary_photo_path else None

        sanitized = {
            k: v for k, v in record.items() if k not in biometric_keys
        }
        sanitized["photo_url"] = photo_url
        sanitized_cases.append(sanitized)

    return jsonify({
        "missing_persons": sanitized_cases,
        "count": len(sanitized_cases),
        "total": len(sanitized_cases),
    }), 200


# ---------------------------------------------------------
# GET REFERENCE PHOTOS FOR AN EXISTING PERSON
# GET /api/missing-persons/<person_id>/photos
# ---------------------------------------------------------

@missing_person_bp.get("/<person_id>/photos")
@require_authority(allowed_departments=["POLICE"])
def get_missing_person_photos(person_id):
    """
    Retrieve reference photos for a missing-person case.
    Generates time-limited signed URLs for the private Storage bucket
    and excludes raw 512-D face embedding vectors.
    """
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID"
        }), 400

    # 1. Authority validation
    authority = getattr(g, "current_authority", None) or {}
    officer_dept = (authority.get("department") or "").strip().upper()
    officer_jurisdiction = (authority.get("jurisdiction") or "").strip()

    if officer_dept != "POLICE" or not officer_jurisdiction:
        return jsonify({
            "error": "Access forbidden: Only authorized police officers with an assigned jurisdiction may view reference photos."
        }), 403

    supabase = get_supabase_client()

    # 2. Verify case exists in missing_persons and fetch jurisdiction
    try:
        person_res = (
            supabase.table("missing_persons")
            .select("id, case_code, jurisdiction")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )
        if not person_res.data:
            return jsonify({
                "error": "Missing-person case not found"
            }), 404

        person = person_res.data[0]
        case_code = person.get("case_code")

    except Exception:
        current_app.logger.exception(
            "Failed to verify missing-person case: %s", person_id
        )
        return jsonify({
            "error": "Could not verify missing-person case"
        }), 500

    # 3. Verify case jurisdiction is non-NULL and matches officer jurisdiction
    case_jurisdiction = (person.get("jurisdiction") or "").strip()
    if not case_jurisdiction:
        return jsonify({
            "error": "Access forbidden: Case has no assigned jurisdiction."
        }), 403

    if case_jurisdiction.lower() != officer_jurisdiction.lower():
        return jsonify({
            "error": f"Access forbidden: Case belongs to '{case_jurisdiction}' jurisdiction, not '{officer_jurisdiction}'."
        }), 403

    # 4. Query photos and generate signed URLs (excluding raw embeddings)
    # Executed strictly AFTER the jurisdiction check has passed!
    photos, error_response = fetch_person_photos_with_signed_urls(supabase, person_id)
    if error_response:
        return error_response

    return jsonify({
        "person_id": person["id"],
        "case_code": case_code,
        "photo_count": len(photos),
        "photos": photos,
    }), 200


# ---------------------------------------------------------
# GET SINGLE MISSING-PERSON CASE DETAILS
# GET /api/missing-persons/<person_id>
# ---------------------------------------------------------

@missing_person_bp.get("/<person_id>")
@require_authority(allowed_departments=["POLICE"])
def get_missing_person_report(person_id):
    """
    Retrieve details of a single missing-person case by UUID,
    including associated reference photos with time-limited signed URLs.
    Never returns raw face embeddings or internal biometric vectors.
    """
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID"
        }), 400

    # 1. Authority validation
    authority = getattr(g, "current_authority", None) or {}
    officer_dept = (authority.get("department") or "").strip().upper()
    officer_jurisdiction = (authority.get("jurisdiction") or "").strip()

    if officer_dept != "POLICE" or not officer_jurisdiction:
        return jsonify({
            "error": "Access forbidden: Only authorized police officers with an assigned jurisdiction may access case details."
        }), 403

    supabase = get_supabase_client()

    # 2. Fetch case record from missing_persons
    try:
        person_res = (
            supabase.table("missing_persons")
            .select("*")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )
        if not person_res.data:
            return jsonify({
                "error": "Missing-person case not found"
            }), 404

        person = person_res.data[0]

    except Exception:
        current_app.logger.exception(
            "Failed to fetch missing-person case: %s", person_id
        )
        return jsonify({
            "error": "Could not fetch missing-person case"
        }), 500

    # 3. Verify case jurisdiction is non-NULL and matches officer jurisdiction
    case_jurisdiction = (person.get("jurisdiction") or "").strip()
    if not case_jurisdiction:
        return jsonify({
            "error": "Access forbidden: Case has no assigned jurisdiction."
        }), 403

    if case_jurisdiction.lower() != officer_jurisdiction.lower():
        return jsonify({
            "error": f"Access forbidden: Case belongs to '{case_jurisdiction}' jurisdiction, not '{officer_jurisdiction}'."
        }), 403

    # 4. Query photos and generate signed URLs (excluding raw embeddings)
    # Executed strictly AFTER the jurisdiction check has passed!
    photos, error_response = fetch_person_photos_with_signed_urls(supabase, person_id)
    if error_response:
        return error_response

    # 5. Build sanitized response without raw biometric embeddings
    biometric_keys = {"embedding", "embeddings", "face_data"}
    case_data = {k: v for k, v in person.items() if k not in biometric_keys}
    case_data["photos"] = photos
    case_data["photo_count"] = len(photos)

    return jsonify(case_data), 200


# ---------------------------------------------------------
# DELETE A PHOTO FROM AN EXISTING PERSON
# DELETE /api/missing-persons/<person_id>/photos
# JSON body: {"embedding_id": "<photo embedding UUID>"}
# ---------------------------------------------------------

@missing_person_bp.delete("/<person_id>/photos")
@require_authority(allowed_departments=["POLICE"])
def delete_missing_person_photo(person_id):
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID"
        }), 400

    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return jsonify({
            "error": "Request body must be a JSON object"
        }), 400

    embedding_id = data.get("embedding_id")
    if not embedding_id or not is_valid_uuid(str(embedding_id)):
        return jsonify({
            "error": "A valid embedding_id UUID is required"
        }), 400

    supabase = get_supabase_client()

    # 1. Verify that the person exists.
    try:
        person_response = (
            supabase.table("missing_persons")
            .select("id, full_name, case_code, jurisdiction")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )

        if not person_response.data:
            return jsonify({
                "error": "Missing-person record not found"
            }), 404

        person = person_response.data[0]
        case_jurisdiction = (person.get("jurisdiction") or "").strip()

        authority = getattr(g, "current_authority", None) or {}
        officer_jurisdiction = (authority.get("jurisdiction") or "").strip()
        if not officer_jurisdiction:
            return jsonify({
                "error": "Access forbidden: Officer account has no assigned jurisdiction."
            }), 403
        if not case_jurisdiction:
            return jsonify({
                "error": "Access forbidden: Case has no assigned jurisdiction."
            }), 403
        if case_jurisdiction.lower() != officer_jurisdiction.lower():
            return jsonify({
                "error": f"Access forbidden: Case belongs to '{case_jurisdiction}' jurisdiction, not '{officer_jurisdiction}'."
            }), 403

    except Exception:
        current_app.logger.exception(
            "Failed to fetch missing-person record"
        )
        return jsonify({
            "error": "Could not fetch missing-person record"
        }), 500

    # 2. Find the selected photo and verify ownership.
    try:
        photo_response = (
            supabase.table("missing_person_embeddings")
            .select("id, missing_person_id, image_path")
            .eq("id", embedding_id)
            .eq("missing_person_id", person_id)
            .limit(1)
            .execute()
        )

        if not photo_response.data:
            return jsonify({
                "error": "Photo not found for this person"
            }), 404

        photo = photo_response.data[0]

        # 3. Prevent deleting the last reference photo.
        count_response = (
            supabase.table("missing_person_embeddings")
            .select("id")
            .eq("missing_person_id", person_id)
            .execute()
        )

        if len(count_response.data) <= 1:
            return jsonify({
                "error": (
                    "Cannot delete the last reference photo. "
                    "Add another photo first."
                )
            }), 409

    except Exception:
        current_app.logger.exception(
            "Failed to verify reference photo"
        )
        return jsonify({
            "error": "Could not verify reference photo"
        }), 500

    storage_path = photo["image_path"]

    # 4. Remove the Storage object.
    try:
        storage_res = supabase.storage.from_(BUCKET_NAME).remove([storage_path])

        if isinstance(storage_res, dict) and (
            "error" in storage_res or storage_res.get("statusCode", 200) >= 400
        ):
            current_app.logger.error(
                "Storage remove returned error payload for '%s': %s",
                storage_path, storage_res
            )
            return jsonify({
                "error": "Could not remove photo from Storage",
                "image_path": storage_path
            }), 500

        if not storage_res or not isinstance(storage_res, list):
            current_app.logger.warning(
                "Storage remove returned empty or non-list response for '%s'; "
                "object may have already been absent: %s",
                storage_path, storage_res
            )
    except Exception:
        current_app.logger.exception(
            "Failed to remove Storage object: %s",
            storage_path
        )
        return jsonify({
            "error": "Could not remove photo from Storage",
            "image_path": storage_path
        }), 500

    # 5. Delete only the selected embedding record.
    try:
        (
            supabase.table("missing_person_embeddings")
            .delete()
            .eq("id", embedding_id)
            .eq("missing_person_id", person_id)
            .execute()
        )

        return jsonify({
            "message": "Reference photo deleted successfully",
            "person_id": person_id,
            "embedding_id": embedding_id,
            "image_path": storage_path
        }), 200

    except Exception as db_err:
        current_app.logger.critical(
            "INCONSISTENCY: Storage object removed or absent, but embedding database deletion failed: "
            "person_id=%s, embedding_id=%s, storage_path=%s, error=%s",
            person_id, embedding_id, storage_path, str(db_err)
        )
        return jsonify({
            "error": (
                "Photo was removed from Storage, but its database "
                "record could not be deleted. Administrator cleanup "
                "is required."
            ),
            "person_id": person_id,
            "embedding_id": embedding_id,
            "image_path": storage_path
        }), 500


@missing_person_bp.patch("/<person_id>")
@require_authority(allowed_departments=["POLICE"])
def update_missing_person_report(person_id):
    """
    Update editable details of an existing missing-person case.

    Authentication and authority-role checks must be integrated
    before this endpoint is exposed for use.
    """
    # Validate the case UUID.
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID."
        }), 400

    data = request.get_json(silent=True)

    if not isinstance(data, dict) or not data:
        return jsonify({
            "error": "Provide a JSON object containing fields to update."
        }), 400

    # Only these fields can be modified through this endpoint.
    allowed_fields = {
        "full_name",
        "age",
        "gender",
        "last_seen_date",
        "latitude",
        "longitude",
        "description",
    }

    unexpected_fields = set(data.keys()) - allowed_fields

    if unexpected_fields:
        return jsonify({
            "error": "Unsupported fields provided.",
            "fields": sorted(unexpected_fields),
        }), 400

    updates = {}

    # Validate full_name.
    if "full_name" in data:
        full_name = data["full_name"]

        if not isinstance(full_name, str) or not full_name.strip():
            return jsonify({
                "error": "full_name must be a non-empty string."
            }), 400

        updates["full_name"] = full_name.strip()

    # Validate age.
    if "age" in data:
        age = data["age"]

        if age is None:
            updates["age"] = None
        elif (
            isinstance(age, bool)
            or not isinstance(age, int)
            or not 0 <= age <= 120
        ):
            return jsonify({
                "error": "age must be an integer between 0 and 120, or null."
            }), 400
        else:
            updates["age"] = age

    # Validate optional text fields.
    for field in ("gender", "description"):
        if field in data:
            value = data[field]

            if value is not None and not isinstance(value, str):
                return jsonify({
                    "error": f"{field} must be text or null."
                }), 400

            updates[field] = (
                value.strip() if (isinstance(value, str) and value.strip()) else None
            )

    # Validate last_seen_date.
    if "last_seen_date" in data:
        value = data["last_seen_date"]

        if value is None:
            updates["last_seen_date"] = None
        elif not isinstance(value, str):
            return jsonify({
                "error": "last_seen_date must be an ISO 8601 date/time string or null."
            }), 400
        else:
            try:
                parsed_date = datetime.fromisoformat(
                    value.strip().replace("Z", "+00:00")
                )
                updates["last_seen_date"] = parsed_date.isoformat()
            except ValueError:
                return jsonify({
                    "error": "Invalid last_seen_date. Use ISO 8601 format."
                }), 400

    # Validate coordinates.
    for field, minimum, maximum in (
        ("latitude", -90, 90),
        ("longitude", -180, 180),
    ):
        if field in data:
            value = data[field]

            if value is None:
                updates[field] = None
            else:
                if isinstance(value, bool):
                    return jsonify({
                        "error": f"{field} must be a number or null."
                    }), 400

                try:
                    parsed_value = float(value)
                except (TypeError, ValueError):
                    return jsonify({
                        "error": f"{field} must be a number or null."
                    }), 400

                if not np.isfinite(parsed_value) or not minimum <= parsed_value <= maximum:
                    return jsonify({
                        "error": f"{field} is outside its valid range."
                    }), 400

                updates[field] = parsed_value

    if not updates:
        return jsonify({
            "error": "No valid fields were provided for updating."
        }), 400

    try:
        supabase = get_supabase_client()

        # Confirm the case exists before updating it.
        existing = (
            supabase.table("missing_persons")
            .select("id, case_code")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )

        if not existing.data:
            return jsonify({
                "error": "Missing-person case not found."
            }), 404

        result = (
            supabase.table("missing_persons")
            .update(updates)
            .eq("id", person_id)
            .execute()
        )

        if not result.data:
            return jsonify({
                "error": "The case could not be updated."
            }), 500

        return jsonify({
            "message": "Missing-person case updated successfully.",
            "case_code": existing.data[0]["case_code"],
            "updated_fields": sorted(updates.keys()),
        }), 200

    except Exception:
        current_app.logger.exception(
            "Failed to update missing-person case."
        )
        return jsonify({
            "error": "An internal error occurred while updating the case."
        }), 500


# ---------------------------------------------------------
# UPDATE MISSING-PERSON CASE STATUS
# PATCH /api/missing-persons/<person_id>/status
# ---------------------------------------------------------

ALLOWED_CASE_STATUSES = {
    "missing": "Missing",
    "found": "Found",
    "closed": "Closed",
}


@missing_person_bp.patch("/<person_id>/status")
@missing_person_bp.patch("/<person_id>/status/")
@missing_person_bp.put("/<person_id>/status")
@missing_person_bp.put("/<person_id>/status/")
@require_authority(allowed_departments=["POLICE"], allowed_roles=["Inspector", "Constable", "authority"])
def update_missing_person_status(person_id):
    """
    Update the official case status of an existing missing-person case.
    Allowed statuses: Missing, Found, Closed.
    Marking a case as 'Found' requires explicit officer verification confirmation
    (automated AI match inferences alone cannot change case status).
    Audit history limitation: The underlying schema does not currently define a
    case_status_logs audit table, so the change is persisted directly to missing_persons.
    """
    # 1. Validate person UUID
    if not is_valid_uuid(person_id):
        return jsonify({
            "error": "Invalid missing-person ID."
        }), 400

    # 2. Parse request body
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or not data:
        return jsonify({
            "error": "Provide a JSON object containing the new status."
        }), 400

    raw_status = data.get("status")
    if not raw_status or not isinstance(raw_status, str) or not raw_status.strip():
        return jsonify({
            "error": "status is required and must be a non-empty string."
        }), 400

    normalized_status = ALLOWED_CASE_STATUSES.get(raw_status.strip().lower())
    if not normalized_status:
        return jsonify({
            "error": (
                f"Invalid status value: '{raw_status.strip()}'. "
                "Allowed statuses are: Missing, Found, Closed."
            ),
            "allowed_statuses": ["Missing", "Found", "Closed"],
        }), 400

    # 3. Protocol safeguard: 'Found' requires explicit verification confirmation
    if normalized_status == "Found":
        verified_confirmation = data.get("verified_confirmation")
        if verified_confirmation is not True:
            return jsonify({
                "error": (
                    "Marking a missing-person case as 'Found' requires explicit officer "
                    "verification confirmation. Automated AI match scores alone cannot "
                    "be used to confirm identity."
                ),
                "confirmation_required": True,
            }), 400

    supabase = get_supabase_client()

    try:
        # 4. Confirm case exists and read current status
        existing = (
            supabase.table("missing_persons")
            .select("id, case_code, full_name, status")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )
        if not existing.data:
            return jsonify({
                "error": "Missing-person case not found."
            }), 404

        current_case = existing.data[0]
        current_status = current_case.get("status")

        # 5. Guard against redundant updates to the same status
        if current_status == normalized_status:
            return jsonify({
                "error": f"Case is already in '{normalized_status}' status.",
                "current_status": current_status,
                "status": current_status,
            }), 400

        # 6. Apply status update
        update_payload = {"status": normalized_status}
        result = (
            supabase.table("missing_persons")
            .update(update_payload)
            .eq("id", person_id)
            .execute()
        )
        if not result.data:
            return jsonify({
                "error": "The case status could not be updated."
            }), 500

        remarks = data.get("remarks")
        remarks_clean = remarks.strip() if isinstance(remarks, str) and remarks.strip() else None

        current_app.logger.info(
            "Status updated for case %s (%s): %s -> %s",
            current_case.get("case_code"),
            person_id,
            current_status,
            normalized_status,
        )

        return jsonify({
            "message": f"Case status successfully updated to '{normalized_status}'.",
            "person_id": person_id,
            "case_code": current_case.get("case_code"),
            "full_name": current_case.get("full_name"),
            "previous_status": current_status,
            "status": normalized_status,
            "remarks": remarks_clean,
        }), 200

    except Exception:
        current_app.logger.exception(
            "Failed to update status for missing-person case: %s", person_id
        )
        return jsonify({
            "error": "An internal error occurred while updating the case status."
        }), 500