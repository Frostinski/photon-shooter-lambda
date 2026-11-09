"""
Submits Image-to-3D tasks to Meshy.ai for the enemy fleet:
  1. Scout (smaller grey craft) -> enemy_scout_meshy_raw.glb
  2. Interceptor / Raider (streamlined crescent gull-wing purple/crimson craft) -> enemy_raider_meshy_raw.glb
  3. Destroyer / Dreadnought (streamlined royal-purple shark-prow warship) -> boss_dreadnought_meshy_raw.glb
  4. Final Ship / Boss Titan (streamlined royal-purple multi-turret flagship) -> boss_titan_meshy_raw.glb

Supports:
  --force                         Regenerate all 4 ships
  --regen=key1,key2,...           Regenerate only the specified ship keys
Uses clean quad topology (target_polycount=6000) so generated hulls have smooth, clutter-free geometry.
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
TASKS_JSON = os.path.join(MODELS_DIR, "meshy_enemies_tasks.json")

ENEMY_SPECS = [
    {
        "key": "enemy_scout",
        "ref_png": "enemy_scout_menu_ref.png",
        "raw_glb": "enemy_scout_meshy_raw.glb",
        "thumb_png": "enemy_scout_meshy_thumb.png",
        "topology": "quad",
        "target_polycount": 6000,
    },
    {
        "key": "enemy_raider",
        "ref_png": "enemy_raider_menu_ref.png",
        "raw_glb": "enemy_raider_meshy_raw.glb",
        "thumb_png": "enemy_raider_meshy_thumb.png",
        "topology": "quad",
        "target_polycount": 6000,
    },
    {
        "key": "boss_dreadnought",
        "ref_png": "boss_dreadnought_menu_ref.png",
        "raw_glb": "boss_dreadnought_meshy_raw.glb",
        "thumb_png": "boss_dreadnought_meshy_thumb.png",
        "topology": "quad",
        "target_polycount": 6000,
    },
    {
        "key": "boss_titan",
        "ref_png": "boss_titan_menu_ref.png",
        "raw_glb": "boss_titan_meshy_raw.glb",
        "thumb_png": "boss_titan_meshy_thumb.png",
        "topology": "quad",
        "target_polycount": 7500,
    },
]


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
        print(f"[Meshy API HTTP {e.code}]: {err_body}", flush=True)
        raise


def download_file(url: str, dest_path: str) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        with open(dest_path, "wb") as f:
            f.write(resp.read())


def main():
    force_all = "--force" in sys.argv
    regen_keys = set()
    for arg in sys.argv[1:]:
        if arg.startswith("--regen="):
            regen_keys.update(k.strip() for k in arg.split("=", 1)[1].split(",") if k.strip())

    api_key = load_env_key("MESHY_API_KEY")
    if not api_key:
        print("ERROR: MESHY_API_KEY not found in .env", flush=True)
        sys.exit(1)

    os.makedirs(MODELS_DIR, exist_ok=True)
    saved_tasks = {}
    if os.path.exists(TASKS_JSON):
        try:
            with open(TASKS_JSON, "r", encoding="utf-8") as f:
                saved_tasks = json.load(f)
        except Exception:
            saved_tasks = {}

    if force_all:
        regen_keys = {s["key"] for s in ENEMY_SPECS}

    if regen_keys:
        for spec in ENEMY_SPECS:
            if spec["key"] in regen_keys:
                saved_tasks.pop(spec["key"], None)
                for k_file in ("raw_glb", "thumb_png"):
                    fp = os.path.join(MODELS_DIR, spec[k_file])
                    if os.path.exists(fp):
                        os.remove(fp)
        with open(TASKS_JSON, "w", encoding="utf-8") as f:
            json.dump(saved_tasks, f, indent=2)
        print(f"[Meshy] Cleared cached raw GLBs/tasks for: {sorted(regen_keys)}", flush=True)

    # 1. Submit any tasks not yet created
    for spec in ENEMY_SPECS:
        key = spec["key"]
        raw_glb_path = os.path.join(MODELS_DIR, spec["raw_glb"])
        if os.path.exists(raw_glb_path) and os.path.getsize(raw_glb_path) > 10000:
            print(f"[{key}] Raw GLB already exists ({os.path.getsize(raw_glb_path)} bytes), skipping submit.", flush=True)
            continue

        task_id = saved_tasks.get(key, {}).get("task_id")
        if task_id:
            print(f"[{key}] Resuming existing Meshy task_id: {task_id}", flush=True)
            continue

        ref_path = os.path.join(MODELS_DIR, spec["ref_png"])
        with open(ref_path, "rb") as f:
            b64_img = base64.b64encode(f.read()).decode("ascii")
        payload = {
            "image_url": f"data:image/png;base64,{b64_img}",
            "enable_pbr": True,
            "should_remesh": True,
            "should_texture": True,
            "topology": spec.get("topology", "quad"),
            "target_polycount": spec.get("target_polycount", 6000),
        }
        print(f"[{key}] Submitting Image-to-3D task (topology={payload['topology']}, polycount={payload['target_polycount']})...", flush=True)
        res = api_request("POST", "https://api.meshy.ai/openapi/v1/image-to-3d", api_key, payload)
        task_id = res.get("result")
        print(f"[{key}] Created Meshy task: {task_id}", flush=True)
        saved_tasks[key] = {"task_id": task_id, "status": "PENDING"}
        with open(TASKS_JSON, "w", encoding="utf-8") as f:
            json.dump(saved_tasks, f, indent=2)
        time.sleep(1.0)

    # 2. Poll all active tasks until all succeed
    pending_keys = [
        spec["key"]
        for spec in ENEMY_SPECS
        if not (os.path.exists(os.path.join(MODELS_DIR, spec["raw_glb"])) and os.path.getsize(os.path.join(MODELS_DIR, spec["raw_glb"])) > 10000)
    ]

    spec_by_key = {s["key"]: s for s in ENEMY_SPECS}

    while pending_keys:
        still_pending = []
        for key in pending_keys:
            spec = spec_by_key[key]
            task_id = saved_tasks[key]["task_id"]
            status_url = f"https://api.meshy.ai/openapi/v1/image-to-3d/{task_id}"
            info = api_request("GET", status_url, api_key)
            status = info.get("status")
            progress = info.get("progress", 0)
            print(f"[{key} | {task_id}] Status: {status} | Progress: {progress}%", flush=True)

            if status == "SUCCEEDED":
                saved_tasks[key]["status"] = "SUCCEEDED"
                saved_tasks[key]["info"] = info
                with open(TASKS_JSON, "w", encoding="utf-8") as f:
                    json.dump(saved_tasks, f, indent=2)

                glb_url = info.get("model_urls", {}).get("glb")
                raw_glb_path = os.path.join(MODELS_DIR, spec["raw_glb"])
                print(f"[{key}] Downloading GLB to {raw_glb_path}...", flush=True)
                download_file(glb_url, raw_glb_path)

                thumb_url = info.get("thumbnail_url")
                if thumb_url:
                    thumb_path = os.path.join(MODELS_DIR, spec["thumb_png"])
                    download_file(thumb_url, thumb_path)
                print(f"[{key}] Downloaded ({os.path.getsize(raw_glb_path)} bytes)", flush=True)
            elif status in ("FAILED", "CANCELED", "EXPIRED"):
                print(f"[{key}] Task {task_id} failed with {status}!", flush=True)
                saved_tasks.pop(key, None)
                with open(TASKS_JSON, "w", encoding="utf-8") as f:
                    json.dump(saved_tasks, f, indent=2)
                sys.exit(1)
            else:
                still_pending.append(key)

        pending_keys = still_pending
        if pending_keys:
            time.sleep(6)

    print("ALL ENEMY 3D MODELS SUCCESSFULLY GENERATED AND DOWNLOADED!", flush=True)


if __name__ == "__main__":
    main()
