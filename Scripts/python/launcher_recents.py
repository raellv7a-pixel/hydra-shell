"""Read desktop-bookmark XBEL without modifying the shared history."""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
from urllib.parse import unquote, urlsplit
import xml.etree.ElementTree as ET

MIME_NS = "http://www.freedesktop.org/standards/shared-mime-info"
BOOKMARK_NS = "http://www.freedesktop.org/standards/desktop-bookmarks"


def timestamp(value):
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp() * 1000
    except (ValueError, AttributeError, OverflowError):
        return 0


def read_recents(path, cutoff=0, limit=12):
    records = {}
    try:
        # iterparse keeps the XML traversal off the QML thread and handles namespaces.
        for _, node in ET.iterparse(path, events=("end",)):
            if node.tag != "bookmark":
                continue
            uri = node.get("href", "")
            parsed = urlsplit(uri)
            modified = max(timestamp(node.get(key, "")) for key in ("modified", "visited", "added"))
            private = node.find(f".//{{{BOOKMARK_NS}}}private") is not None
            if parsed.scheme != "file" or parsed.netloc not in ("", "localhost") or private or modified <= cutoff:
                node.clear()
                continue
            filename = Path(unquote(parsed.path))
            if not filename.is_absolute() or not filename.is_file():
                node.clear()
                continue
            mime_node = node.find(f".//{{{MIME_NS}}}mime-type")
            mime = mime_node.get("type", "application/octet-stream") if mime_node is not None else "application/octet-stream"
            group = mime.split("/", 1)[0]
            icon = {"image": "photo", "video": "video", "audio": "music", "text": "file-text"}.get(group, "file-description")
            entry = {"uri": filename.as_uri(), "path": str(filename), "name": node.findtext("title") or filename.name,
                     "mime": mime, "modifiedAt": modified, "icon": icon}
            previous = records.get(entry["uri"])
            if previous is None or modified > previous["modifiedAt"]:
                records[entry["uri"]] = entry
            node.clear()
    except (OSError, ET.ParseError, ValueError):
        return []
    return sorted(records.values(), key=lambda entry: entry["modifiedAt"], reverse=True)[:limit]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cutoff", type=float, default=0)
    args = parser.parse_args()
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    print(json.dumps(read_recents(data_home / "recently-used.xbel", args.cutoff)))


if __name__ == "__main__":
    main()
