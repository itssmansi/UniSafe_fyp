import os
import sys
import cv2
import numpy as np

# Force UTF-8 encoding for standard output on Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# ---------------------------------------------------------
# 1. Automatic CUDA & cuDNN DLL Path Configuration
# ---------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
VENV_SITE_PACKAGES = os.path.join(BASE_DIR, "venv", "Lib", "site-packages")

NVIDIA_DLL_DIRS = [
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cuda_runtime", "bin"),
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cudnn", "bin"),
    os.path.join(VENV_SITE_PACKAGES, "nvidia", "cublas", "bin"),
]

for dll_dir in NVIDIA_DLL_DIRS:
    if os.path.exists(dll_dir):
        # Prepend to system PATH for Windows DLL resolution
        os.environ["PATH"] = dll_dir + os.path.pathsep + os.environ["PATH"]
        # Python 3.8+ Windows DLL directory addition
        if hasattr(os, "add_dll_directory"):
            try:
                os.add_dll_directory(dll_dir)
            except Exception as e:
                print(f"[Warning] Failed to add DLL dir {dll_dir}: {e}")

import onnxruntime as ort
try:
    ort.preload_dlls()
except Exception:
    pass

print("=" * 70)
print("UniSafe - 1:1 Face Verification & Matching System")
print("Available ONNX Execution Providers:", ort.get_available_providers())
print("=" * 70)

from insightface.app import FaceAnalysis

# ---------------------------------------------------------
# 2. Initialize InsightFace Model (buffalo_l with GPU)
# ---------------------------------------------------------
print("\n[+] Initializing InsightFace (buffalo_l model packs)...")
app = FaceAnalysis(
    name="buffalo_l",
    providers=["CUDAExecutionProvider", "CPUExecutionProvider"]
)
app.prepare(ctx_id=0, det_size=(640, 640))
print("[+] InsightFace loaded successfully on GPU!\n")

# ---------------------------------------------------------
# 3. Helper Functions
# ---------------------------------------------------------
def extract_face_embedding(image_path):
    """
    Loads an image, detects faces, and returns the normalized 512-D embedding 
    of the primary (largest) detected face.
    """
    if not os.path.exists(image_path):
        raise FileNotFoundError(f"Image not found at path: {image_path}")

    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Failed to decode image: {image_path}")

    faces = app.get(img)
    
    if len(faces) == 0:
        print(f"[FAIL] No face detected in: {os.path.basename(image_path)}")
        return None, None
    
    # Sort faces by bounding box area to select the primary subject
    faces = sorted(faces, key=lambda x: (x.bbox[2] - x.bbox[0]) * (x.bbox[3] - x.bbox[1]), reverse=True)
    primary_face = faces[0]
    
    raw_embedding = primary_face.embedding
    # Normalize 512-D embedding vector to unit length (L2 norm)
    norm_embedding = raw_embedding / np.linalg.norm(raw_embedding)
    
    print(f"[OK] Face detected in {os.path.basename(image_path)} (Detection Score: {primary_face.det_score:.2f}, Vector Dim: {len(norm_embedding)})")
    return norm_embedding, img

def compute_cosine_similarity(emb1, emb2):
    """
    Computes Cosine Similarity between two normalized 512-D embeddings.
    Range: -1.0 to 1.0 (Higher = more similar).
    """
    return np.dot(emb1, emb2)

def compute_euclidean_distance(emb1, emb2):
    """
    Computes Euclidean (L2) Distance between two normalized 512-D embeddings.
    Lower = more similar.
    """
    return np.linalg.norm(emb1 - emb2)

def categorize_match(similarity_score, high_thresh=0.50, low_thresh=0.35):
    """
    Decision structure for UniSafe missing person matching:
    - >= 0.50: Strong Match (High Confidence)
    - 0.35 to 0.49: Moderate Match (Requires Admin / Human Verification)
    - < 0.35: No Match (Different Individuals)
    """
    if similarity_score >= high_thresh:
        return "STRONG MATCH (High Confidence)", "MATCH"
    elif similarity_score >= low_thresh:
        return "MODERATE MATCH (Requires Human Verification)", "POTENTIAL MATCH"
    else:
        return "NO MATCH (Different Individuals)", "NO MATCH"

# ---------------------------------------------------------
# 4. Main 1:1 Face Matching Test Routine
# ---------------------------------------------------------
# ---------------------------------------------------------
# 4. Missing Person vs Sighting Matching Test Routine
# ---------------------------------------------------------
def get_image_files(folder):
    """
    Returns all supported image files inside a folder.
    """
    supported_extensions = (".jpg", ".jpeg", ".png", ".webp")

    if not os.path.exists(folder):
        return []

    return [
        os.path.join(folder, filename)
        for filename in os.listdir(folder)
        if filename.lower().endswith(supported_extensions)
    ]


def run_missing_person_tests():
    test_dir = os.path.join(BASE_DIR, "test_images")

    missing_people_dir = os.path.join(test_dir, "missing_people")
    sightings_dir = os.path.join(test_dir, "sightings")

    print("-" * 70)
    print("STEP 1: Loading Missing Person Reference Images")
    print("-" * 70)

    # -----------------------------------------------------
    # Load missing person reference images
    # -----------------------------------------------------
    missing_people = {}

    if not os.path.exists(missing_people_dir):
        print(f"[FAIL] Missing people directory not found:")
        print(f"       {missing_people_dir}")
        return

    for person_id in sorted(os.listdir(missing_people_dir)):
        person_dir = os.path.join(missing_people_dir, person_id)

        if not os.path.isdir(person_dir):
            continue

        image_files = get_image_files(person_dir)

        if len(image_files) == 0:
            print(f"[WARNING] No images found for {person_id}")
            continue

        missing_people[person_id] = image_files

        print(f"\n[+] {person_id}")
        print(f"    Reference Images: {len(image_files)}")

        for image_path in image_files:
            print(f"      - {os.path.basename(image_path)}")

    if len(missing_people) == 0:
        print("\n[FAIL] No missing person reference images found.")
        return

    # -----------------------------------------------------
    # Load sighting images
    # -----------------------------------------------------
    sighting_files = get_image_files(sightings_dir)

    print("\n" + "-" * 70)
    print("STEP 2: Loading Sighting Images")
    print("-" * 70)

    if len(sighting_files) == 0:
        print(f"[FAIL] No sighting images found in:")
        print(f"       {sightings_dir}")
        return

    for sighting in sighting_files:
        print(f"[+] {os.path.basename(sighting)}")

    # -----------------------------------------------------
    # Extract embeddings for missing people
    # -----------------------------------------------------
    print("\n" + "-" * 70)
    print("STEP 3: Extracting Missing Person Embeddings")
    print("-" * 70)

    missing_embeddings = {}

    for person_id, image_files in missing_people.items():

        person_embeddings = []

        print(f"\n[{person_id}]")

        for image_path in image_files:

            embedding, _ = extract_face_embedding(image_path)

            if embedding is not None:
                person_embeddings.append(embedding)

        if len(person_embeddings) > 0:
            missing_embeddings[person_id] = person_embeddings

            print(
                f"    [OK] {len(person_embeddings)} "
                f"valid face embedding(s) stored."
            )
        else:
            print(
                f"    [FAIL] No valid face embeddings for {person_id}"
            )

    if len(missing_embeddings) == 0:
        print("\n[FAIL] Could not extract any missing person embeddings.")
        return

    # -----------------------------------------------------
    # STEP 4: Match every sighting against every person
    # -----------------------------------------------------
    print("\n" + "=" * 70)
    print("STEP 4: MISSING PERSON vs SIGHTING MATCHING")
    print("=" * 70)

    for sighting_path in sighting_files:

        sighting_name = os.path.basename(sighting_path)

        print("\n" + "-" * 70)
        print(f"SIGHTING: {sighting_name}")
        print("-" * 70)

        sighting_embedding, _ = extract_face_embedding(sighting_path)

        if sighting_embedding is None:
            print("[FAIL] No face detected in this sighting.")
            continue

        best_person = None
        best_similarity = -1.0
        best_distance = None

        # -------------------------------------------------
        # Compare sighting with every missing person
        # -------------------------------------------------
        for person_id, person_embeddings in missing_embeddings.items():

            person_best_similarity = -1.0
            person_best_distance = None

            for reference_embedding in person_embeddings:

                similarity = compute_cosine_similarity(
                    reference_embedding,
                    sighting_embedding
                )

                distance = compute_euclidean_distance(
                    reference_embedding,
                    sighting_embedding
                )

                # Keep the best reference image for this person
                if similarity > person_best_similarity:
                    person_best_similarity = similarity
                    person_best_distance = distance

            print(
                f"    {person_id} -> "
                f"Similarity: {person_best_similarity:.4f} | "
                f"Distance: {person_best_distance:.4f}"
            )

            # -------------------------------------------------
            # Keep the overall best person
            # -------------------------------------------------
            if person_best_similarity > best_similarity:
                best_similarity = person_best_similarity
                best_distance = person_best_distance
                best_person = person_id

        # -----------------------------------------------------
        # Make final decision
        # -----------------------------------------------------
        match_desc, status = categorize_match(best_similarity)

        print("\n    BEST MATCH")
        print(f"    Missing Person        : {best_person}")
        print(f"    Cosine Similarity     : {best_similarity:.4f}")
        print(f"    Euclidean Distance    : {best_distance:.4f}")
        print(f"    UniSafe AI Decision   : [{status}]")
        print(f"    Interpretation        : {match_desc}")

    # -----------------------------------------------------
    # Decision Matrix
    # -----------------------------------------------------
    print("\n" + "=" * 70)
    print("UniSafe MISSING PERSON DECISION MATRIX & THRESHOLDS:")
    print("  • Similarity >= 0.50 : Strong Match")
    print("                           -> High Confidence")
    print("  • 0.35 <= Sim < 0.50 : Potential Match")
    print("                           -> Human/Admin Verification")
    print("  • Similarity < 0.35  : No Match")
    print("                           -> Different Individual")
    print("=" * 70)


# ---------------------------------------------------------
# 5. Program Entry Point
# ---------------------------------------------------------
if __name__ == "__main__":
    run_missing_person_tests()

