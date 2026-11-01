import unittest
import numpy as np
from uuid import uuid4

from services.face_recognition import (
    compute_cosine_similarity,
    categorize_similarity,
    validate_and_normalize_embedding,
    match_sighting_against_cases,
    EXPECTED_EMBEDDING_DIM,
)


def create_unit_embedding(dim=EXPECTED_EMBEDDING_DIM, index=0):
    """Creates a deterministic unit basis vector of length dim."""
    vec = np.zeros(dim, dtype=np.float32)
    vec[index % dim] = 1.0
    return vec.tolist()


def create_embedding_with_similarity(base_embedding, target_similarity, dim=EXPECTED_EMBEDDING_DIM):
    """
    Creates a normalized 512-D unit vector with exact cosine similarity to base_embedding.
    Uses Gram-Schmidt orthogonalization: v = s * base + sqrt(1 - s^2) * ortho.
    """
    base = np.asarray(base_embedding, dtype=np.float32)
    base = base / np.linalg.norm(base)

    # Pick an orthogonal basis vector
    ortho = np.zeros(dim, dtype=np.float32)
    idx = 1 if abs(base[1]) < 0.9 else 2
    ortho[idx] = 1.0
    ortho = ortho - np.dot(ortho, base) * base
    ortho = ortho / np.linalg.norm(ortho)

    s = float(target_similarity)
    c = np.sqrt(max(0.0, 1.0 - s * s))
    result = s * base + c * ortho
    normalized = result / np.linalg.norm(result)
    return normalized.astype(np.float32).tolist()


class TestFaceMatchingService(unittest.TestCase):
    """
    Unit tests for the sighting-to-reference face matching service and helper functions.
    Tests run purely in-memory with mocked/synthetic embeddings, requiring zero live DB or GPU calls.
    """

    def setUp(self):
        self.base_emb_0 = create_unit_embedding(index=0)
        self.base_emb_1 = create_unit_embedding(index=1)
        self.person_id_1 = str(uuid4())
        self.person_id_2 = str(uuid4())

    # -------------------------------------------------------------
    # 1. Embedding Validation and Normalization Tests
    # -------------------------------------------------------------
    def test_validate_and_normalize_valid_list(self):
        emb = create_unit_embedding()
        result = validate_and_normalize_embedding(emb)
        self.assertIsNotNone(result)
        self.assertEqual(result.shape, (EXPECTED_EMBEDDING_DIM,))
        self.assertAlmostEqual(float(np.linalg.norm(result)), 1.0, places=5)

    def test_validate_and_normalize_unnormalized_vector(self):
        # Vector with non-unit norm should be normalized
        vec = [2.0] * EXPECTED_EMBEDDING_DIM
        result = validate_and_normalize_embedding(vec)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(float(np.linalg.norm(result)), 1.0, places=5)

    def test_validate_and_normalize_pgvector_string(self):
        emb = create_unit_embedding()
        str_emb = "[" + ",".join(str(x) for x in emb) + "]"
        result = validate_and_normalize_embedding(str_emb)
        self.assertIsNotNone(result)
        self.assertEqual(result.shape, (EXPECTED_EMBEDDING_DIM,))

    def test_validate_and_normalize_invalid_inputs(self):
        # None
        self.assertIsNone(validate_and_normalize_embedding(None))
        # Empty list
        self.assertIsNone(validate_and_normalize_embedding([]))
        # Wrong dimension (too short)
        self.assertIsNone(validate_and_normalize_embedding([0.1] * 256))
        # Wrong dimension (too long)
        self.assertIsNone(validate_and_normalize_embedding([0.1] * 513))
        # All zeros (zero norm)
        self.assertIsNone(validate_and_normalize_embedding([0.0] * EXPECTED_EMBEDDING_DIM))
        # Contains NaN
        nan_vec = [0.1] * EXPECTED_EMBEDDING_DIM
        nan_vec[10] = float("nan")
        self.assertIsNone(validate_and_normalize_embedding(nan_vec))
        # Contains Inf
        inf_vec = [0.1] * EXPECTED_EMBEDDING_DIM
        inf_vec[10] = float("inf")
        self.assertIsNone(validate_and_normalize_embedding(inf_vec))
        # Non-numeric string
        self.assertIsNone(validate_and_normalize_embedding("corrupt_vector_data"))
        # Invalid object type
        self.assertIsNone(validate_and_normalize_embedding(12345))

    # -------------------------------------------------------------
    # 2. Threshold Boundaries & Categorization Tests
    # -------------------------------------------------------------
    def test_categorize_similarity_high_threshold(self):
        # Exactly 0.50 -> match
        self.assertEqual(categorize_similarity(0.50), "match")
        # Above 0.50 -> match
        self.assertEqual(categorize_similarity(0.75), "match")
        self.assertEqual(categorize_similarity(0.99), "match")
        self.assertEqual(categorize_similarity(1.00), "match")
        # Just below 0.50 -> potential_match
        self.assertEqual(categorize_similarity(0.4999), "potential_match")

    def test_categorize_similarity_low_threshold(self):
        # Exactly 0.35 -> potential_match
        self.assertEqual(categorize_similarity(0.35), "potential_match")
        # Between 0.35 and 0.50 -> potential_match
        self.assertEqual(categorize_similarity(0.42), "potential_match")
        # Just below 0.35 -> no_match
        self.assertEqual(categorize_similarity(0.3499), "no_match")
        # Well below 0.35 -> no_match
        self.assertEqual(categorize_similarity(0.15), "no_match")
        self.assertEqual(categorize_similarity(0.0), "no_match")
        self.assertEqual(categorize_similarity(-0.5), "no_match")

    def test_categorize_similarity_custom_thresholds(self):
        # Custom thresholds: high=0.60, low=0.40
        self.assertEqual(categorize_similarity(0.60, high_thresh=0.60, low_thresh=0.40), "match")
        self.assertEqual(categorize_similarity(0.55, high_thresh=0.60, low_thresh=0.40), "potential_match")
        self.assertEqual(categorize_similarity(0.38, high_thresh=0.60, low_thresh=0.40), "no_match")

    # -------------------------------------------------------------
    # 3. One Face Matching One Missing-Person Case
    # -------------------------------------------------------------
    def test_one_face_matches_one_case_strong_match(self):
        sighting_emb = self.base_emb_0
        target_score = 0.82
        ref_emb = create_embedding_with_similarity(sighting_emb, target_score)

        sighting_faces = [{"face_index": 0, "embedding": sighting_emb}]
        reference_profiles = [
            {"missing_person_id": self.person_id_1, "embedding": ref_emb}
        ]

        results = match_sighting_against_cases(sighting_faces, reference_profiles)

        self.assertEqual(len(results), 1)
        match = results[0]
        self.assertEqual(match["face_index"], 0)
        self.assertEqual(match["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(match["similarity_score"], target_score, places=3)
        self.assertEqual(match["match_category"], "match")
        self.assertEqual(match["status"], "match")
        # Ensure raw embedding is NOT leaked in the returned match dictionary
        self.assertNotIn("embedding", match)
        self.assertNotIn("embeddings", match)

    def test_one_face_matches_one_case_potential_match(self):
        sighting_emb = self.base_emb_0
        target_score = 0.44
        ref_emb = create_embedding_with_similarity(sighting_emb, target_score)

        sighting_faces = [{"face_index": 0, "embedding": sighting_emb}]
        reference_profiles = {self.person_id_1: [ref_emb]}

        results = match_sighting_against_cases(sighting_faces, reference_profiles)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["match_category"], "potential_match")
        self.assertEqual(results[0]["status"], "potential_match")
        self.assertAlmostEqual(results[0]["similarity_score"], target_score, places=3)

    def test_one_face_matches_one_case_no_match(self):
        sighting_emb = self.base_emb_0
        target_score = 0.20
        ref_emb = create_embedding_with_similarity(sighting_emb, target_score)

        sighting_faces = [{"face_index": 0, "embedding": sighting_emb}]
        reference_profiles = {self.person_id_1: [ref_emb]}

        # When include_no_match is True (default)
        results = match_sighting_against_cases(sighting_faces, reference_profiles)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["match_category"], "no_match")
        self.assertEqual(results[0]["status"], "no_match")
        self.assertAlmostEqual(results[0]["similarity_score"], target_score, places=3)

        # When include_no_match is False
        filtered_results = match_sighting_against_cases(
            sighting_faces, reference_profiles, include_no_match=False
        )
        self.assertEqual(len(filtered_results), 0)

    # -------------------------------------------------------------
    # 4. Multiple Faces Matching Different Cases
    # -------------------------------------------------------------
    def test_multiple_faces_matching_different_cases(self):
        # Sighting has 2 faces: Face 0 and Face 1
        sighting_face_0 = self.base_emb_0
        sighting_face_1 = self.base_emb_1

        # Person 1 matches Face 0 strongly (0.85) and Face 1 weakly (0.10)
        p1_emb = create_embedding_with_similarity(sighting_face_0, 0.85)
        # Person 2 matches Face 1 strongly (0.78) and Face 0 weakly (0.15)
        p2_emb = create_embedding_with_similarity(sighting_face_1, 0.78)

        sighting_faces = [
            {"face_index": 0, "embedding": sighting_face_0},
            {"face_index": 1, "embedding": sighting_face_1},
        ]
        reference_profiles = [
            {"missing_person_id": self.person_id_1, "embedding": p1_emb},
            {"missing_person_id": self.person_id_2, "embedding": p2_emb},
        ]

        results = match_sighting_against_cases(sighting_faces, reference_profiles)

        # 2 faces x 2 cases = 4 evaluated results
        self.assertEqual(len(results), 4)

        # Face 0 results: best match should be Person 1
        face_0_matches = [r for r in results if r["face_index"] == 0]
        self.assertEqual(face_0_matches[0]["missing_person_id"], self.person_id_1)
        self.assertEqual(face_0_matches[0]["match_category"], "match")
        self.assertAlmostEqual(face_0_matches[0]["similarity_score"], 0.85, places=2)

        # Face 1 results: best match should be Person 2
        face_1_matches = [r for r in results if r["face_index"] == 1]
        self.assertEqual(face_1_matches[0]["missing_person_id"], self.person_id_2)
        self.assertEqual(face_1_matches[0]["match_category"], "match")
        self.assertAlmostEqual(face_1_matches[0]["similarity_score"], 0.78, places=2)

    def test_multiple_faces_top_k_per_face(self):
        sighting_faces = [
            {"face_index": 0, "embedding": self.base_emb_0},
            {"face_index": 1, "embedding": self.base_emb_1},
        ]
        p1_emb = create_embedding_with_similarity(self.base_emb_0, 0.85)
        p2_emb = create_embedding_with_similarity(self.base_emb_1, 0.78)

        reference_profiles = {
            self.person_id_1: [p1_emb],
            self.person_id_2: [p2_emb],
        }

        # Request top 1 case per face
        top_results = match_sighting_against_cases(
            sighting_faces, reference_profiles, top_k_per_face=1
        )
        self.assertEqual(len(top_results), 2)
        self.assertEqual(top_results[0]["face_index"], 0)
        self.assertEqual(top_results[0]["missing_person_id"], self.person_id_1)
        self.assertEqual(top_results[1]["face_index"], 1)
        self.assertEqual(top_results[1]["missing_person_id"], self.person_id_2)

    # -------------------------------------------------------------
    # 5. Multiple Reference Photos Belonging to Same Case
    # -------------------------------------------------------------
    def test_multiple_reference_photos_retains_highest_score(self):
        sighting_emb = self.base_emb_0

        # Person 1 has 3 photos with similarities 0.38 (potential), 0.76 (match), 0.52 (match)
        ref_photo_1 = create_embedding_with_similarity(sighting_emb, 0.38)
        ref_photo_2 = create_embedding_with_similarity(sighting_emb, 0.76)
        ref_photo_3 = create_embedding_with_similarity(sighting_emb, 0.52)

        sighting_faces = [{"face_index": 0, "embedding": sighting_emb}]
        reference_profiles = {
            self.person_id_1: [ref_photo_1, ref_photo_2, ref_photo_3]
        }

        results = match_sighting_against_cases(sighting_faces, reference_profiles)

        # Requirement 4: Exactly ONE result for that case, retaining the HIGHEST similarity score
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["face_index"], 0)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(results[0]["similarity_score"], 0.76, places=3)
        self.assertEqual(results[0]["match_category"], "match")
        self.assertEqual(results[0]["status"], "match")

    def test_flat_supabase_rows_grouped_by_person_id(self):
        sighting_emb = self.base_emb_0

        # Flat records as returned by Supabase missing_person_embeddings query
        ref_rows = [
            {
                "missing_person_id": self.person_id_1,
                "embedding": create_embedding_with_similarity(sighting_emb, 0.40),
            },
            {
                "missing_person_id": self.person_id_1,
                "embedding": create_embedding_with_similarity(sighting_emb, 0.81),
            },
            {
                "missing_person_id": self.person_id_2,
                "embedding": create_embedding_with_similarity(sighting_emb, 0.25),
            },
        ]

        results = match_sighting_against_cases([{"embedding": sighting_emb}], ref_rows)

        # Should produce 2 results: one for Person 1, one for Person 2
        self.assertEqual(len(results), 2)
        person_1_result = next(r for r in results if r["missing_person_id"] == self.person_id_1)
        self.assertAlmostEqual(person_1_result["similarity_score"], 0.81, places=3)
        self.assertEqual(person_1_result["match_category"], "match")

        person_2_result = next(r for r in results if r["missing_person_id"] == self.person_id_2)
        self.assertAlmostEqual(person_2_result["similarity_score"], 0.25, places=3)
        self.assertEqual(person_2_result["match_category"], "no_match")

    # -------------------------------------------------------------
    # 6. Exact Boundary and Threshold Behavior
    # -------------------------------------------------------------
    def test_boundary_scores_exact_thresholds(self):
        sighting_emb = self.base_emb_0

        # Create reference embeddings at exact thresholds
        exact_high = create_embedding_with_similarity(sighting_emb, 0.50)
        just_below_high = create_embedding_with_similarity(sighting_emb, 0.4999)
        exact_low = create_embedding_with_similarity(sighting_emb, 0.35)
        just_below_low = create_embedding_with_similarity(sighting_emb, 0.3499)

        cases = {
            "case_exact_high": [exact_high],
            "case_just_below_high": [just_below_high],
            "case_exact_low": [exact_low],
            "case_just_below_low": [just_below_low],
        }

        results = match_sighting_against_cases([{"embedding": sighting_emb}], cases)
        res_map = {r["missing_person_id"]: r for r in results}

        # 0.50 -> match
        self.assertEqual(res_map["case_exact_high"]["match_category"], "match")
        # 0.4999 -> potential_match
        self.assertEqual(res_map["case_just_below_high"]["match_category"], "potential_match")
        # 0.35 -> potential_match
        self.assertEqual(res_map["case_exact_low"]["match_category"], "potential_match")
        # 0.3499 -> no_match
        self.assertEqual(res_map["case_just_below_low"]["match_category"], "no_match")

    # -------------------------------------------------------------
    # 7. No Detected Faces and No Reference Profiles
    # -------------------------------------------------------------
    def test_empty_or_none_inputs_handled_safely(self):
        valid_faces = [{"face_index": 0, "embedding": self.base_emb_0}]
        valid_refs = {self.person_id_1: [self.base_emb_0]}

        # Empty sighting faces
        self.assertEqual(match_sighting_against_cases([], valid_refs), [])
        # None sighting faces
        self.assertEqual(match_sighting_against_cases(None, valid_refs), [])
        # Empty reference profiles list
        self.assertEqual(match_sighting_against_cases(valid_faces, []), [])
        # Empty reference profiles dict
        self.assertEqual(match_sighting_against_cases(valid_faces, {}), [])
        # None reference profiles
        self.assertEqual(match_sighting_against_cases(valid_faces, None), [])
        # Both empty
        self.assertEqual(match_sighting_against_cases([], []), [])
        # Both None
        self.assertEqual(match_sighting_against_cases(None, None), [])

    # -------------------------------------------------------------
    # 8. Invalid or Incorrectly Sized Embeddings Handled Safely
    # -------------------------------------------------------------
    def test_invalid_sighting_face_embeddings_skipped(self):
        valid_emb = self.base_emb_0
        valid_refs = {self.person_id_1: [valid_emb]}

        # Sighting face with wrong dimension (e.g. 10 instead of 512)
        results = match_sighting_against_cases(
            [{"face_index": 0, "embedding": [0.1] * 10}],
            valid_refs,
        )
        self.assertEqual(results, [])

        # Sighting face with None embedding
        results = match_sighting_against_cases(
            [{"face_index": 0, "embedding": None}],
            valid_refs,
        )
        self.assertEqual(results, [])

        # Sighting face with non-numeric string
        results = match_sighting_against_cases(
            [{"face_index": 0, "embedding": "bad_vector"}],
            valid_refs,
        )
        self.assertEqual(results, [])

        # Sighting face with all zeros (zero magnitude)
        results = match_sighting_against_cases(
            [{"face_index": 0, "embedding": [0.0] * EXPECTED_EMBEDDING_DIM}],
            valid_refs,
        )
        self.assertEqual(results, [])

    def test_mixed_valid_and_invalid_sighting_faces(self):
        valid_emb = self.base_emb_0
        valid_refs = {self.person_id_1: [create_embedding_with_similarity(valid_emb, 0.85)]}

        # Face 0 is invalid (length 10); Face 1 is valid (length 512)
        sighting_faces = [
            {"face_index": 0, "embedding": [0.1] * 10},
            {"face_index": 1, "embedding": valid_emb},
        ]

        results = match_sighting_against_cases(sighting_faces, valid_refs)

        # Invalid face 0 is skipped; valid face 1 is matched successfully
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["face_index"], 1)
        self.assertEqual(results[0]["match_category"], "match")
        self.assertAlmostEqual(results[0]["similarity_score"], 0.85, places=2)

    def test_invalid_reference_embeddings_skipped(self):
        sighting_faces = [{"face_index": 0, "embedding": self.base_emb_0}]
        valid_photo = create_embedding_with_similarity(self.base_emb_0, 0.70)

        # Person 1 has one invalid photo and one valid photo
        reference_profiles = {
            self.person_id_1: [
                [0.1] * 20,  # Invalid dimension
                valid_photo, # Valid 512-D photo
                None,        # Invalid None
            ]
        }

        results = match_sighting_against_cases(sighting_faces, reference_profiles)

        # Invalid photos skipped, valid photo evaluated without exception
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertEqual(results[0]["match_category"], "match")
        self.assertAlmostEqual(results[0]["similarity_score"], 0.70, places=2)

    def test_reference_case_with_only_invalid_photos(self):
        sighting_faces = [{"face_index": 0, "embedding": self.base_emb_0}]

        # Person 1 only has corrupt/invalid embeddings
        reference_profiles = {
            self.person_id_1: [[0.1] * 10, None, "bad_data"]
        }

        results = match_sighting_against_cases(sighting_faces, reference_profiles)
        self.assertEqual(results, [])

    # -------------------------------------------------------------
    # 9. Regression Tests for Targeted Audit Fixes
    # -------------------------------------------------------------
    def test_reference_profile_dict_single_flat_vector(self):
        """Fix 1: Dict with single flat 512-D list vector must not be dropped."""
        sighting_emb = self.base_emb_0
        ref_photo = create_embedding_with_similarity(sighting_emb, 0.77)

        # Value is directly a flat 512-D list (not nested in an outer list)
        reference_profiles = {self.person_id_1: ref_photo}

        results = match_sighting_against_cases([{"embedding": sighting_emb}], reference_profiles)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(results[0]["similarity_score"], 0.77, places=3)
        self.assertEqual(results[0]["match_category"], "match")

    def test_reference_profile_list_single_flat_embeddings_key(self):
        """Fix 1: Profile object with flat 512-D list under 'embeddings' must not be dropped."""
        sighting_emb = self.base_emb_0
        ref_photo = create_embedding_with_similarity(sighting_emb, 0.65)

        reference_profiles = [
            {"missing_person_id": self.person_id_1, "embeddings": ref_photo}
        ]

        results = match_sighting_against_cases([{"embedding": sighting_emb}], reference_profiles)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(results[0]["similarity_score"], 0.65, places=3)
        self.assertEqual(results[0]["match_category"], "match")

    def test_sighting_faces_single_raw_vector_list(self):
        """Fix 2: Single flat 512-D list passed as sighting_faces must be treated as 1 face."""
        sighting_emb = self.base_emb_0
        ref_photo = create_embedding_with_similarity(sighting_emb, 0.88)
        reference_profiles = {self.person_id_1: [ref_photo]}

        # sighting_faces is directly the 512-D list
        results = match_sighting_against_cases(sighting_emb, reference_profiles)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["face_index"], 0)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(results[0]["similarity_score"], 0.88, places=3)
        self.assertEqual(results[0]["match_category"], "match")

    def test_sighting_faces_single_raw_numpy_array(self):
        """Fix 2: Single 1D numpy array passed as sighting_faces must be treated as 1 face."""
        sighting_emb = np.asarray(self.base_emb_0, dtype=np.float32)
        ref_photo = create_embedding_with_similarity(sighting_emb, 0.72)
        reference_profiles = {self.person_id_1: [ref_photo]}

        results = match_sighting_against_cases(sighting_emb, reference_profiles)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["face_index"], 0)
        self.assertEqual(results[0]["missing_person_id"], self.person_id_1)
        self.assertAlmostEqual(results[0]["similarity_score"], 0.72, places=3)

    def test_equal_score_tie_deterministic_sorting(self):
        """Fix 3: When scores are identical, missing_person_id tie-breaker ensures deterministic ordering."""
        sighting_emb = self.base_emb_0
        # Both candidates have exact same similarity 0.75
        cand_score = 0.75
        ref_photo = create_embedding_with_similarity(sighting_emb, cand_score)

        # Intentionally insert "case_z" before "case_a"
        reference_profiles = {
            "case_z": [ref_photo],
            "case_a": [ref_photo],
        }

        results = match_sighting_against_cases([{"embedding": sighting_emb}], reference_profiles)
        self.assertEqual(len(results), 2)
        # Alphabetical tie-breaker: "case_a" must come before "case_z"
        self.assertEqual(results[0]["missing_person_id"], "case_a")
        self.assertEqual(results[1]["missing_person_id"], "case_z")
        self.assertEqual(results[0]["similarity_score"], results[1]["similarity_score"])

    def test_negative_zero_normalization(self):
        """Fix 4: Small negative scores near zero must normalize -0.0 to 0.0."""
        sighting_emb = self.base_emb_0
        # Target score that would round to -0.0
        near_zero_neg = create_embedding_with_similarity(sighting_emb, -0.00002)
        reference_profiles = {self.person_id_1: [near_zero_neg]}

        results = match_sighting_against_cases([{"embedding": sighting_emb}], reference_profiles)
        self.assertEqual(len(results), 1)
        score = results[0]["similarity_score"]
        self.assertEqual(score, 0.0)
        # Ensure it does not format as "-0.0" in string representation
        self.assertEqual(f"{score:.1f}", "0.0")
        self.assertEqual(str(score), "0.0")
        self.assertEqual(results[0]["match_category"], "no_match")

    def test_sighting_face_nan_vector_safely_skipped(self):
        """Ensure sighting face with NaN values is safely ignored in matching."""
        nan_vec = [0.1] * EXPECTED_EMBEDDING_DIM
        nan_vec[5] = float("nan")
        valid_refs = {self.person_id_1: [self.base_emb_0]}

        results = match_sighting_against_cases([{"face_index": 0, "embedding": nan_vec}], valid_refs)
        self.assertEqual(results, [])


if __name__ == "__main__":
    unittest.main()

