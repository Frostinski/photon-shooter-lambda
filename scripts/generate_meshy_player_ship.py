"""
Calls the Meshy.ai Image-to-3D API using MESHY_API_KEY from .env
to generate a 3D .glb model of the main player starfighter from the main menu image.
"""
import os
import sys
import time
import json
import base64
import urllib.request
import urllib.error

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(BASE_DIR, ".env")
MODELS_DIR = os.path.join(BASE_DIR, "PhotonShooter_Godot", "assets", "models")
REF_IMAGE_PATH = os.path.join(MODELS_DIR, "player_ship_menu_ref.png")
RAW_GLB_PATH = os.path.join(MODELS_DIR, "player_ship_meshy_raw.glb")
TASK_INFO_PATH = os.path.join(MODELS_DIR, "meshy_player_task.json")


def load_env_key(key_name: str) -> str:
    if os.path.exists(ENV_PATH):
        with open(ENV_PATH, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    if k.strip() == key_name:
                        return v.strip().strip('"').strip("'")
    return os.environ.get(key_name, "")


def api_request(method: str, url: str, api_key: str, payload: dict = None) -> dict:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"[Meshy API HTTP {e.code}]: {err_body}")
        raise


def download_file(url: str, dest_path: str) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            f.write(resp.read())


def main():
    api_key = load_env_key("MESHY_API_KEY")
    if not api_key:
        print("ERROR: MESHY_API_KEY not found in .env")
        sys.exit(1)

    os.makedirs(MODELS_DIR, exist_ok=True)

    # Check if we already have an active or completed task saved
    task_id = None
    if os.path.exists(TASK_INFO_PATH):
        try:
            with open(TASK_INFO_PATH, "r", encoding="utf-8") as f:
                saved = json.load(f)
                task_id = saved.get("task_id")
                if task_id:
                    print(f"Resuming existing Meshy task_id: {task_id}")
        except Exception:
            pass

    if not task_id:
        with open(REF_IMAGE_PATH, "rb") as f:
            b64_img = base64.b64encode(f.read()).decode("ascii")
        data_uri = f"data:image/png;base64,{b64_img}"

        payload = {
            "image_url": data_uri,
            "enable_pbr": True,
            "should_remesh": True,
            "should_texture": True,
        }
        print("Submitting Image-to-3D task to Meshy.ai...")
        res = api_request("POST", "https://api.meshy.ai/openapi/v1/image-to-3d", api_key, payload)
        task_id = res.get("result")
        print(f"Created Meshy Image-to-3D task: {task_id}")
        with open(TASK_INFO_PATH, "w", encoding="utf-8") as f:
            json.dump({"task_id": task_id}, f, indent=2)

    # Poll task until SUCCEEDED
    status_url = f"https://api.meshy.ai/openapi/v1/image-to-3d/{task_id}"
    while True:
        info = api_request("GET", status_url, api_key)
        status = info.get("status")
        progress = info.get("progress", 0)
        print(f"[Meshy Task {task_id}] Status: {status} | Progress: {progress}%", flush=True)

        if status == "SUCCEEDED":
            with open(TASK_INFO_PATH, "w", encoding="utf-8") as f:
                json.dump({"task_id": task_id, "info": info}, f, indent=2)
            glb_url = info.get("model_urls", {}).get("glb")
            if not glb_url:
                print("ERROR: No GLB URL in task response:", info)
                sys.exit(1)
            print(f"Downloading GLB model to {RAW_GLB_PATH}...")
            download_file(glb_url, RAW_GLB_PATH)
            thumb_url = info.get("thumbnail_url")
            if thumb_url:
                thumb_path = os.path.join(MODELS_DIR, "player_ship_meshy_thumb.png")
                download_file(thumb_url, thumb_path)
                print(f"Downloaded Meshy thumbnail to {thumb_path}")
            print(f"SUCCESS: Downloaded 3D model ({os.path.getsize(RAW_GLB_PATH)} bytes)")
            break
        elif status in ("FAILED", "CANCELED", "EXPIRED"):
            print(f"ERROR: Meshy task ended with status {status}: {info}")
            sys.exit(1)

        time.sleep(5)


if __name__ == "__main__":
    main()
