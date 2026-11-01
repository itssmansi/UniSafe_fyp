import unittest
from unittest.mock import MagicMock, patch
from uuid import uuid4
from app import app


class MockQueryBuilder:
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

    def ilike(self, *args, **kwargs):
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
        res.data = self._data
        return res


class TestAuthRBAC(unittest.TestCase):
    def setUp(self):
        self.app = app
        self.app.config["TESTING"] = True
        self.app.config["REQUIRE_AUTH_IN_TESTS"] = True
        self.client = self.app.test_client()

        self.valid_person_id = str(uuid4())
        self.valid_sighting_id = str(uuid4())

        self.police_inspector_id = "95db69d2-f380-45a4-bea1-1a3d7a5bedbd"
        self.bmc_officer_id = "e1fc9047-abec-42f0-b9f4-b6de8df02e3c"
        self.citizen_id = "9250ca8e-960c-4ee3-b8f3-bd4248fc3cf3"

    def tearDown(self):
        self.app.config["REQUIRE_AUTH_IN_TESTS"] = False

    # -------------------------------------------------------------
    # 1. Unauthenticated Access Tests (401 Unauthorized)
    # -------------------------------------------------------------
    def test_unauthenticated_request_to_sightings_queue(self):
        """Unauthenticated requests to internal sightings queue must return 401."""
        response = self.client.get("/api/sightings")
        self.assertEqual(response.status_code, 401)
        res_json = response.get_json()
        self.assertEqual(res_json.get("code"), "UNAUTHENTICATED")
        self.assertIn("Authentication required", res_json.get("error", ""))

    def test_unauthenticated_request_to_sighting_detail(self):
        """Unauthenticated requests to internal sighting detail must return 401."""
        response = self.client.get(f"/api/sightings/{self.valid_sighting_id}")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    def test_unauthenticated_request_to_case_detail(self):
        """Unauthenticated requests to missing person dossier must return 401."""
        response = self.client.get(f"/api/missing-persons/{self.valid_person_id}")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    def test_unauthenticated_request_to_case_registration(self):
        """Unauthenticated requests to register missing person must return 401."""
        response = self.client.post("/api/missing-persons", data={"full_name": "John Doe"})
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    def test_unauthenticated_request_to_status_update(self):
        """Unauthenticated requests to update case status must return 401."""
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            json={"status": "Found", "verified_confirmation": True}
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    def test_unauthenticated_request_to_sighting_match(self):
        """Unauthenticated requests to trigger face match must return 401."""
        response = self.client.post(f"/api/sightings/{self.valid_sighting_id}/match")
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    # -------------------------------------------------------------
    # 2. Invalid Token Tests (401 Unauthorized)
    # -------------------------------------------------------------
    @patch("middleware.auth.verify_supabase_token")
    def test_invalid_or_expired_token_rejected(self, mock_verify):
        """Invalid or expired Supabase tokens must return 401."""
        mock_verify.return_value = (None, "Token is expired")
        response = self.client.get(
            "/api/sightings",
            headers={"Authorization": "Bearer bad-expired-token"}
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "INVALID_TOKEN")

    # -------------------------------------------------------------
    # 3. Citizen Role Forbidden on Authority Endpoints (403 Forbidden)
    # -------------------------------------------------------------
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_citizen_forbidden_on_authority_endpoint(self, mock_verify, mock_lookup):
        """A citizen authenticated user must receive 403 when accessing authority queue."""
        mock_verify.return_value = (type("User", (), {"id": self.citizen_id})(), None)
        mock_lookup.return_value = {
            "id": self.citizen_id,
            "name": "Aarav Sharma",
            "user_type": "citizen",
            "role": "citizen"
        }

        response = self.client.get(
            "/api/sightings",
            headers={"Authorization": "Bearer valid-citizen-token"}
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.get_json().get("code"), "FORBIDDEN")
        self.assertIn("only registered authorities", response.get_json().get("error", ""))

    # -------------------------------------------------------------
    # 4. Department Restrictions (403 Forbidden)
    # -------------------------------------------------------------
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_bmc_officer_forbidden_on_police_only_status_update(self, mock_verify, mock_lookup):
        """A BMC officer must be forbidden from updating police case status."""
        mock_verify.return_value = (type("User", (), {"id": self.bmc_officer_id})(), None)
        mock_lookup.return_value = {
            "id": "b5af0aee-c9f4-4cb9-be92-9097571d5362",
            "name": "Neha Desai",
            "department": "BMC",
            "role": "Ward Officer",
            "user_type": "authority"
        }

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            headers={"Authorization": "Bearer valid-bmc-token"},
            json={"status": "Found", "verified_confirmation": True}
        )
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.get_json().get("code"), "FORBIDDEN")
        self.assertIn("restricted to POLICE department", response.get_json().get("error", ""))

    # -------------------------------------------------------------
    # 5. Authorized Police Authority Success
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_police_inspector_allowed_on_status_update(self, mock_verify, mock_lookup, mock_db):
        """A Police Inspector is allowed to update case status."""
        mock_verify.return_value = (type("User", (), {"id": self.police_inspector_id})(), None)
        mock_lookup.return_value = {
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority"
        }

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[{
            "id": self.valid_person_id,
            "case_code": "MP001",
            "full_name": "Sona Tiwari",
            "status": "Missing"
        }])
        mock_db.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            headers={"Authorization": "Bearer valid-inspector-token"},
            json={"status": "Found", "verified_confirmation": True, "remarks": "Found by Inspector Patil"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertEqual(res_json.get("status"), "Found")

    # -------------------------------------------------------------
    # 6. Public Endpoints Accessible Without Authentication
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    def test_public_missing_persons_list_accessible(self, mock_db):
        """Citizens and public can browse missing persons without auth token."""
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[{
            "id": self.valid_person_id,
            "case_code": "MP001",
            "full_name": "Sona Tiwari",
            "status": "Missing"
        }])
        mock_db.return_value = mock_client

        response = self.client.get("/api/missing-persons")
        self.assertEqual(response.status_code, 200)
        self.assertIn("missing_persons", response.get_json())

    # -------------------------------------------------------------
    # 7. Authority Login Endpoint (/api/auth/authority-login)
    # -------------------------------------------------------------
    def test_authority_login_missing_fields(self):
        """Validation fails if required credentials are not provided."""
        res1 = self.client.post("/api/auth/authority-login", json={"name": ""})
        self.assertEqual(res1.status_code, 400)
        self.assertIn("name is required", res1.get_json()["error"].lower())

        res2 = self.client.post("/api/auth/authority-login", json={"name": "Rajesh", "department": ""})
        self.assertEqual(res2.status_code, 400)
        self.assertIn("department is required", res2.get_json()["error"].lower())

    @patch("routes.auth.get_supabase_client")
    def test_authority_login_unregistered_officer(self, mock_db):
        """Unregistered officer name returns 401."""
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[])
        mock_db.return_value = mock_client

        response = self.client.post("/api/auth/authority-login", json={
            "name": "Nonexistent Officer",
            "department": "POLICE",
            "designation": "Inspector",
            "password": "any"
        })
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json()["code"], "INVALID_CREDENTIALS")

    @patch("routes.auth.get_supabase_client")
    def test_authority_login_success(self, mock_db):
        """Valid registered officer credentials return legitimate session token."""
        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[{
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority",
            "jurisdiction": "Mumbai North",
            "auth_user_id": self.police_inspector_id
        }])

        # Mock Supabase Auth admin & verify_otp
        mock_admin = MagicMock()
        mock_admin.get_user_by_id.return_value = MagicMock(
            user=MagicMock(email="inspector001@unisafe.demo")
        )
        mock_link = MagicMock()
        mock_link.properties = MagicMock(email_otp="123456")
        mock_admin.generate_link.return_value = mock_link
        mock_client.auth.admin = mock_admin

        mock_session_res = MagicMock()
        mock_session_res.session = MagicMock(
            access_token="test-access-token-xyz",
            refresh_token="test-refresh-token-xyz"
        )
        mock_client.auth.verify_otp.return_value = mock_session_res
        mock_db.return_value = mock_client

        response = self.client.post("/api/auth/authority-login", json={
            "name": "Rajesh Patil",
            "department": "POLICE",
            "designation": "Inspector",
            "password": "secretpassword"
        })
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertEqual(res_json["access_token"], "test-access-token-xyz")
        self.assertEqual(res_json["user"]["name"], "Rajesh Patil")
        self.assertEqual(res_json["user"]["department"], "POLICE")
        self.assertEqual(res_json["user"]["role"], "Inspector")

    # -------------------------------------------------------------
    # 8. Current Officer Profile (/api/auth/me)
    # -------------------------------------------------------------
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_auth_me_authenticated(self, mock_verify, mock_lookup):
        """Authenticated authority officer can fetch /api/auth/me."""
        mock_verify.return_value = (type("User", (), {"id": self.police_inspector_id})(), None)
        mock_lookup.return_value = {
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority"
        }

        response = self.client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer valid-token"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertEqual(res_json["user"]["name"], "Rajesh Patil")

    # -------------------------------------------------------------
    # 9. BMC Forbidden on All Police Missing-Person & Sighting Endpoints
    # -------------------------------------------------------------
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_bmc_officer_forbidden_on_all_police_endpoints(self, mock_verify, mock_lookup):
        """BMC officers must be rejected with 403 across all police-restricted endpoints."""
        mock_verify.return_value = (type("User", (), {"id": self.bmc_officer_id})(), None)
        mock_lookup.return_value = {
            "id": "b5af0aee-c9f4-4cb9-be92-9097571d5362",
            "name": "Neha Desai",
            "department": "BMC",
            "role": "Ward Officer",
            "user_type": "authority"
        }

        bmc_headers = {"Authorization": "Bearer valid-bmc-token"}
        endpoints = [
            ("POST", "/api/missing-persons", {"data": {"full_name": "Test"}}),
            ("GET", f"/api/missing-persons/{self.valid_person_id}", {}),
            ("POST", f"/api/missing-persons/{self.valid_person_id}/photos", {}),
            ("DELETE", f"/api/missing-persons/{self.valid_person_id}/photos", {"json": {"embedding_id": str(uuid4())}}),
            ("PATCH", f"/api/missing-persons/{self.valid_person_id}", {"json": {"full_name": "New Name"}}),
            ("GET", "/api/sightings", {}),
            ("GET", f"/api/sightings/{self.valid_sighting_id}", {}),
            ("PATCH", f"/api/sightings/{self.valid_sighting_id}/verify", {"json": {"action": "verify"}}),
            ("POST", f"/api/sightings/{self.valid_sighting_id}/match", {}),
        ]

        for method, path, kwargs in endpoints:
            with self.subTest(method=method, path=path):
                req_kwargs = dict(kwargs)
                req_kwargs["headers"] = bmc_headers
                if method == "GET":
                    res = self.client.get(path, **req_kwargs)
                elif method == "POST":
                    res = self.client.post(path, **req_kwargs)
                elif method == "PATCH":
                    res = self.client.patch(path, **req_kwargs)
                elif method == "DELETE":
                    res = self.client.delete(path, **req_kwargs)

                self.assertEqual(
                    res.status_code, 403,
                    f"Expected 403 FORBIDDEN for BMC officer on {method} {path}, got {res.status_code}"
                )
                self.assertEqual(res.get_json().get("code"), "FORBIDDEN")
                self.assertIn("POLICE", res.get_json().get("error", ""))

    # -------------------------------------------------------------
    # 10. Sighting Review & Verification RBAC
    # -------------------------------------------------------------
    def test_unauthenticated_request_to_sighting_verify(self):
        """Unauthenticated call to sighting verify returns 401."""
        response = self.client.patch(
            f"/api/sightings/{self.valid_sighting_id}/verify",
            json={"action": "verify"}
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.get_json().get("code"), "UNAUTHENTICATED")

    @patch("routes.sightings.get_supabase_client")
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_police_officer_allowed_on_sighting_verify(self, mock_verify, mock_lookup, mock_db):
        """Authorized Police officer can verify a sighting."""
        mock_verify.return_value = (type("User", (), {"id": self.police_inspector_id})(), None)
        mock_lookup.return_value = {
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority"
        }

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[{
            "id": self.valid_sighting_id,
            "missing_person_id": self.valid_person_id,
            "is_verified": False,
        }])
        mock_db.return_value = mock_client

        response = self.client.patch(
            f"/api/sightings/{self.valid_sighting_id}/verify",
            headers={"Authorization": "Bearer valid-police-token"},
            json={"action": "verify", "remarks": "Match confirmed"}
        )
        self.assertEqual(response.status_code, 200)
        res_json = response.get_json()
        self.assertTrue(res_json["success"])
        self.assertTrue(res_json["is_verified"])

    # -------------------------------------------------------------
    # 11. Separation of Verification and Found Status
    # -------------------------------------------------------------
    @patch("routes.missing_persons.get_supabase_client")
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_case_status_found_requires_verified_confirmation(self, mock_verify, mock_lookup, mock_db):
        """Declaring person Found requires explicit verified_confirmation=True."""
        mock_verify.return_value = (type("User", (), {"id": self.police_inspector_id})(), None)
        mock_lookup.return_value = {
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority"
        }

        # Attempting without verified_confirmation
        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            headers={"Authorization": "Bearer valid-police-token"},
            json={"status": "Found"}
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("explicit officer verification confirmation", response.get_json()["error"])

    @patch("routes.missing_persons.get_supabase_client")
    @patch("middleware.auth.lookup_authority_profile")
    @patch("middleware.auth.verify_supabase_token")
    def test_case_status_closed_succeeds(self, mock_verify, mock_lookup, mock_db):
        """Police officer can close a case."""
        mock_verify.return_value = (type("User", (), {"id": self.police_inspector_id})(), None)
        mock_lookup.return_value = {
            "id": "884460fd-bad6-445a-864d-8c5f18763bec",
            "name": "Rajesh Patil",
            "department": "POLICE",
            "role": "Inspector",
            "user_type": "authority"
        }

        mock_client = MagicMock()
        mock_client.table.return_value = MockQueryBuilder(data=[{
            "id": self.valid_person_id,
            "case_code": "MP001",
            "status": "Missing"
        }])
        mock_db.return_value = mock_client

        response = self.client.patch(
            f"/api/missing-persons/{self.valid_person_id}/status",
            headers={"Authorization": "Bearer valid-police-token"},
            json={"status": "Closed", "remarks": "Case investigation completed"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["status"], "Closed")


if __name__ == "__main__":
    unittest.main()

