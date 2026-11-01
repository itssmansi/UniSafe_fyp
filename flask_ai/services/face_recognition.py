import os
import sys
from typing import Any, Dict, List, Optional, Union
import cv2
import numpy as np
import onnxruntime as ort
from insightface.app import FaceAnalysis

# Force UTF-8 stdout encoding for Windows CLI
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# ---------------------------------------------------------
# CUDA & cuDNN DLL Path Configuration for Windows
# ---------------------------------------------------------
BASE_DIR = os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))
)
VENV_SITE_PACKAGES = os.path.join(BASE_DIR, "venv", "Lib", "site-packages")

NVIDIA_DLL_DIRS = [
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cuda_runtime", "bin"),
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cudnn", "bin"),
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cublas", "bin"),
]

for dll_dir in NVIDIA_DLL_DIRS:
    if os.path.exists(dll_dir):
        os.environ["PATH"] = dll_dir + os.path.pathsep + os.environ["PATH"]
        if hasattr(os, "add_dll_directory"):
            try:
                os.add_dll_directory(dll_dir)
            except Exception as e:
                print(f"[Warning] Could not add DLL directory {dll_dir}: {e}")

try:
    ort.preload_dlls()
except Exception:
    pass

_app_instance = None

def get_face_analysis_app():
    """
    Initializes and returns the singleton InsightFace FaceAnalysis application configured for GPU execution.

    Inputs: None
    Returns: FaceAnalysis object (buffalo_l model pack running on CUDAExecutionProvider with CPU fallback)
    Why needed: Reuses the exact working GPU configuration across reference processing and sightings analysis,
                preventing redundant model loading and memory duplication.
    """
    global _app_instance
    if _app_instance is None:
        print("[+] Initializing InsightFace (buffalo_l model packs on GPU)...")
        _app_instance = FaceAnalysis(
            name="buffalo_l",
            providers=["CUDAExecutionProvider", "CPUExecutionProvider"]
        )
        _app_instance.prepare(ctx_id=0, det_size=(640, 640))
        print("[+] InsightFace loaded successfully on GPU!\n")
    return _app_instance


def normalize_embedding(embedding: np.ndarray) -> np.ndarray:
    """
    Applies L2 normalization to a face embedding vector.

    Inputs:
        embedding (np.ndarray): 512-dimensional raw face embedding vector.
    Returns:
        np.ndarray: L2 normalized 512-dimensional unit vector.
    Why needed: L2 normalization simplifies cosine similarity calculation to a simple dot product
                and standardizes vector magnitudes across different images and lighting conditions.
    """
    norm = np.linalg.norm(embedding)
    if norm == 0:
        return embedding
    return embedding / norm




def extract_reference_face_from_image(img: np.ndarray):
    """Extract an embedding only when exactly one face is detected."""
    if img is None or not isinstance(img, np.ndarray) or img.size == 0:
        raise ValueError("Invalid or empty image")

    app = get_face_analysis_app()
    faces = app.get(img)
    face_count = len(faces)

    if face_count == 0:
        return None, None, 0

    if face_count > 1:
        return None, None, face_count

    face = faces[0]
    embedding = normalize_embedding(face.embedding)

    return embedding.tolist(), float(face.det_score), face_count


def extract_reference_face(image_path: str):
    """Compatibility wrapper for existing callers that use image paths."""
    if not os.path.exists(image_path):
        print(f"[FAIL] Image file not found: {image_path}")
        return None, None, 0

    img = cv2.imread(image_path)
    if img is None:
        print(f"[FAIL] Failed to decode image: {image_path}")
        return None, None, 0

    return extract_reference_face_from_image(img)


def extract_all_sighting_faces_from_image(img: np.ndarray):
    """Extract normalized embeddings and metadata for every face in an image."""
    if img is None or not isinstance(img, np.ndarray) or img.size == 0:
        raise ValueError("Invalid or empty image")

    app = get_face_analysis_app()
    faces = app.get(img)

    sighting_faces = []

    for idx, face in enumerate(faces):
        embedding = normalize_embedding(face.embedding)

        sighting_faces.append({
            "face_index": idx,
            "embedding": embedding.tolist(),
            "bbox": [float(coord) for coord in face.bbox],
            "det_score": float(face.det_score),
        })

    return sighting_faces


def extract_all_sighting_faces(image_path: str):
    """Compatibility wrapper for existing callers that use image paths."""
    if not os.path.exists(image_path):
        print(f"[FAIL] Image file not found: {image_path}")
        return []

    img = cv2.imread(image_path)
    if img is None:
        print(f"[FAIL] Failed to decode image: {image_path}")
        return []

    return extract_all_sighting_faces_from_image(img)


def compute_cosine_similarity(emb1: np.ndarray, emb2: np.ndarray) -> float:
    """
    Computes Cosine Similarity between two L2-normalized 512-D vectors via dot product.

    Inputs:
        emb1 (np.ndarray): L2-normalized 512-D vector.
        emb2 (np.ndarray): L2-normalized 512-D vector.
    Returns:
        float: Cosine similarity score in range [-1.0, 1.0].
    Why needed: Used to quantify facial feature vector similarity between sighting faces and reference profiles.
    """
    return float(np.dot(emb1, emb2))


def categorize_similarity(score: float, high_thresh: float = 0.50, low_thresh: float = 0.35) -> str:
    """
    Categorizes similarity score into match status labels.

    Inputs:
        score (float): Calculated cosine similarity score.
        high_thresh (float): Threshold for strong match (default 0.50).
        low_thresh (float): Threshold for potential match (default 0.35).
    Returns:
        str: Status category ("match", "potential_match", or "no_match").
    Why needed: Provides a configurable, structured classification for AI match outputs.
    """
    if score >= high_thresh:
        return "match"
    elif score >= low_thresh:
        return "potential_match"
    else:
        return "no_match"


# ---------------------------------------------------------
# Sighting-to-Reference Case Matching Service
# ---------------------------------------------------------
EXPECTED_EMBEDDING_DIM = 512
DEFAULT_HIGH_MATCH_THRESHOLD = 0.50
DEFAULT_LOW_MATCH_THRESHOLD = 0.35


def validate_and_normalize_embedding(
    embedding: Any,
    expected_dim: int = EXPECTED_EMBEDDING_DIM,
) -> Optional[np.ndarray]:
    """
    Safely validates, parses, and normalizes a face embedding vector.

    Inputs:
        embedding: Raw embedding as list, tuple, np.ndarray, or serialized string.
        expected_dim (int): Expected vector length (default 512).
    Returns:
        Optional[np.ndarray]: L2-normalized 1D float32 numpy array, or None if invalid.
    Why needed: Guards against malformed, corrupted, empty, NaN, or incorrectly sized
                embeddings from external inputs or database records without crashing.
    """
    if embedding is None:
        return None

    try:
        if isinstance(embedding, str):
            cleaned = embedding.strip().lstrip("[").rstrip("]").strip()
            if not cleaned:
                return None
            arr = np.fromstring(cleaned, sep=",", dtype=np.float32)
        elif isinstance(embedding, (list, tuple, np.ndarray)):
            arr = np.asarray(embedding, dtype=np.float32)
        else:
            return None

        # Squeeze potential batch/singleton dimensions (e.g. (1, 512) -> (512,))
        if arr.ndim > 1:
            arr = np.squeeze(arr)

        if arr.ndim != 1 or arr.size != expected_dim:
            return None

        if not np.isfinite(arr).all():
            return None

        norm = float(np.linalg.norm(arr))
        if norm <= 1e-7 or not np.isfinite(norm):
            return None

        # Reuse existing normalize_embedding logic if not already a unit vector
        if abs(norm - 1.0) > 1e-4:
            arr = normalize_embedding(arr)

        return arr.astype(np.float32)

    except Exception:
        return None


def _group_reference_profiles(
    reference_profiles: Any,
    expected_dim: int = EXPECTED_EMBEDDING_DIM,
) -> Dict[str, List[np.ndarray]]:
    """
    Groups and validates reference profiles into a mapping of {person_id: [valid_embeddings]}.
    Accepts dictionaries, lists of case profiles, or flat embedding rows.
    """
    grouped: Dict[str, List[np.ndarray]] = {}

    if reference_profiles is None:
        return grouped

    try:
        if len(reference_profiles) == 0:
            return grouped
    except TypeError:
        return grouped

    def add_embedding(pid: str, raw_emb: Any):
        valid = validate_and_normalize_embedding(raw_emb, expected_dim=expected_dim)
        if valid is not None:
            grouped.setdefault(pid, []).append(valid)

    if isinstance(reference_profiles, dict):
        for raw_pid, items in reference_profiles.items():
            if not raw_pid:
                continue
            pid_str = str(raw_pid).strip()
            if not pid_str:
                continue
            if isinstance(items, dict):
                add_embedding(pid_str, items.get("embedding"))
            elif validate_and_normalize_embedding(items, expected_dim=expected_dim) is not None:
                # Direct single embedding vector (list/tuple/ndarray/string)
                add_embedding(pid_str, items)
            elif isinstance(items, (list, tuple)):
                for item in items:
                    if isinstance(item, dict):
                        add_embedding(pid_str, item.get("embedding"))
                    else:
                        add_embedding(pid_str, item)
            else:
                add_embedding(pid_str, items)

    elif isinstance(reference_profiles, (list, tuple)):
        for entry in reference_profiles:
            if not isinstance(entry, dict):
                continue
            raw_pid = (
                entry.get("missing_person_id")
                or entry.get("person_id")
                or entry.get("id")
            )
            if not raw_pid:
                continue
            pid_str = str(raw_pid).strip()
            if not pid_str:
                continue

            if "embeddings" in entry:
                raw_val = entry["embeddings"]
                if validate_and_normalize_embedding(raw_val, expected_dim=expected_dim) is not None:
                    add_embedding(pid_str, raw_val)
                elif isinstance(raw_val, (list, tuple)):
                    for raw_emb in raw_val:
                        if isinstance(raw_emb, dict):
                            add_embedding(pid_str, raw_emb.get("embedding"))
                        else:
                            add_embedding(pid_str, raw_emb)
                else:
                    add_embedding(pid_str, raw_val)
            elif "photos" in entry and isinstance(entry["photos"], (list, tuple)):
                for photo in entry["photos"]:
                    if isinstance(photo, dict):
                        add_embedding(pid_str, photo.get("embedding"))
                    else:
                        add_embedding(pid_str, photo)
            elif "face_data" in entry and isinstance(entry["face_data"], (list, tuple)):
                for fd in entry["face_data"]:
                    if isinstance(fd, dict):
                        add_embedding(pid_str, fd.get("embedding"))
                    else:
                        add_embedding(pid_str, fd)
            elif "embedding" in entry:
                add_embedding(pid_str, entry.get("embedding"))

    return grouped


def match_sighting_against_cases(
    sighting_faces: Any,
    reference_profiles: Any,
    high_thresh: float = DEFAULT_HIGH_MATCH_THRESHOLD,
    low_thresh: float = DEFAULT_LOW_MATCH_THRESHOLD,
    include_no_match: bool = True,
    top_k_per_face: Optional[int] = None,
    expected_dim: int = EXPECTED_EMBEDDING_DIM,
) -> List[Dict[str, Any]]:
    """
    Compares detected sighting faces against missing-person reference profile embeddings.

    Inputs:
        sighting_faces: List of sighting face dictionaries (with 'face_index' and 'embedding')
                        or single face dict.
        reference_profiles: Reference profiles (dict of person_id -> embeddings, or list of
                            profiles/records with person_id and embedding(s)).
        high_thresh (float): Threshold for strong match (default 0.50).
        low_thresh (float): Threshold for potential match (default 0.35).
        include_no_match (bool): If True, retains 'no_match' evaluations; if False, returns only
                                 'match' and 'potential_match' (default True).
        top_k_per_face (Optional[int]): If specified, limits results to the top K best-matching
                                        cases per sighting face.
        expected_dim (int): Expected vector dimension (default 512).

    Returns:
        List[Dict[str, Any]]: Structured match results where each item contains:
            - face_index (int): Sighting face index
            - missing_person_id (str): Missing person identifier
            - similarity_score (float): Highest cosine similarity across that person's reference photos
            - match_category (str): "match", "potential_match", or "no_match"
            - status (str): Alias of match_category for database schema compatibility
            (No raw embeddings are included in returned results)

    Why needed: Provides a pure, decoupled AI matching service supporting multi-face sightings
                and multi-photo reference profiles with configurable thresholds.
    """
    if sighting_faces is None or reference_profiles is None:
        return []

    try:
        if len(sighting_faces) == 0 or len(reference_profiles) == 0:
            return []
    except TypeError:
        return []

    # Normalize sighting_faces into list of dicts
    if isinstance(sighting_faces, dict):
        faces_list = [sighting_faces]
    elif validate_and_normalize_embedding(sighting_faces, expected_dim=expected_dim) is not None:
        # A single raw 512-D vector passed directly as a list/array
        faces_list = [{"face_index": 0, "embedding": sighting_faces}]
    elif isinstance(sighting_faces, (list, tuple)):
        faces_list = list(sighting_faces)
    else:
        return []

    # Group and validate reference embeddings by missing_person_id
    grouped_references = _group_reference_profiles(
        reference_profiles,
        expected_dim=expected_dim
    )
    if not grouped_references:
        return []

    all_matches: List[Dict[str, Any]] = []

    for idx, face_entry in enumerate(faces_list):
        if isinstance(face_entry, dict):
            raw_index = face_entry.get("face_index", idx)
            raw_emb = face_entry.get("embedding")
        else:
            raw_index = idx
            raw_emb = face_entry

        try:
            face_index = int(raw_index)
        except (ValueError, TypeError):
            face_index = idx

        sighting_emb = validate_and_normalize_embedding(
            raw_emb,
            expected_dim=expected_dim
        )
        if sighting_emb is None:
            # Skip invalid or incorrectly sized face embeddings safely
            continue

        face_case_matches: List[Dict[str, Any]] = []

        for person_id, ref_embeddings in grouped_references.items():
            if not ref_embeddings:
                continue

            # Compare against all reference photos for this case and retain the highest score
            case_scores = [
                compute_cosine_similarity(sighting_emb, ref_emb)
                for ref_emb in ref_embeddings
            ]
            best_score = max(case_scores)

            # Bound score to [-1.0, 1.0] and round to 4 decimal places
            clamped_score = max(-1.0, min(1.0, float(best_score)))
            rounded_score = round(clamped_score, 4)
            if rounded_score == 0.0:
                rounded_score = 0.0

            category = categorize_similarity(
                rounded_score,
                high_thresh=high_thresh,
                low_thresh=low_thresh
            )

            if not include_no_match and category == "no_match":
                continue

            face_case_matches.append({
                "face_index": face_index,
                "missing_person_id": person_id,
                "similarity_score": rounded_score,
                "match_category": category,
                "status": category,
            })

        # Sort this face's candidate matches by similarity score descending, with person_id as tie-breaker
        face_case_matches.sort(
            key=lambda m: (-m["similarity_score"], str(m["missing_person_id"]))
        )

        if top_k_per_face is not None and top_k_per_face > 0:
            face_case_matches = face_case_matches[:top_k_per_face]

        all_matches.extend(face_case_matches)

    # Sort final list by face_index ascending, then similarity_score descending, with person_id as tie-breaker
    all_matches.sort(
        key=lambda m: (m["face_index"], -m["similarity_score"], str(m["missing_person_id"]))
    )

    return all_matches

