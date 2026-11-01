import io
import os
import unittest
from unittest.mock import MagicMock, patch
from uuid import uuid4
from werkzeug.datastructures import FileStorage

from app import app
from routes.missing_persons import (
    validate_uploaded_image,
    is_valid_uuid,
    BUCKET_NAME,
)


class MockQueryBuilder:
    """Mock helper for chained Supabase/PostgREST queries."""
    def __init__(self, data=None, on_execute=None):
        self._data = data if data is not None else []
        self._on_execute = on_execute

    def select(self, *args, **kwargs):
        return self

    def insert(self, *args, **kwargs):
        return self

    def update(self, *args, **kwargs):
        return self

    def delete(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def execute(self):
        if self._on_execute:
            return self._on_execute()
        res = MagicMock()
        res.data = self._data
        return res


class TestMissingPersonsRoutes(unittest.TestCase):
    def setUp(self):
        self.app = app
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()
        self.valid_person_id = str(uuid4())
        self.valid_embedding_id = str(uuid4())

    def test_is_valid_uuid(self):
        self.assertTrue(is_valid_uuid(str(uuid4())))
        self.assertFalse(is_valid_uuid("not-a-uuid"))
        self.assertFalse(is_valid_uuid(""))
        self.assertFalse(is_valid_uuid(None))
        self.assertFalse(is_valid_uuid(12345))

    # -------------------------------------------------------------
    # 1. UUID & Request Validation Tests
    # -------------------------------------------------------------
    def test_post_photo_malformed_person_id(self):
        response = self.client.post("/api/missing-persons/not-a-uuid/photos")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    def test_delete_photo_malformed_person_id(self):
        response = self.client.delete(
            "/api/missing-persons/not-a-uuid/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    def test_delete_photo_non_json_body(self):
        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            data="not-json",
            content_type="text/plain",
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("JSON object", response.get_json()["error"])

    def test_delete_photo_non_dict_json_body(self):
        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json=["item1", "item2"],
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("JSON object", response.get_json()["error"])

    def test_delete_photo_missing_embedding_id(self):
        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("embedding_id", response.get_json()["error"])

    def test_delete_photo_malformed_embedding_id(self):
        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": "malformed-uuid"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("valid embedding_id UUID", response.get_json()["error"])

    # -------------------------------------------------------------
    # 2. Upload Size Limit Validation
    # -------------------------------------------------------------
    def test_oversized_image_upload_rejected(self):
        # Create an oversized in-memory file (> 10 MB)
        oversized_data = b"0" * (11 * 1024 * 1024)
        stream = io.BytesIO(oversized_data)
        file_storage = FileStorage(
            stream=stream,
            filename="large_photo.jpg",
            content_type="image/jpeg",
        )

        with self.app.test_request_context():
            _, _, _, _, error_resp = validate_uploaded_image(file_storage)
            self.assertIsNotNone(error_resp)
            resp, status_code = error_resp
            self.assertEqual(status_code, 400)
            self.assertIn("exceeds maximum allowed size", resp.get_json()["error"])

    # -------------------------------------------------------------
    # 3. Photo Deletion Consistency & Failure Paths
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_person_not_found(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client
        mock_client.table.return_value = MockQueryBuilder([])

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 404)
        self.assertIn("record not found", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_photo_not_found_for_person(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder([])  # Photo not found
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 404)
        self.assertIn("Photo not found", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_prevent_last_photo_deletion(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # Only 1 photo exists
        photo_record = {
            "id": self.valid_embedding_id,
            "missing_person_id": self.valid_person_id,
            "image_path": "missing_people/MP001/photo_1.jpg",
        }

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder([photo_record])
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 409)
        self.assertIn("Cannot delete the last reference photo", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_storage_failure(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_records = [
            {
                "id": self.valid_embedding_id,
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_1.jpg",
            },
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_2.jpg",
            },
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(photo_records)
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage remove raises exception
        mock_storage = MagicMock()
        mock_storage.remove.side_effect = RuntimeError("Storage network failure")
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not remove photo from Storage", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_db_failure_after_storage_removal(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_records = [
            {
                "id": self.valid_embedding_id,
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_1.jpg",
            },
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_2.jpg",
            },
        ]

        def on_delete_execute():
            raise RuntimeError("Database deadlock on delete")

        call_count = {"embeddings": 0}

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                call_count["embeddings"] += 1
                if call_count["embeddings"] <= 2:
                    # 1: find photo, 2: count check
                    return MockQueryBuilder(photo_records)
                else:
                    # 3: delete call
                    return MockQueryBuilder(on_execute=on_delete_execute)
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage remove succeeds
        mock_storage = MagicMock()
        mock_storage.remove.return_value = [{"name": "missing_people/MP001/photo_1.jpg"}]
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 500)
        self.assertIn("Administrator cleanup is required", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_success(self, mock_get_client):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_records = [
            {
                "id": self.valid_embedding_id,
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_1.jpg",
            },
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "image_path": "missing_people/MP001/photo_2.jpg",
            },
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(photo_records)
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage remove succeeds
        mock_storage = MagicMock()
        mock_storage.remove.return_value = [{"name": "missing_people/MP001/photo_1.jpg"}]
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("deleted successfully", response.get_json()["message"])

    # -------------------------------------------------------------
    # 4. Photo Addition Tests
    # -------------------------------------------------------------
    @patch("routes.missing_persons.validate_uploaded_image")
    @patch("routes.missing_persons.get_supabase_client")
    def test_post_photo_duplicate_filename_rejected(self, mock_get_client, mock_validate):
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        # Mock valid image
        dummy_embedding = [0.1] * 512
        mock_validate.return_value = (
            b"fake_bytes",
            "existing_photo.jpg",
            dummy_embedding,
            0.95,
            None,
        )

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "full_name": "Test Person", "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder([{"id": str(uuid4())}])  # Already exists
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        response = self.client.post(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            data={"missing_person_image": (io.BytesIO(b"abc"), "existing_photo.jpg")},
            content_type="multipart/form-data",
        )
        self.assertEqual(response.status_code, 409)
        self.assertIn("already registered", response.get_json()["error"])

    # -------------------------------------------------------------
    # 5. Case Creation Validation
    # -------------------------------------------------------------
    def test_create_case_invalid_last_seen_date(self):
        response = self.client.post(
            "/api/missing-persons",
            data={
                "full_name": "John Doe",
                "last_seen_date": "not-an-iso-date",
            },
            content_type="multipart/form-data",
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid last_seen_date", response.get_json()["error"])

    # -------------------------------------------------------------
    # 6. PATCH Case Validation & Protected Fields
    # -------------------------------------------------------------
    def test_patch_malformed_person_id(self):
        response = self.client.patch("/api/missing-persons/invalid-id", json={"full_name": "Jane Doe"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    def test_patch_protected_field_rejected(self):
        for protected_field in ("id", "case_code", "status", "citizen_id", "created_at"):
            response = self.client.patch(
                f"/api/missing-persons/{self.valid_person_id}",
                json={protected_field: "hacked"},
            )
            self.assertEqual(response.status_code, 400)
            self.assertIn("Unsupported fields", response.get_json()["error"])

    def test_patch_boolean_coordinates_rejected(self):
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}",
            json={"latitude": True},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("latitude must be a number", response.get_json()["error"])

    # -------------------------------------------------------------
    # 7. Additional Storage Response & Boundary Tests
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_storage_empty_response_success(self, mock_get_client):
        """Storage remove() returns [] when object was already absent in bucket."""
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_records = [
            {"id": self.valid_embedding_id, "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/photo_1.jpg"},
            {"id": str(uuid4()), "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/photo_2.jpg"},
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(photo_records)
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage remove returns [] (object already missing in bucket)
        mock_storage = MagicMock()
        mock_storage.remove.return_value = []
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("deleted successfully", response.get_json()["message"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_delete_photo_storage_error_payload_dict(self, mock_get_client):
        """Storage remove() returns error dictionary payload -> must fail and abort DB delete."""
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_records = [
            {"id": self.valid_embedding_id, "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/photo_1.jpg"},
            {"id": str(uuid4()), "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/photo_2.jpg"},
        ]

        mock_delete_builder = MockQueryBuilder(photo_records)

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return mock_delete_builder
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage returns dict with error
        mock_storage = MagicMock()
        mock_storage.remove.return_value = {"error": "Storage access denied", "statusCode": 403}
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": self.valid_embedding_id},
        )
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not remove photo from Storage", response.get_json()["error"])

    @patch("routes.missing_persons.validate_uploaded_image")
    @patch("routes.missing_persons.get_supabase_client")
    def test_post_photo_storage_conflict_409(self, mock_get_client, mock_validate):
        """Storage upload throws already exists / conflict -> must return 409."""
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        dummy_embedding = [0.1] * 512
        mock_validate.return_value = (
            b"fake_bytes",
            "new_photo.jpg",
            dummy_embedding,
            0.95,
            None,
        )

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "full_name": "Test Person", "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder([])  # Not in DB
            return MockQueryBuilder([])

        mock_client.table.side_effect = table_router

        # Storage upload throws conflict
        mock_storage = MagicMock()
        mock_storage.upload.side_effect = RuntimeError("Resource already exists: 409 conflict")
        mock_client.storage.from_.return_value = mock_storage

        response = self.client.post(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            data={"missing_person_image": (io.BytesIO(b"abc"), "new_photo.jpg")},
            content_type="multipart/form-data",
        )
        self.assertEqual(response.status_code, 409)
        self.assertIn("already exists in storage", response.get_json()["error"])

    # -------------------------------------------------------------
    # 8. Boundary Size Limit & Stream Positioning Tests
    # -------------------------------------------------------------
    @patch("routes.missing_persons.extract_reference_face_from_image")
    def test_image_upload_exact_max_size_accepted(self, mock_extract):
        """Exact max size (10 MB) must pass size validation without being rejected."""
        mock_extract.return_value = ([0.1] * 512, 0.95, 1)

        # 10 MB payload
        exact_max_size = 10 * 1024 * 1024
        stream = io.BytesIO(b"0" * exact_max_size)
        file_storage = FileStorage(
            stream=stream,
            filename="exact_limit.jpg",
            content_type="image/jpeg",
        )

        with self.app.test_request_context():
            # Mock cv2.imdecode to avoid decoding 10MB of synthetic zeros
            with patch("routes.missing_persons.cv2.imdecode") as mock_imdecode:
                mock_imdecode.return_value = MagicMock()
                img_bytes, filename, emb, score, error_resp = validate_uploaded_image(file_storage)
                self.assertIsNone(error_resp)
                self.assertEqual(len(img_bytes), exact_max_size)

    def test_image_upload_max_size_plus_one_rejected(self):
        """Max size + 1 byte must be rejected with HTTP 400."""
        oversized = (10 * 1024 * 1024) + 1
        stream = io.BytesIO(b"0" * oversized)
        file_storage = FileStorage(
            stream=stream,
            filename="plus_one.jpg",
            content_type="image/jpeg",
        )

        with self.app.test_request_context():
            _, _, _, _, error_resp = validate_uploaded_image(file_storage)
            self.assertIsNotNone(error_resp)
            resp, status = error_resp
            self.assertEqual(status, 400)
            self.assertIn("exceeds maximum allowed size", resp.get_json()["error"])

    def test_image_upload_non_seekable_oversized_rejected(self):
        """Non-seekable stream exceeding max limit must be rejected via bounded read chunk."""
        class NonSeekableStream:
            def __init__(self, data):
                self._data = data
                self._pos = 0

            def read(self, n=-1):
                if n == -1:
                    chunk = self._data[self._pos:]
                    self._pos = len(self._data)
                    return chunk
                chunk = self._data[self._pos:self._pos + n]
                self._pos += len(chunk)
                return chunk

            def seek(self, *args, **kwargs):
                raise io.UnsupportedOperation("Stream not seekable")

            def tell(self):
                raise io.UnsupportedOperation("Stream not seekable")

        data = b"0" * ((10 * 1024 * 1024) + 100)
        file_storage = FileStorage(
            stream=NonSeekableStream(data),
            filename="non_seekable.jpg",
            content_type="image/jpeg",
        )

        with self.app.test_request_context():
            _, _, _, _, error_resp = validate_uploaded_image(file_storage)
            self.assertIsNotNone(error_resp)
            resp, status = error_resp
            self.assertEqual(status, 400)
            self.assertIn("exceeds maximum allowed size", resp.get_json()["error"])

    def test_image_upload_seek_raises_value_error_handled(self):
        """Stream whose seek() raises ValueError must gracefully fall back to bounded chunk read."""
        class ValueErrorStream:
            def __init__(self, data):
                self._data = data

            def read(self, n=-1):
                return self._data[:n] if n != -1 else self._data

            def seek(self, *args, **kwargs):
                raise ValueError("I/O operation on closed file")

        file_storage = FileStorage(
            stream=ValueErrorStream(b"0" * ((10 * 1024 * 1024) + 50)),
            filename="value_error.jpg",
            content_type="image/jpeg",
        )

        with self.app.test_request_context():
            _, _, _, _, error_resp = validate_uploaded_image(file_storage)
            self.assertIsNotNone(error_resp)
            resp, status = error_resp
            self.assertEqual(status, 400)

    # -------------------------------------------------------------
    # 9. Concurrency Simulation Test
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    def test_concurrent_delete_last_photo_race_condition(self, mock_get_client):
        """
        Simulate concurrent execution demonstrating why application-level count check
        is vulnerable without a PostgreSQL transaction/RPC locking the rows:
        Case has exactly 2 photos (A and B).
        Request 1 wants to delete A, Request 2 wants to delete B.
        Both query photo count simultaneously and both see count = 2.
        Both pass the count check and both delete, leaving 0 photos.
        """
        mock_client = MagicMock()
        mock_get_client.return_value = mock_client

        photo_a_id = str(uuid4())
        photo_b_id = str(uuid4())

        # In-memory store representing database state
        db_photos = [
            {"id": photo_a_id, "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/a.jpg"},
            {"id": photo_b_id, "missing_person_id": self.valid_person_id, "image_path": "missing_people/MP001/b.jpg"},
        ]

        # Simulating concurrent read: both requests read the initial state of 2 photos
        def concurrent_table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder([{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                # Returns the snapshot of 2 photos to both requests
                return MockQueryBuilder(list(db_photos))
            return MockQueryBuilder([])

        mock_client.table.side_effect = concurrent_table_router
        mock_storage = MagicMock()
        mock_storage.remove.return_value = [{"name": "deleted"}]
        mock_client.storage.from_.return_value = mock_storage

        # Request 1 deletes Photo A
        res1 = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": photo_a_id},
        )
        self.assertEqual(res1.status_code, 200)

        # Request 2 deletes Photo B (under the same snapshot before DB reflects deletion)
        res2 = self.client.delete(
            f"/api/missing-persons/{self.valid_person_id}/photos",
            json={"embedding_id": photo_b_id},
        )
        self.assertEqual(res2.status_code, 200)
        # Demonstrates that both pass when reading concurrently without a database lock!

    # -------------------------------------------------------------
    # 6. GET /api/missing-persons/<person_id>/photos Tests
    # -------------------------------------------------------------
    def test_get_photos_malformed_person_id(self):
        response = self.client.get("/api/missing-persons/not-a-uuid/photos")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_case_not_found(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 404)
        self.assertIn("Missing-person case not found", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_database_failure_verifying_case(self, mock_get_supabase):
        def fail_case():
            raise RuntimeError("Database error during verification")

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(on_execute=fail_case)
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not verify missing-person case", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_database_failure_querying_photos(self, mock_get_supabase):
        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                def fail_embeddings():
                    raise RuntimeError("Database error on embeddings")
                return MockQueryBuilder(on_execute=fail_embeddings)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query reference photos", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_empty_photo_list(self, mock_get_supabase):
        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=[])
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["person_id"], self.valid_person_id)
        self.assertEqual(res_json["case_code"], "MP001")
        self.assertEqual(res_json["photo_count"], 0)
        self.assertEqual(res_json["photos"], [])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_successful_retrieval(self, mock_get_supabase):
        photo_id_1 = str(uuid4())
        photo_id_2 = str(uuid4())

        photo_records = [
            {
                "id": photo_id_1,
                "image_path": "missing_people/MP001/photo_1.jpg",
                "det_score": 0.98,
                "created_at": "2026-10-01T12:00:00Z",
            },
            {
                "id": photo_id_2,
                "image_path": "missing_people/MP001/photo_2.jpg",
                "det_score": 0.95,
                "created_at": "2026-10-01T12:05:00Z",
            },
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=photo_records)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_storage = MagicMock()
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/photo.jpg",
            "signedUrl": "https://storage.supabase.com/signed/photo.jpg",
        }
        mock_client.storage.from_.return_value = mock_storage
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["person_id"], self.valid_person_id)
        self.assertEqual(res_json["case_code"], "MP001")
        self.assertEqual(res_json["photo_count"], 2)
        self.assertEqual(len(res_json["photos"]), 2)

        first_photo = res_json["photos"][0]
        self.assertEqual(first_photo["embedding_id"], photo_id_1)
        self.assertEqual(first_photo["image_path"], "missing_people/MP001/photo_1.jpg")
        self.assertEqual(first_photo["signed_url"], "https://storage.supabase.com/signed/photo.jpg")
        self.assertEqual(first_photo["detection_score"], 0.98)
        self.assertEqual(first_photo["created_at"], "2026-10-01T12:00:00Z")

        # Verify that raw embedding vectors are NEVER leaked
        for photo in res_json["photos"]:
            self.assertNotIn("embedding", photo)
            self.assertNotIn("embeddings", photo)

        # Storage was called with BUCKET_NAME
        mock_client.storage.from_.assert_called_with("missing-person-images")
        self.assertEqual(mock_storage.create_signed_url.call_count, 2)

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_successful_retrieval_string_signed_url(self, mock_get_supabase):
        photo_records = [
            {
                "id": str(uuid4()),
                "image_path": "missing_people/MP001/photo_1.jpg",
                "det_score": 0.99,
                "created_at": "2026-10-01T12:00:00Z",
            }
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=photo_records)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_storage = MagicMock()
        # SDK returns direct string
        mock_storage.create_signed_url.return_value = "https://storage.supabase.com/direct_string.jpg"
        mock_client.storage.from_.return_value = mock_storage
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["photos"][0]["signed_url"], "https://storage.supabase.com/direct_string.jpg")

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_photos_signed_url_failure(self, mock_get_supabase):
        photo_records = [
            {
                "id": str(uuid4()),
                "image_path": "missing_people/MP001/photo_1.jpg",
                "det_score": 0.99,
                "created_at": "2026-10-01T12:00:00Z",
            }
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[{"id": self.valid_person_id, "case_code": "MP001"}])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=photo_records)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_storage = MagicMock()
        mock_storage.create_signed_url.side_effect = RuntimeError("Storage signature failure")
        mock_client.storage.from_.return_value = mock_storage
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}/photos")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not generate signed photo URLs", response.get_json()["error"])

    # -------------------------------------------------------------
    # 7. GET /api/missing-persons/<person_id> Tests
    # -------------------------------------------------------------
    def test_get_case_malformed_person_id(self):
        response = self.client.get("/api/missing-persons/invalid-uuid")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_not_found(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 404)
        self.assertIn("Missing-person case not found", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_database_failure_fetching_case(self, mock_get_supabase):
        def fail_case():
            raise RuntimeError("Database connection timed out")

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(on_execute=fail_case)
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not fetch missing-person case", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_database_failure_querying_photos(self, mock_get_supabase):
        case_record = {
            "id": self.valid_person_id,
            "case_code": "MP001",
            "full_name": "Jane Doe",
            "age": 30,
            "gender": "Female",
            "status": "Missing",
        }

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[case_record])
            elif table_name == "missing_person_embeddings":
                def fail_embeddings():
                    raise RuntimeError("Database error on embeddings")
                return MockQueryBuilder(on_execute=fail_embeddings)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query reference photos", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_signed_url_failure(self, mock_get_supabase):
        case_record = {
            "id": self.valid_person_id,
            "case_code": "MP001",
            "full_name": "Jane Doe",
            "status": "Missing",
        }
        photo_records = [
            {
                "id": str(uuid4()),
                "image_path": "missing_people/MP001/photo_1.jpg",
                "det_score": 0.98,
                "created_at": "2026-10-01T12:00:00Z",
            }
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[case_record])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=photo_records)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_storage = MagicMock()
        mock_storage.create_signed_url.side_effect = RuntimeError("Storage signing failed")
        mock_client.storage.from_.return_value = mock_storage
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not generate signed photo URLs", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_successful_retrieval_with_photos(self, mock_get_supabase):
        case_record = {
            "id": self.valid_person_id,
            "case_code": "MP001",
            "full_name": "John Doe",
            "age": 28,
            "gender": "Male",
            "last_seen_date": "2026-10-01T10:00:00Z",
            "latitude": 12.9716,
            "longitude": 77.5946,
            "description": "Last seen near city center station",
            "status": "Missing",
            "created_at": "2026-10-01T08:00:00Z",
        }

        photo_id_1 = str(uuid4())
        photo_id_2 = str(uuid4())
        photo_records = [
            {
                "id": photo_id_1,
                "image_path": "missing_people/MP001/photo_1.jpg",
                "det_score": 0.98,
                "created_at": "2026-10-01T08:05:00Z",
            },
            {
                "id": photo_id_2,
                "image_path": "missing_people/MP001/photo_2.jpg",
                "det_score": 0.96,
                "created_at": "2026-10-01T08:10:00Z",
            },
        ]

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[case_record])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=photo_records)
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_storage = MagicMock()
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/photo.jpg",
        }
        mock_client.storage.from_.return_value = mock_storage
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["id"], self.valid_person_id)
        self.assertEqual(res_json["case_code"], "MP001")
        self.assertEqual(res_json["full_name"], "John Doe")
        self.assertEqual(res_json["age"], 28)
        self.assertEqual(res_json["gender"], "Male")
        self.assertEqual(res_json["last_seen_date"], "2026-10-01T10:00:00Z")
        self.assertEqual(res_json["latitude"], 12.9716)
        self.assertEqual(res_json["longitude"], 77.5946)
        self.assertEqual(res_json["description"], "Last seen near city center station")
        self.assertEqual(res_json["status"], "Missing")
        self.assertEqual(res_json["created_at"], "2026-10-01T08:00:00Z")
        self.assertEqual(res_json["photo_count"], 2)
        self.assertEqual(len(res_json["photos"]), 2)

        # Verify photo details
        first_photo = res_json["photos"][0]
        self.assertEqual(first_photo["embedding_id"], photo_id_1)
        self.assertEqual(first_photo["image_path"], "missing_people/MP001/photo_1.jpg")
        self.assertEqual(first_photo["signed_url"], "https://storage.supabase.com/signed/photo.jpg")
        self.assertEqual(first_photo["detection_score"], 0.98)
        self.assertEqual(first_photo["created_at"], "2026-10-01T08:05:00Z")

        # Verify no raw biometric embeddings leaked
        self.assertNotIn("embedding", res_json)
        self.assertNotIn("embeddings", res_json)
        self.assertNotIn("face_data", res_json)
        for photo in res_json["photos"]:
            self.assertNotIn("embedding", photo)
            self.assertNotIn("embeddings", photo)

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_successful_retrieval_empty_photos(self, mock_get_supabase):
        case_record = {
            "id": self.valid_person_id,
            "case_code": "MP002",
            "full_name": "Alex Smith",
            "status": "Missing",
        }

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[case_record])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=[])
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["id"], self.valid_person_id)
        self.assertEqual(res_json["case_code"], "MP002")
        self.assertEqual(res_json["photo_count"], 0)
        self.assertEqual(res_json["photos"], [])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_case_sanitizes_internal_biometric_fields(self, mock_get_supabase):
        case_record_with_biometrics = {
            "id": self.valid_person_id,
            "case_code": "MP003",
            "full_name": "Test Person",
            "status": "Missing",
            "face_data": [{"embedding": [0.1] * 512}],
            "embedding": [0.2] * 512,
            "embeddings": [[0.3] * 512],
        }

        def table_router(table_name):
            if table_name == "missing_persons":
                return MockQueryBuilder(data=[case_record_with_biometrics])
            elif table_name == "missing_person_embeddings":
                return MockQueryBuilder(data=[])
            return MockQueryBuilder()

        mock_client = MagicMock()
        mock_client.table.side_effect = table_router
        mock_get_supabase.return_value = mock_client

        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertNotIn("embedding", res_json)
        self.assertNotIn("embeddings", res_json)
        self.assertNotIn("face_data", res_json)

    # -------------------------------------------------------------
    # 8. GET /api/missing-persons List Tests
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_successful_retrieval(self, mock_get_supabase):
        cases = [
            {
                "id": self.valid_person_id,
                "case_code": "MP001",
                "full_name": "Alice Green",
                "age": 22,
                "gender": "Female",
                "last_seen_date": "2026-10-01T10:00:00Z",
                "latitude": 12.9716,
                "longitude": 77.5946,
                "description": "Last seen near park",
                "status": "Missing",
                "created_at": "2026-10-01T08:00:00Z",
            },
            {
                "id": str(uuid4()),
                "case_code": "MP002",
                "full_name": "Bob Brown",
                "age": 45,
                "gender": "Male",
                "last_seen_date": "2026-10-02T15:00:00Z",
                "latitude": 13.0827,
                "longitude": 80.2707,
                "description": "Last seen near station",
                "status": "Missing",
                "created_at": "2026-10-02T09:00:00Z",
            },
        ]

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=cases)
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 2)
        self.assertEqual(res_json["total"], 2)
        self.assertEqual(len(res_json["missing_persons"]), 2)

        first_case = res_json["missing_persons"][0]
        self.assertEqual(first_case["id"], self.valid_person_id)
        self.assertEqual(first_case["case_code"], "MP001")
        self.assertEqual(first_case["full_name"], "Alice Green")
        self.assertEqual(first_case["age"], 22)
        self.assertEqual(first_case["gender"], "Female")
        self.assertEqual(first_case["status"], "Missing")

        # Verify biometric vectors never leaked
        for c in res_json["missing_persons"]:
            self.assertNotIn("embedding", c)
            self.assertNotIn("embeddings", c)
            self.assertNotIn("face_data", c)

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_empty_result(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 0)
        self.assertEqual(res_json["total"], 0)
        self.assertEqual(res_json["missing_persons"], [])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_status_filter_applied(self, mock_get_supabase):
        filtered_cases = [
            {
                "id": self.valid_person_id,
                "case_code": "MP001",
                "full_name": "Alice Green",
                "status": "Missing",
            }
        ]

        mock_client = MagicMock()
        mock_builder = MockQueryBuilder(data=filtered_cases)
        mock_client.table.return_value = mock_builder
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons?status=Missing")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 1)
        self.assertEqual(res_json["missing_persons"][0]["status"], "Missing")

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_status_filter_all(self, mock_get_supabase):
        cases = [
            {"id": str(uuid4()), "case_code": "MP001", "status": "Missing"},
            {"id": str(uuid4()), "case_code": "MP002", "status": "Found"},
        ]

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=cases)
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons?status=all")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 2)

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_database_failure(self, mock_get_supabase):
        def fail_query():
            raise RuntimeError("Database unavailable")

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(on_execute=fail_query)
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query missing-person cases", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_sanitizes_internal_biometric_vectors(self, mock_get_supabase):
        dirty_records = [
            {
                "id": self.valid_person_id,
                "case_code": "MP001",
                "full_name": "Test Person",
                "status": "Missing",
                "face_data": [{"embedding": [0.1] * 512}],
                "embedding": [0.2] * 512,
                "embeddings": [[0.3] * 512],
            }
        ]

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=dirty_records)
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        first = res_json["missing_persons"][0]
        self.assertNotIn("embedding", first)
        self.assertNotIn("embeddings", first)
        self.assertNotIn("face_data", first)

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_invalid_limit(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_get_supabase.return_value = mock_client
        response = self.client.get("/api/missing-persons?limit=not-a-number")
        self.assertEqual(response.status_code, 400)
        self.assertIn("limit must be a positive integer", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_get_cases_trailing_slash(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/missing-persons/")
        self.assertEqual(response.status_code, 200)

    # -------------------------------------------------------------
    # 13. Case Status Update Tests (PATCH /<person_id>/status)
    # -------------------------------------------------------------
    def test_update_status_malformed_id(self):
        response = self.client.patch(
            "/api/missing-persons/not-a-valid-uuid/status",
            json={"status": "Found", "verified_confirmation": True},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid missing-person ID", response.get_json()["error"])

    def test_update_status_empty_body(self):
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Provide a JSON object", response.get_json()["error"])

    def test_update_status_missing_status_field(self):
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"remarks": "Found someone"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("status is required", response.get_json()["error"])

    def test_update_status_invalid_value(self):
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Escaped"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid status value", response.get_json()["error"])

    def test_update_status_to_found_without_confirmation(self):
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Found"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("requires explicit officer verification confirmation", response.get_json()["error"])
        self.assertTrue(response.get_json().get("confirmation_required"))

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_not_found(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_get_supabase.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Closed"},
        )
        self.assertEqual(response.status_code, 404)
        self.assertIn("Missing-person case not found", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_same_status_rejected(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(
            data=[{"id": self.valid_person_id, "case_code": "MP001", "status": "Missing"}]
        )
        mock_get_supabase.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Missing"},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("already in 'Missing' status", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_to_found_success(self, mock_get_supabase):
        mock_client = MagicMock()
        # Mock initial query (Missing) then update returns Found
        mock_client.table.return_value = MockQueryBuilder(
            data=[{"id": self.valid_person_id, "case_code": "MP001", "full_name": "John Doe", "status": "Missing"}]
        )
        mock_get_supabase.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={
                "status": "Found",
                "verified_confirmation": True,
                "remarks": "Located at hospital and verified by Constable Patil",
            },
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["status"], "Found")
        self.assertEqual(res_json["previous_status"], "Missing")
        self.assertEqual(res_json["person_id"], self.valid_person_id)
        self.assertEqual(res_json["remarks"], "Located at hospital and verified by Constable Patil")
        self.assertIn("successfully updated", res_json["message"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_to_closed_success(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(
            data=[{"id": self.valid_person_id, "case_code": "MP001", "full_name": "John Doe", "status": "Missing"}]
        )
        mock_get_supabase.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Closed"},
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["status"], "Closed")
        self.assertEqual(res_json["previous_status"], "Missing")

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_database_failure(self, mock_get_supabase):
        def fail_query():
            raise RuntimeError("Database connection timed out")

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(on_execute=fail_query)
        mock_get_supabase.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Closed"},
        )
        self.assertEqual(response.status_code, 500)
        self.assertIn("internal error occurred", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    def test_update_status_trailing_slash_and_put(self, mock_get_supabase):
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(
            data=[{"id": self.valid_person_id, "case_code": "MP001", "full_name": "John Doe", "status": "Missing"}]
        )
        mock_get_supabase.return_value = mock_client

        response = self.client.put(
            f"/api/missing-persons/{self.valid_person_id}/status/",
            json={"status": "Closed"},
        )
        self.assertEqual(response.status_code, 200)


if __name__ == "__main__":
    unittest.main()



