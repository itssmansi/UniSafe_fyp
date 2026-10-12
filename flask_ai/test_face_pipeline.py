from cv2 import normalize
import os
import sys
import cv2
import numpy as np

# ---------------------------------------------------------
# 2. Set Up Supabase client
# ---------------------------------------------------------

from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

supabase = create_client(supabase_url, supabase_key)
print("Supabase client created!")

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

# testing  embedding generation n cosine similarity
# img = cv2.imread("t1.jpeg")
# img_2 = cv2.imread("t2.jpeg")
# img_3 = cv2.imread("t3.jpeg")
# print(type(img))
# print(img.shape)

# faces = app.get(img)
# faces2 = app.get(img_2)
# faces3 = app.get(img_3)

# print(type(faces))
# print(len(faces))
# print(type(faces[0]))
# print(faces[0].embedding.shape)
# print(faces[0].embedding.dtype)

# embedding_length_1 = np.linalg.norm(faces[0].embedding)
# normalized_embedding_1 = faces[0].embedding / embedding_length_1

# embedding_length_2 = np.linalg.norm(faces2[0].embedding)
# normalized_embedding_2 = faces2[0].embedding / embedding_length_2

# embedding_length_3 = np.linalg.norm(faces3[0].embedding)
# normalized_embedding_3 = faces3[0].embedding / embedding_length_3

# similarity = np.dot(normalized_embedding_1, normalized_embedding_2)
# print(similarity)
# print(type(similarity))

# similarity_scores = {}
# embedding_list = {
#     "t2.jpeg": normalized_embedding_2,
#     "t3.jpeg": normalized_embedding_3
# }

# for image, embedding in embedding_list.items():
#     # print(image, embedding.shape)
#     similarity = np.dot(embedding, normalized_embedding_1)
#     similarity_scores[image] = similarity

# max_score = max(similarity_scores.values())
# for image, score in similarity_scores.items():
#     if score == max_score:
#         print(image, score)
#         break


# embedding_list = [normalized_embedding_2, normalized_embedding_3]
# for embedding in embedding_list:
#     similarity = np.dot(embedding, normalized_embedding_1)
#     similarity_scores.append(similarity)

# best_index = similarity_scores.index(max(similarity_scores))
# print(best_index)

image_path = r"D:\UniSafe_fyp\flask_ai\test_images\missing_people\MP002\photo_2.jpeg"
img = cv2.imread(image_path)
face = app.get(img)
det_score = float(face[0].det_score)

L2_norm = np.linalg.norm(face[0].embedding)
normalized_embedding = face[0].embedding / L2_norm
normalized_embedding_magnitude = np.linalg.norm(normalized_embedding)

normalized_embedding = normalized_embedding.tolist()
# print(type(normalized_embedding))
# print(len(normalized_embedding))

photo_2_data ={
        "image_path": "missing_people/MP002/photo_2.jpeg",
        "embedding": normalized_embedding,
        "det_score": det_score
}

# to add embedding
response = (
    supabase
    .table("missing_persons")
    .select("face_data")
    .eq("id", "3b894708-4b88-47e1-aa3a-4e5681688a60")
    .execute()
)

existing_face_data = response.data[0]["face_data"]
# print(type(existing_face_data))
# print(len(existing_face_data))

existing_face_data.append(photo_2_data)
print(len(existing_face_data))
print(existing_face_data[0]["image_path"])
print(existing_face_data[1]["image_path"])
print(len(existing_face_data[1]["embedding"]))
print(existing_face_data[1]["det_score"])

update_new_embedding_response = (
    supabase
    .table("missing_persons")
    .update({"face_data": existing_face_data})
    .eq("id", "3b894708-4b88-47e1-aa3a-4e5681688a60")
    .execute()
)



# update_response = (
#     supabase
#     .table("missing_persons")
#     .update({"face_data": face_data})
#     .eq("id", "3b894708-4b88-47e1-aa3a-4e5681688a60")
#     .execute()
# )

print(update_new_embedding_response.data)

verify = (
    supabase
    .table("missing_persons")
    .select("id, full_name, face_data")
    .eq("id", "3b894708-4b88-47e1-aa3a-4e5681688a60")
    .execute()
)

stored_face_data = verify.data[0]["face_data"]

print("Number of stored faces:", len(stored_face_data))
print("Image path:", stored_face_data[0]["image_path"])
print("Image path:", stored_face_data[1]["image_path"])
print("Embedding length:", len(stored_face_data[0]["embedding"]))
print("Embedding length:", len(stored_face_data[1]["embedding"]))
print("Detection score:", stored_face_data[0]["det_score"])
print("Detection score:", stored_face_data[1]["det_score"])