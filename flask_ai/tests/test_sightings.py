import io
import unittest
from unittest.mock import MagicMock, patch
from uuid import uuid4
import cv2
import numpy as np

from app import app
from routes.sightings import BUCKET_NAME


def make_dummy_jpeg():
    """Generates valid minimal JPEG image bytes."""
    dummy_img = np.zeros((20, 20, 3), dtype=np.uint8)
    _, encoded = cv2.imencode(".jpg", dummy_img)
    return encoded.tobytes()


def make_unit_vector(dim=512, index=0):
    """Generates normalized 512-D unit vector."""
    vec = np.zeros(dim, dtype=np.float32)
    vec[index % dim] = 1.0
    return vec.tolist()


def make_vector_with_similarity(base_vec, similarity, dim=512):
    """Creates a normalized unit vector with exact cosine similarity to base_vec."""
    base = np.asarray(base_vec, dtype=np.float32)
    base = base / np.linalg.norm(base)
    ortho = np.zeros(dim, dtype=np.float32)
    idx = 1 if abs(base[1]) < 0.9 else 2
    ortho[idx] = 1.0
    ortho = ortho - np.dot(ortho, base) * base
    ortho = ortho / np.linalg.norm(ortho)
    s = float(similarity)
    c = np.sqrt(max(0.0, 1.0 - s * s))
    res = s * base + c * ortho
    return (res / np.linalg.norm(res)).astype(np.float32).tolist()


class MockTableQueryBuilder:
    """Mock query builder supporting chained select, insert, eq, in_, and limit."""
    def __init__(self, data=None, on_execute=None):
        self._data = data if data is not None else []
        self._on_execute = on_execute
        self.inserted_records = []

    def select(self, *args, **kwargs):
        return self

    def update(self, data, *args, **kwargs):
        self.updated_data = data
        return self

    def insert(self, data, *args, **kwargs):
        self.inserted_records.append(data)
        return self

    def eq(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def execute(self):
        if self._on_execute:
            return self._on_execute()
        res = MagicMock()
        if hasattr(self, "updated_data") and self.updated_data and not self._data:
            rec = dict(self.updated_data)
            if "id" not in rec:
                rec["id"] = str(uuid4())
            res.data = [rec]
        elif self.inserted_records and not self._data:
            rec = dict(self.inserted_records[-1])
            if "id" not in rec:
                rec["id"] = str(uuid4())
            res.data = [rec]
        else:
            res.data = self._data
        return res


class TestSightingsRoutes(unittest.TestCase):
    def setUp(self):
        self.app = app
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

        self.valid_person_id = str(uuid4())
        self.valid_person_id_2 = str(uuid4())
        self.base_emb = make_unit_vector(index=0)
        self.base_emb_2 = make_unit_vector(index=1)

    def _setup_mock_supabase(
        self,
        active_missing_data=None,
        embeddings_data=None,
        insert_on_execute=None,
        fetch_on_execute=None,
        sightings_data=None,
    ):
        mock_client = MagicMock()

        # Storage mock
        mock_storage = MagicMock()
        mock_storage.upload.return_value = {"Key": "sightings/mock.jpg"}
        mock_storage.remove.return_value = [{"name": "sightings/mock.jpg"}]
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/mock.jpg"
        }
        mock_client.storage.from_.return_value = mock_storage

        # Tables mock
        def table_router(table_name):
            if table_name == "missing_persons":
                return MockTableQueryBuilder(
                    data=active_missing_data if active_missing_data is not None else [{"id": self.valid_person_id}],
                    on_execute=fetch_on_execute,
                )
            elif table_name == "missing_person_embeddings":
                return MockTableQueryBuilder(
                    data=embeddings_data if embeddings_data is not None else [
                        {"missing_person_id": self.valid_person_id, "embedding": make_vector_with_similarity(self.base_emb, 0.82)}
                    ]
                )
            elif table_name == "missing_person_sightings":
                return MockTableQueryBuilder(
                    data=sightings_data,
                    on_execute=insert_on_execute,
                )
            return MockTableQueryBuilder()

        mock_client.table.side_effect = table_router
        return mock_client, mock_storage

    # -------------------------------------------------------------
    # 1. Success Cases
    # -------------------------------------------------------------
    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_success_strong_match(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.98,
        }]

        ref_emb = make_vector_with_similarity(self.base_emb, 0.82)
        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[{"id": self.valid_person_id}],
            embeddings_data=[{"missing_person_id": self.valid_person_id, "embedding": ref_emb}],
        )
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting_photo.jpg", "image/jpeg"),
            "latitude": "12.9716",
            "longitude": "77.5946",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)


    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        self.assertEqual(res_json["message"], "Sighting submitted successfully")
        self.assertIsNotNone(res_json["sighting_id"])
        self.assertEqual(res_json["detected_faces"], 1)
        self.assertEqual(res_json["matched_person_id"], self.valid_person_id)
        self.assertIsNotNone(res_json["top_match"])
        self.assertEqual(res_json["top_match"]["match_category"], "match")
        self.assertTrue(res_json["image_url"].startswith("sightings/"))

        # Verify storage upload
        mock_storage.upload.assert_called_once()

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_multiple_faces_multiple_candidates(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [
            {"face_index": 0, "embedding": self.base_emb, "bbox": [10.0, 10.0, 50.0, 50.0], "det_score": 0.95},
            {"face_index": 1, "embedding": self.base_emb_2, "bbox": [60.0, 60.0, 100.0, 100.0], "det_score": 0.92},
        ]

        p1_emb = make_vector_with_similarity(self.base_emb, 0.85)
        p2_emb = make_vector_with_similarity(self.base_emb_2, 0.75)

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[{"id": self.valid_person_id}, {"id": self.valid_person_id_2}],
            embeddings_data=[
                {"missing_person_id": self.valid_person_id, "embedding": p1_emb},
                {"missing_person_id": self.valid_person_id_2, "embedding": p2_emb},
            ],
        )
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "group_photo.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)


    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        self.assertEqual(res_json["detected_faces"], 2)
        # Person 1 has highest match score (0.85)
        self.assertEqual(res_json["matched_person_id"], self.valid_person_id)
        # ai_matches should have 4 evaluations (2 faces x 2 candidates)
        self.assertEqual(len(res_json["ai_matches"]), 4)

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_no_strong_match_sets_person_id_null(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        # Potential match (0.42 < 0.50 threshold)
        ref_emb = make_vector_with_similarity(self.base_emb, 0.42)
        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[{"id": self.valid_person_id}],
            embeddings_data=[{"missing_person_id": self.valid_person_id, "embedding": ref_emb}],
        )
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)


    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

        res_json = response.get_json()
        # Non-qualifying match must leave matched_person_id None
        self.assertIsNone(res_json["matched_person_id"])
        self.assertIsNone(res_json["top_match"])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_no_active_missing_persons(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[],
            embeddings_data=[],
        )
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)


    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])
        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])
        res_json = response.get_json()
        self.assertIsNone(res_json["matched_person_id"])
        self.assertEqual(res_json["ai_matches"], [])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_client_supplied_citizen_id_ignored(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        inserted_records = []
        def capture_insert():
            res = MagicMock()
            rec = {"id": str(uuid4()), "citizen_id": None}
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_id": str(uuid4()),  # Client attempts to spoof citizen_id
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)


    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

    # -------------------------------------------------------------
    # 2. Validation Failures
    # -------------------------------------------------------------
    def test_post_sighting_missing_image(self):
        response = self.client.post("/api/sightings", data={}, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("A sighting photo is required", response.get_json()["error"])

    def test_post_sighting_empty_filename(self):
        data = {"sighting_image": (io.BytesIO(b"data"), "")}
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("A sighting photo is required", response.get_json()["error"])

    def test_post_sighting_invalid_extension(self):
        data = {"sighting_image": (io.BytesIO(b"fake data"), "sighting.gif")}
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Image must be JPG, JPEG, PNG, or WEBP", response.get_json()["error"])

    def test_post_sighting_empty_file_bytes(self):
        data = {"sighting_image": (io.BytesIO(b""), "sighting.jpg")}
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Uploaded image is empty", response.get_json()["error"])

    def test_post_sighting_oversized_file(self):
        large_bytes = b"0" * (11 * 1024 * 1024)
        data = {"sighting_image": (io.BytesIO(large_bytes), "large.jpg")}
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("exceeds maximum allowed size", response.get_json()["error"])

    def test_post_sighting_corrupted_image_bytes(self):
        data = {"sighting_image": (io.BytesIO(b"not an image"), "corrupt.jpg")}
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Uploaded file is not a valid image", response.get_json()["error"])

    # -------------------------------------------------------------
    # 3. Coordinate Validation Failures
    # -------------------------------------------------------------
    def test_post_sighting_invalid_latitude_non_numeric(self):
        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "latitude": "abc",
        }
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("latitude must be a number", response.get_json()["error"])

    def test_post_sighting_latitude_out_of_bounds(self):
        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "latitude": "95.0",
        }
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("latitude must be between -90 and 90", response.get_json()["error"])

    def test_post_sighting_longitude_out_of_bounds(self):
        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "longitude": "190.0",
        }
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        self.assertIn("longitude must be between -180 and 180", response.get_json()["error"])

    # -------------------------------------------------------------
    # 4. Face Detection: 0 Faces Returns HTTP 422
    # -------------------------------------------------------------
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_no_faces_detected_returns_422(self, mock_extract):
        mock_extract.return_value = []

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "noface.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 422)
        res_json = response.get_json()
        self.assertEqual(res_json["detected_faces"], 0)
        self.assertIn("No faces detected", res_json["error"])

    # -------------------------------------------------------------
    # 5. Storage Upload and Database Failure & Cleanup
    # -------------------------------------------------------------
    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_storage_upload_failure(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0, "embedding": self.base_emb, "bbox": [10.0, 10.0, 50.0, 50.0], "det_score": 0.95
        }]

        mock_supabase, mock_storage = self._setup_mock_supabase()
        mock_storage.upload.side_effect = RuntimeError("Storage network failure")
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not upload sighting photo to storage", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_database_insert_failure_triggers_storage_cleanup(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0, "embedding": self.base_emb, "bbox": [10.0, 10.0, 50.0, 50.0], "det_score": 0.95
        }]

        def fail_insert():
            raise RuntimeError("Database connection lost")

        mock_supabase, mock_storage = self._setup_mock_supabase(insert_on_execute=fail_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not record sighting in database", response.get_json()["error"])

        # Storage cleanup must be called with the uploaded object path
        mock_storage.remove.assert_called_once()
        remove_args = mock_storage.remove.call_args[0][0]
        self.assertTrue(remove_args[0].startswith("sightings/"))

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_database_insert_failure_with_failed_cleanup(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0, "embedding": self.base_emb, "bbox": [10.0, 10.0, 50.0, 50.0], "det_score": 0.95
        }]

        def fail_insert():
            raise RuntimeError("Database error")

        mock_supabase, mock_storage = self._setup_mock_supabase(insert_on_execute=fail_insert)
        mock_storage.remove.side_effect = RuntimeError("Storage remove error")
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        # Should still cleanly return HTTP 500 without crashing
        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not record sighting in database", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_database_fetch_active_cases_failure(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0, "embedding": self.base_emb, "bbox": [10.0, 10.0, 50.0, 50.0], "det_score": 0.95
        }]

        def fail_fetch():
            raise RuntimeError("DB read error")

        mock_supabase, mock_storage = self._setup_mock_supabase(fetch_on_execute=fail_fetch)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {"sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg")}

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not fetch reference profiles from database", response.get_json()["error"])
        # Storage upload should NOT have been called
        mock_storage.upload.assert_not_called()

    # -------------------------------------------------------------
    # 6. GET /api/sightings Tests
    # -------------------------------------------------------------
    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_success(self, mock_get_supabase):
        sighting_id_1 = str(uuid4())
        sighting_id_2 = str(uuid4())
        mock_sightings = [
            {
                "id": sighting_id_1,
                "missing_person_id": self.valid_person_id,
                "latitude": 12.9716,
                "longitude": 77.5946,
                "image_url": "sightings/sighting_1.jpg",
                "is_verified": False,
                "created_at": "2026-10-01T12:00:00Z",
            },
            {
                "id": sighting_id_2,
                "missing_person_id": None,
                "latitude": 13.0827,
                "longitude": 80.2707,
                "image_url": "sightings/sighting_2.jpg",
                "is_verified": True,
                "created_at": "2026-10-02T14:30:00Z",
            },
        ]

        mock_supabase, _ = self._setup_mock_supabase(sightings_data=mock_sightings)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 2)
        self.assertEqual(res_json["total"], 2)
        self.assertEqual(len(res_json["sightings"]), 2)

        first = res_json["sightings"][0]
        self.assertEqual(first["id"], sighting_id_1)
        self.assertEqual(first["missing_person_id"], self.valid_person_id)
        self.assertEqual(first["latitude"], 12.9716)
        self.assertEqual(first["longitude"], 77.5946)
        self.assertEqual(first["image_url"], "sightings/sighting_1.jpg")
        self.assertEqual(first["image_path"], "sightings/sighting_1.jpg")
        self.assertFalse(first["is_verified"])
        self.assertEqual(first["created_at"], "2026-10-01T12:00:00Z")

        # Zero biometric vector leakage
        for s in res_json["sightings"]:
            self.assertNotIn("embedding", s)
            self.assertNotIn("embeddings", s)
            self.assertNotIn("face_data", s)

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_empty_result(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 0)
        self.assertEqual(res_json["total"], 0)
        self.assertEqual(res_json["sightings"], [])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_filtering_verified_true(self, mock_get_supabase):
        mock_sightings = [
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "is_verified": True,
                "image_url": "sightings/verified.jpg",
                "created_at": "2026-10-01T12:00:00Z",
            }
        ]

        mock_supabase, _ = self._setup_mock_supabase(sightings_data=mock_sightings)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?is_verified=true")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 1)
        self.assertTrue(res_json["sightings"][0]["is_verified"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_filtering_verified_false(self, mock_get_supabase):
        mock_sightings = [
            {
                "id": str(uuid4()),
                "missing_person_id": None,
                "is_verified": False,
                "image_url": "sightings/unverified.jpg",
                "created_at": "2026-10-01T12:00:00Z",
            }
        ]

        mock_supabase, _ = self._setup_mock_supabase(sightings_data=mock_sightings)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?is_verified=false")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 1)
        self.assertFalse(res_json["sightings"][0]["is_verified"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_filtering_all(self, mock_get_supabase):
        mock_sightings = [
            {"id": str(uuid4()), "is_verified": True},
            {"id": str(uuid4()), "is_verified": False},
        ]

        mock_supabase, _ = self._setup_mock_supabase(sightings_data=mock_sightings)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?is_verified=all")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["count"], 2)

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_filtering_invalid(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase()
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?is_verified=not-a-boolean")
        self.assertEqual(response.status_code, 400)
        self.assertIn("is_verified must be 'true', 'false', or 'all'", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_invalid_limit(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase()
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?limit=xyz")
        self.assertEqual(response.status_code, 400)
        self.assertIn("limit must be a positive integer", response.get_json()["error"])

        response_zero = self.client.get("/api/sightings?limit=0")
        self.assertEqual(response_zero.status_code, 400)
        self.assertIn("limit must be a positive integer", response_zero.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_valid_limit(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings?limit=10")
        self.assertEqual(response.status_code, 200)

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_biometric_data_exclusion(self, mock_get_supabase):
        dirty_sighting = [
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "image_url": "sightings/dirty.jpg",
                "is_verified": False,
                "face_data": [{"embedding": [0.1] * 512, "bbox": [0, 0, 10, 10]}],
                "embedding": [0.5] * 512,
                "embeddings": [[0.5] * 512],
            }
        ]

        mock_supabase, _ = self._setup_mock_supabase(sightings_data=dirty_sighting)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        item = res_json["sightings"][0]
        self.assertNotIn("face_data", item)
        self.assertNotIn("embedding", item)
        self.assertNotIn("embeddings", item)

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_database_failure(self, mock_get_supabase):
        def fail_query():
            raise RuntimeError("DB connection timeout")

        mock_client = MagicMock()
        mock_client.table.return_value = MockTableQueryBuilder(on_execute=fail_query)
        mock_get_supabase.return_value = mock_client

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query sightings", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_trailing_slash(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings/")
        self.assertEqual(response.status_code, 200)

    # -------------------------------------------------------------
    # 7. GET /api/sightings/<sighting_id> Detail Tests
    # -------------------------------------------------------------
    def test_get_sighting_detail_invalid_uuid(self):
        response = self.client.get("/api/sightings/not-a-valid-uuid")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid sighting ID", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_not_found(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        sighting_id = str(uuid4())
        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 404)
        self.assertIn("Sighting not found", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_database_failure(self, mock_get_supabase):
        def fail_query():
            raise RuntimeError("Database connection lost")

        mock_client = MagicMock()
        mock_client.table.return_value = MockTableQueryBuilder(on_execute=fail_query)
        mock_get_supabase.return_value = mock_client

        sighting_id = str(uuid4())
        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query sighting", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_success(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": 12.9716,
            "longitude": 77.5946,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "ai_matches": [
                {
                    "face_index": 0,
                    "missing_person_id": self.valid_person_id,
                    "similarity_score": 0.85,
                    "match_category": "match",
                    "status": "match",
                }
            ],
        }

        mock_supabase, mock_storage = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/sightings/sighting_sample.jpg",
        }
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["id"], sighting_id)
        self.assertEqual(res_json["missing_person_id"], self.valid_person_id)
        self.assertIsNone(res_json["citizen_id"])
        self.assertEqual(res_json["latitude"], 12.9716)
        self.assertEqual(res_json["longitude"], 77.5946)
        self.assertEqual(res_json["image_url"], "sightings/sighting_sample.jpg")
        self.assertEqual(res_json["image_path"], "sightings/sighting_sample.jpg")
        self.assertEqual(
            res_json["signed_image_url"],
            "https://storage.supabase.com/signed/sightings/sighting_sample.jpg",
        )
        self.assertFalse(res_json["is_verified"])
        self.assertEqual(res_json["created_at"], "2026-10-01T12:00:00Z")
        self.assertEqual(len(res_json["ai_matches"]), 1)
        self.assertEqual(res_json["ai_matches"][0]["similarity_score"], 0.85)

        # Confirm bucket and path used in create_signed_url
        mock_supabase.storage.from_.assert_called_with("missing-person-images")
        mock_storage.create_signed_url.assert_called_once_with(
            "sightings/sighting_sample.jpg",
            expires_in=3600,
        )

        # Ensure no biometric vectors leaked
        self.assertNotIn("face_data", res_json)
        self.assertNotIn("embedding", res_json)
        self.assertNotIn("embeddings", res_json)

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_signing_failure(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": None,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
        }

        mock_supabase, mock_storage = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_storage.create_signed_url.side_effect = RuntimeError("Storage signing failed")
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not generate signed image URL", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_biometric_data_exclusion(self, mock_get_supabase):
        sighting_id = str(uuid4())
        dirty_sighting = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "image_url": "sightings/dirty.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "face_data": [{"embedding": [0.1] * 512, "bbox": [10, 10, 50, 50]}],
            "embedding": [0.2] * 512,
            "embeddings": [[0.3] * 512],
            "ai_matches": [
                {
                    "face_index": 0,
                    "missing_person_id": self.valid_person_id,
                    "similarity_score": 0.90,
                    "embedding": [0.4] * 512,
                }
            ],
        }

        mock_supabase, mock_storage = self._setup_mock_supabase(sightings_data=[dirty_sighting])
        mock_storage.create_signed_url.return_value = "https://storage.supabase.com/signed/dirty.jpg"
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertNotIn("face_data", res_json)
        self.assertNotIn("embedding", res_json)
        self.assertNotIn("embeddings", res_json)
        # In ai_matches
        self.assertNotIn("embedding", res_json["ai_matches"][0])

    # -------------------------------------------------------------
    # 8. POST /api/sightings/<sighting_id>/match Rerun Face Matching Tests
    # -------------------------------------------------------------
    def test_post_sighting_match_invalid_uuid(self):
        response = self.client.post("/api/sightings/invalid-uuid/match")
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid sighting ID", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_not_found(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        sighting_id = str(uuid4())
        response = self.client.post(f"/api/sightings/{sighting_id}/match")
        self.assertEqual(response.status_code, 404)
        self.assertIn("Sighting not found", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_success_strong_match(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": None,
            "citizen_id": None,
            "latitude": 12.9716,
            "longitude": 77.5946,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "face_data": [
                {
                    "face_index": 0,
                    "embedding": self.base_emb,
                    "bbox": [10.0, 10.0, 50.0, 50.0],
                    "det_score": 0.98,
                }
            ],
            "ai_matches": None,
            "created_at": "2026-10-01T12:00:00Z",
        }

        ref_emb = make_vector_with_similarity(self.base_emb, 0.85)
        active_missing = [
            {
                "id": self.valid_person_id,
                "case_code": "MP001",
                "full_name": "Test Subject",
                "age": 30,
                "gender": "Male",
                "status": "Missing",
            }
        ]
        embeddings = [
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "embedding": ref_emb,
                "image_path": "missing_people/MP001/photo_1.jpeg",
                "det_score": 0.99,
            }
        ]

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=active_missing,
            embeddings_data=embeddings,
            sightings_data=[sighting_record],
        )
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/missing_people/MP001/photo_1.jpeg"
        }
        mock_get_supabase.return_value = mock_supabase

        response = self.client.post(f"/api/sightings/{sighting_id}/match")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertEqual(res_json["sighting_id"], sighting_id)
        self.assertEqual(res_json["detected_faces"], 1)
        self.assertEqual(res_json["matched_person_id"], self.valid_person_id)
        self.assertIsNotNone(res_json["top_match"])
        self.assertEqual(res_json["top_match"]["match_category"], "match")
        self.assertGreaterEqual(res_json["top_match"]["similarity_score"], 0.50)

        # Check candidate cases
        self.assertTrue(len(res_json["candidate_cases"]) >= 1)
        candidate = res_json["candidate_cases"][0]
        self.assertEqual(candidate["missing_person_id"], self.valid_person_id)
        self.assertEqual(candidate["case_code"], "MP001")
        self.assertEqual(candidate["full_name"], "Test Subject")
        self.assertEqual(candidate["match_category"], "match")
        self.assertEqual(
            candidate["reference_photo_signed_url"],
            "https://storage.supabase.com/signed/missing_people/MP001/photo_1.jpeg",
        )

        # Ensure no biometric vector leaks
        self.assertNotIn("face_data", res_json)
        self.assertNotIn("embedding", res_json)
        self.assertNotIn("embeddings", res_json)

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_no_strong_match(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": None,
            "citizen_id": None,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "face_data": [
                {
                    "face_index": 0,
                    "embedding": self.base_emb,
                    "bbox": [10.0, 10.0, 50.0, 50.0],
                    "det_score": 0.95,
                }
            ],
            "ai_matches": None,
            "created_at": "2026-10-01T12:00:00Z",
        }

        # Low similarity: 0.20 < 0.35 threshold
        ref_emb = make_vector_with_similarity(self.base_emb, 0.20)
        active_missing = [
            {
                "id": self.valid_person_id,
                "case_code": "MP002",
                "full_name": "Unrelated Person",
                "status": "Missing",
            }
        ]
        embeddings = [
            {
                "missing_person_id": self.valid_person_id,
                "embedding": ref_emb,
                "image_path": "missing_people/MP002/photo_1.jpeg",
            }
        ]

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=active_missing,
            embeddings_data=embeddings,
            sightings_data=[sighting_record],
        )
        mock_get_supabase.return_value = mock_supabase

        response = self.client.post(f"/api/sightings/{sighting_id}/match")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertIsNone(res_json["matched_person_id"])
        self.assertIsNone(res_json["top_match"])
        self.assertEqual(len(res_json["candidate_cases"]), 1)
        self.assertEqual(res_json["candidate_cases"][0]["match_category"], "no_match")

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_no_active_cases(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": None,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "face_data": [
                {
                    "face_index": 0,
                    "embedding": self.base_emb,
                    "bbox": [10.0, 10.0, 50.0, 50.0],
                    "det_score": 0.95,
                }
            ],
            "ai_matches": None,
            "created_at": "2026-10-01T12:00:00Z",
        }

        mock_supabase, _ = self._setup_mock_supabase(
            active_missing_data=[],
            embeddings_data=[],
            sightings_data=[sighting_record],
        )
        mock_get_supabase.return_value = mock_supabase

        response = self.client.post(f"/api/sightings/{sighting_id}/match")
        self.assertEqual(response.status_code, 200)

        res_json = response.get_json()
        self.assertIsNone(res_json["matched_person_id"])
        self.assertEqual(res_json["ai_matches"], [])
        self.assertEqual(res_json["candidate_cases"], [])

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_database_failure(self, mock_get_supabase):
        def fail_query():
            raise RuntimeError("Database connection timed out")

        mock_client = MagicMock()
        mock_client.table.return_value = MockTableQueryBuilder(on_execute=fail_query)
        mock_get_supabase.return_value = mock_client

        sighting_id = str(uuid4())
        response = self.client.post(f"/api/sightings/{sighting_id}/match")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Could not query sighting", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_post_sighting_match_trailing_slash(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": None,
            "image_url": "sightings/sample.jpg",
            "is_verified": False,
            "face_data": [
                {
                    "face_index": 0,
                    "embedding": self.base_emb,
                    "bbox": [10.0, 10.0, 50.0, 50.0],
                    "det_score": 0.95,
                }
            ],
            "created_at": "2026-10-01T12:00:00Z",
        }

        mock_supabase, _ = self._setup_mock_supabase(
            active_missing_data=[],
            embeddings_data=[],
            sightings_data=[sighting_record],
        )
        mock_get_supabase.return_value = mock_supabase

        response = self.client.post(f"/api/sightings/{sighting_id}/match/")
        self.assertEqual(response.status_code, 200)

    # -------------------------------------------------------------
    # 9. PATCH /api/sightings/<sighting_id>/verify Tests
    # -------------------------------------------------------------
    def test_verify_sighting_invalid_uuid(self):
        response = self.client.patch("/api/sightings/not-a-valid-uuid/verify", json={"action": "verify"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid sighting ID", response.get_json()["error"])

    def test_verify_sighting_invalid_action(self):
        sighting_id = str(uuid4())
        response = self.client.patch(f"/api/sightings/{sighting_id}/verify", json={"action": "invalid_action"})
        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid action", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_verify_sighting_not_found(self, mock_get_supabase):
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[])
        mock_get_supabase.return_value = mock_supabase

        sighting_id = str(uuid4())
        response = self.client.patch(f"/api/sightings/{sighting_id}/verify", json={"action": "verify"})
        self.assertEqual(response.status_code, 404)
        self.assertIn("Sighting record not found", response.get_json()["error"])

    @patch("routes.sightings.get_supabase_client")
    def test_verify_sighting_action_verify_success(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "is_verified": False,
            "ai_matches": [{"missing_person_id": self.valid_person_id, "similarity_score": 0.88}],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.patch(
            f"/api/sightings/{sighting_id}/verify",
            json={"action": "verify", "remarks": "Visual match confirmed by officer"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertTrue(res_json["is_verified"])
        self.assertEqual(res_json["action"], "verify")
        self.assertEqual(res_json["remarks"], "Visual match confirmed by officer")

    @patch("routes.sightings.get_supabase_client")
    def test_verify_sighting_action_reject_success(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "is_verified": True,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.patch(
            f"/api/sightings/{sighting_id}/verify",
            json={"action": "reject", "remarks": "Incorrect person in photograph"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertFalse(res_json["is_verified"])
        self.assertEqual(res_json["action"], "reject")

    @patch("routes.sightings.get_supabase_client")
    def test_verify_sighting_action_reject_with_unlink(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "is_verified": False,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.patch(
            f"/api/sightings/{sighting_id}/verify",
            json={"action": "reject", "unlink_case": True, "remarks": "False positive match"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertFalse(res_json["is_verified"])

    # -------------------------------------------------------------
    # 10. Sighting Linked to Resolved Case Enrichment
    # -------------------------------------------------------------
    @patch("routes.sightings.get_supabase_client")
    def test_sighting_detail_enrichment_for_found_case(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "latitude": 19.0760,
            "longitude": 72.8777,
            "image_url": "sightings/resolved_found.jpg",
            "is_verified": True,
            "created_at": "2026-10-01T12:00:00Z",
            "ai_matches": [],
        }

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[{
                "id": self.valid_person_id,
                "case_code": "MP001",
                "full_name": "Sona Tiwari",
                "status": "Found",
            }],
            sightings_data=[sighting_record],
        )
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/resolved_found.jpg"
        }
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["linked_case_code"], "MP001")
        self.assertEqual(res_json["linked_case_name"], "Sona Tiwari")
        self.assertEqual(res_json["linked_case_status"], "Found")
        self.assertTrue(res_json["is_case_resolved"])

    @patch("routes.sightings.get_supabase_client")
    def test_sighting_detail_enrichment_for_closed_case(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "latitude": 19.0760,
            "longitude": 72.8777,
            "image_url": "sightings/resolved_closed.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "ai_matches": [],
        }

        mock_supabase, mock_storage = self._setup_mock_supabase(
            active_missing_data=[{
                "id": self.valid_person_id,
                "case_code": "MP002",
                "full_name": "Ramesh Kumar",
                "status": "Closed",
            }],
            sightings_data=[sighting_record],
        )
        mock_storage.create_signed_url.return_value = {
            "signedURL": "https://storage.supabase.com/signed/resolved_closed.jpg"
        }
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["linked_case_code"], "MP002")
        self.assertEqual(res_json["linked_case_name"], "Ramesh Kumar")
        self.assertEqual(res_json["linked_case_status"], "Closed")
        self.assertTrue(res_json["is_case_resolved"])



    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "citizen_note": "Citizen thinks this sighting may be Aarav Sharma (MP-001).",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Aarav Sharma (MP-001).")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_citizen_note(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "citizen_note": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_with_citizen_note(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": 12.9716,
            "longitude": 77.5946,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": "Citizen thinks this sighting may be Hetal Rana (MP-005).",
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["citizen_note"], "Citizen thinks this sighting may be Hetal Rana (MP-005).")

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_null_citizen_note_backwards_compatible(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": 12.9716,
            "longitude": 77.5946,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": None,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertIsNone(res_json["citizen_note"])


    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_combinations_address_and_coordinates(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.98,
        }]

        test_cases = [
            ("address_only", "Near Dadar West Market", None, None, "Near Dadar West Market", None, None),
            ("coordinates_only", None, "19.0544", "72.8402", None, 19.0544, 72.8402),
            ("both", "Bandra Station West Platform 1", "19.0544", "72.8402", "Bandra Station West Platform 1", 19.0544, 72.8402),
            ("neither", None, None, None, None, None, None),
        ]

        jpeg_bytes = make_dummy_jpeg()

        for name, addr, lat, lon, exp_addr, exp_lat, exp_lon in test_cases:
            sightings_builder = MockTableQueryBuilder()
            mock_client = MagicMock()
            mock_storage = MagicMock()
            mock_storage.upload.return_value = {"Key": "sightings/mock.jpg"}
            mock_storage.remove.return_value = [{"name": "sightings/mock.jpg"}]
            mock_storage.create_signed_url.return_value = {
                "signedURL": "https://storage.supabase.com/signed/mock.jpg"
            }
            mock_client.storage.from_.return_value = mock_storage

            def make_table_router(sb):
                def table_router(table_name):
                    if table_name == "missing_persons":
                        return MockTableQueryBuilder(data=[{"id": self.valid_person_id}])
                    elif table_name == "missing_person_embeddings":
                        return MockTableQueryBuilder(data=[
                            {"missing_person_id": self.valid_person_id, "embedding": make_vector_with_similarity(self.base_emb, 0.82)}
                        ])
                    elif table_name == "missing_person_sightings":
                        return sb
                    return MockTableQueryBuilder()
                return table_router

            mock_client.table.side_effect = make_table_router(sightings_builder)
            mock_get_supabase.return_value = mock_client

            data = {
                "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            }
            if addr is not None:
                data["address"] = addr
            if lat is not None:
                data["latitude"] = lat
            if lon is not None:
                data["longitude"] = lon

            response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
            self.assertEqual(response.status_code, 201, f"Failed for case {name}: {response.get_json()}")
            res_json = response.get_json()

            if exp_addr is not None:
                self.assertEqual(res_json["address"], exp_addr, f"Address mismatch for {name}")
            else:
                self.assertIsNone(res_json["address"], f"Expected null address for {name}")

            # Verify saved in DB insert
            self.assertEqual(len(sightings_builder.inserted_records), 1)
            inserted = sightings_builder.inserted_records[0]
            self.assertEqual(inserted.get("address"), exp_addr, f"DB insert address mismatch for {name}")
            self.assertEqual(inserted.get("latitude"), exp_lat, f"DB insert latitude mismatch for {name}")
            self.assertEqual(inserted.get("longitude"), exp_lon, f"DB insert longitude mismatch for {name}")

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_with_address(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": 19.0544,
            "longitude": 72.8402,
            "address": "Bandra Station West Concourse, Platform 1",
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": None,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["address"], "Bandra Station West Concourse, Platform 1")

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_null_address_backwards_compatible(self, mock_get_supabase):
        sighting_id = str(uuid4())
        # Older record without address
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": None,
            "longitude": None,
            "address": None,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": None,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertIsNone(res_json["address"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_list_includes_address(self, mock_get_supabase):
        records = [
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "latitude": 19.0544,
                "longitude": 72.8402,
                "address": "Bandra Station Platform 1",
                "image_url": "sightings/1.jpg",
                "is_verified": False,
                "created_at": "2026-10-02T12:00:00Z",
                "citizen_note": None,
            },
            {
                "id": str(uuid4()),
                "missing_person_id": None,
                "latitude": None,
                "longitude": None,
                "address": None,
                "image_url": "sightings/2.jpg",
                "is_verified": False,
                "created_at": "2026-10-01T12:00:00Z",
                "citizen_note": None,
            },
        ]
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=records)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(len(res_json["sightings"]), 2)
        self.assertEqual(res_json["sightings"][0]["address"], "Bandra Station Platform 1")
        self.assertIsNone(res_json["sightings"][1]["address"])

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_valid_contact_email(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "contact_email": "witness.citizen@example.com",
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "contact_email": "witness.citizen@example.com",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertEqual(res_json["contact_email"], "witness.citizen@example.com")

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_with_invalid_contact_email_rejected(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
            "contact_email": "not-a-valid-email-address",
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 400)
        res_json = response.get_json()
        self.assertIn("Invalid contact email", res_json.get("error", ""))

    @patch("routes.sightings.get_supabase_client")
    @patch("routes.sightings.extract_all_sighting_faces_from_image")
    def test_post_sighting_without_contact_email_stores_null(self, mock_extract, mock_get_supabase):
        mock_extract.return_value = [{
            "face_index": 0,
            "embedding": self.base_emb,
            "bbox": [10.0, 10.0, 50.0, 50.0],
            "det_score": 0.90,
        }]

        captured_records = []
        def capture_insert():
            res = MagicMock()
            rec = {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "contact_email": None,
            }
            captured_records.append(rec)
            res.data = [rec]
            return res

        mock_supabase, _ = self._setup_mock_supabase(insert_on_execute=capture_insert)
        mock_get_supabase.return_value = mock_supabase

        jpeg_bytes = make_dummy_jpeg()
        data = {
            "sighting_image": (io.BytesIO(jpeg_bytes), "sighting.jpg"),
        }

        response = self.client.post("/api/sightings", data=data, content_type="multipart/form-data")
        self.assertEqual(response.status_code, 201)
        res_json = response.get_json()
        self.assertIsNone(res_json["contact_email"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_with_contact_email(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": 19.0544,
            "longitude": 72.8402,
            "address": "Dadar Bastian cafe",
            "contact_email": "reporter@example.org",
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": None,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json["contact_email"], "reporter@example.org")

    @patch("routes.sightings.get_supabase_client")
    def test_get_sighting_detail_null_contact_email_backwards_compatible(self, mock_get_supabase):
        sighting_id = str(uuid4())
        sighting_record = {
            "id": sighting_id,
            "missing_person_id": self.valid_person_id,
            "citizen_id": None,
            "latitude": None,
            "longitude": None,
            "address": None,
            "contact_email": None,
            "image_url": "sightings/sighting_sample.jpg",
            "is_verified": False,
            "created_at": "2026-10-01T12:00:00Z",
            "citizen_note": None,
            "ai_matches": [],
        }
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=[sighting_record])
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get(f"/api/sightings/{sighting_id}")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertIsNone(res_json["contact_email"])

    @patch("routes.sightings.get_supabase_client")
    def test_get_sightings_list_includes_contact_email(self, mock_get_supabase):
        records = [
            {
                "id": str(uuid4()),
                "missing_person_id": self.valid_person_id,
                "latitude": 19.0544,
                "longitude": 72.8402,
                "address": "Bandra Station Platform 1",
                "contact_email": "citizen1@unisafe.org",
                "image_url": "sightings/1.jpg",
                "is_verified": False,
                "created_at": "2026-10-02T12:00:00Z",
                "citizen_note": None,
            },
            {
                "id": str(uuid4()),
                "missing_person_id": None,
                "latitude": None,
                "longitude": None,
                "address": None,
                "contact_email": None,
                "image_url": "sightings/2.jpg",
                "is_verified": False,
                "created_at": "2026-10-01T12:00:00Z",
                "citizen_note": None,
            },
        ]
        mock_supabase, _ = self._setup_mock_supabase(sightings_data=records)
        mock_get_supabase.return_value = mock_supabase

        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(len(res_json["sightings"]), 2)
        self.assertEqual(res_json["sightings"][0]["contact_email"], "citizen1@unisafe.org")
        self.assertIsNone(res_json["sightings"][1]["contact_email"])


if __name__ == "__main__":
    unittest.main()

