import os
import io
from flask import Blueprint, request, jsonify, current_app
import cv2
import numpy as np
from datetime import datetime
from uuid import UUID
from werkzeug.utils import secure_filename

from database.supabase_client import get_supabase_client
from services.face_recognition import extract_reference_face_from_image


missing_person_bp = Blueprint(
    "missing_persons",
    __name__,
    url_prefix="/api/missing-persons"
)

BUCKET_NAME = "missing-person-images"
ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
EXPECTED_EMBEDDING_SIZE = 512
DEFAULT_MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB


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
def create_missing_person_report():

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
            "status": "Missing"
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
            .select("id, full_name, case_code")
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

        if not case_code:
            return jsonify({
                "error": "Person has no case code"
            }), 500

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


# ---------------------------------------------------------
# DELETE A PHOTO FROM AN EXISTING PERSON
# DELETE /api/missing-persons/<person_id>/photos
# JSON body: {"embedding_id": "<photo embedding UUID>"}
# ---------------------------------------------------------

@missing_person_bp.delete("/<person_id>/photos")
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
            .select("id, full_name, case_code")
            .eq("id", person_id)
            .limit(1)
            .execute()
        )

        if not person_response.data:
            return jsonify({
                "error": "Missing-person record not found"
            }), 404

        person = person_response.data[0]

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