import os
import sys
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
