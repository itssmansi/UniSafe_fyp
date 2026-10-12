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


if __name__ == "__main__":
    unittest.main()

