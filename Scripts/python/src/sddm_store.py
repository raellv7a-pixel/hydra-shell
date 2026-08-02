#!/usr/bin/env python3

import os
import sys
import json
import urllib.request
import urllib.error
import shutil
import tempfile
import textwrap

GITHUB_API_URL = "https://api.github.com/repos/Darkkal44/qylock/git/trees/main?recursive=1"
GITHUB_RAW_URL = "https://raw.githubusercontent.com/Darkkal44/qylock/main"

def get_themes_dir():
    # Use ~/.local/share/hydra-lock/themes
    data_home = os.environ.get("XDG_DATA_HOME", os.path.join(os.path.expanduser("~"), ".local", "share"))
    return os.path.join(data_home, "hydra-lock", "themes")

def fetch_catalog():
    req = urllib.request.Request(GITHUB_API_URL, headers={"User-Agent": "hydra-shell"})
    try:
        with urllib.request.urlopen(req) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                return parse_catalog(data.get("tree", []))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

def parse_catalog(tree):
    # Find all folders containing Main.qml
    # And map preview.gif if exists
    themes = {}
    for item in tree:
        path = item.get("path", "")
        if path.startswith("themes/") and path.endswith("/Main.qml"):
            slug = path[len("themes/"): -len("/Main.qml")]
            themes[slug] = {
                "slug": slug,
                "name": format_name(slug),
                "preview_url": f"{GITHUB_RAW_URL}/themes/{slug}/preview.gif", # Attempt to use generic if exists, else None
                "installed": False,
                "path": os.path.join(get_themes_dir(), slug)
            }
            
    # Also look for preview gifs in Assets according to ryoku-arch logic
    # But for simplicity, we can assume preview.gif is inside the theme dir in qylock main branch, 
    # actually qylock puts them in Assets directory. 
    # Let's map Assets/ previews.
    for item in tree:
        path = item.get("path", "")
        if path.startswith("Assets/") and path.endswith(".gif"):
            name = path[len("Assets/"): -4]
            # Try to match name to slug
            for slug in themes:
                if slug.endswith(name) or name.replace("_", "-") in slug or slug.split("/")[-1] == name:
                    themes[slug]["preview_url"] = f"{GITHUB_RAW_URL}/{path}"

    # Check installed
    themes_dir = get_themes_dir()
    for slug in themes:
        if os.path.exists(os.path.join(themes_dir, slug, "Main.qml")):
            themes[slug]["installed"] = True
            
    return list(themes.values())

def format_name(slug):
    leaf = slug.split("/")[-1]
    return leaf.replace("-", " ").replace("_", " ").title()

def get_installed():
    themes_dir = get_themes_dir()
    if not os.path.exists(themes_dir):
        return []
        
    installed = []
    for root, dirs, files in os.walk(themes_dir):
        if "Main.qml" in files:
            slug = os.path.relpath(root, themes_dir)
            
            preview_path = os.path.join(root, "preview.gif")
            preview_url = f"file://{preview_path}" if os.path.exists(preview_path) else ""
            
            # Read metadata.desktop for description
            desc = ""
            meta_path = os.path.join(root, "metadata.desktop")
            if os.path.exists(meta_path):
                with open(meta_path, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.startswith("Description="):
                            desc = line.split("=", 1)[1].strip()
                            break
                            
            installed.append({
                "slug": slug,
                "name": format_name(slug),
                "preview_url": preview_url,
                "installed": True,
                "path": root,
                "description": desc
            })
    return installed

def install_theme(slug):
    # Fetch tree to find files to download
    req = urllib.request.Request(GITHUB_API_URL, headers={"User-Agent": "hydra-shell"})
    try:
        with urllib.request.urlopen(req) as response:
            tree_data = json.loads(response.read().decode('utf-8')).get("tree", [])
    except Exception as e:
        print(json.dumps({"error": f"Failed to fetch catalog: {e}"}))
        sys.exit(1)
        
    theme_files = []
    prefix = f"themes/{slug}/"
    for item in tree_data:
        path = item.get("path", "")
        if path.startswith(prefix) and item.get("type") == "blob":
            theme_files.append(path)
            
    if not theme_files:
        print(json.dumps({"error": f"Theme {slug} not found"}))
        sys.exit(1)
        
    themes_dir = get_themes_dir()
    dest_theme_dir = os.path.join(themes_dir, slug)
    
    with tempfile.TemporaryDirectory(prefix="hydra-lock-") as tmpdir:
        for file_path in theme_files:
            rel_path = file_path[len(prefix):]
            dest_file = os.path.join(tmpdir, rel_path)
            os.makedirs(os.path.dirname(dest_file), exist_ok=True)
            
            raw_url = f"{GITHUB_RAW_URL}/{file_path}"
            try:
                urllib.request.urlretrieve(raw_url, dest_file)
            except Exception as e:
                print(json.dumps({"error": f"Failed to download {file_path}: {e}"}))
                sys.exit(1)
                
        os.makedirs(os.path.dirname(dest_theme_dir), exist_ok=True)
        if os.path.exists(dest_theme_dir):
            shutil.rmtree(dest_theme_dir)
        shutil.move(tmpdir, dest_theme_dir)
        
    print(json.dumps({"status": "success", "slug": slug}))

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Missing command"}))
        sys.exit(1)
        
    command = sys.argv[1]
    
    if command == "catalog":
        print(json.dumps(fetch_catalog()))
    elif command == "list":
        print(json.dumps(get_installed()))
    elif command == "install":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "Missing slug"}))
            sys.exit(1)
        install_theme(sys.argv[2])
    else:
        print(json.dumps({"error": "Unknown command"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
