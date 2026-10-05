"""Consumer-visible XBEL filtering, ordering and local privacy boundaries."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("launcher_recents", Path(__file__).parents[1] / "launcher_recents.py")
recents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recents)


class RecentDocumentsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.history = self.root / "recently-used.xbel"

    def history_for(self, body):
        self.history.write_text('<xbel xmlns:b="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:m="http://www.freedesktop.org/standards/shared-mime-info">' + body + '</xbel>')

    def test_namespaces_encoded_paths_order_and_cutoff(self):
        first = self.root / "Notes & ideas.txt"
        second = self.root / "Presentation.odp"
        first.touch()
        second.touch()
        self.history_for(f'<bookmark href="{first.as_uri()}" modified="2026-10-04T12:00:00Z"><title>Notes &amp; ideas</title><info><metadata><m:mime-type type="text/plain"/></metadata></info></bookmark>'
                         f'<bookmark href="{second.as_uri()}" modified="2026-10-05T12:00:00Z"/>')
        data = recents.read_recents(self.history)
        self.assertEqual([item["path"] for item in data], [str(second), str(first)])
        self.assertEqual(data[1]["name"], "Notes & ideas")
        self.assertEqual(data[1]["mime"], "text/plain")
        self.assertEqual([item["path"] for item in recents.read_recents(self.history, data[1]["modifiedAt"])], [str(second)])

    def test_private_remote_deleted_and_duplicates(self):
        file = self.root / "image.png"
        file.touch()
        self.history_for(f'<bookmark href="{file.as_uri()}" modified="2026-10-04T12:00:00Z"/>'
                         f'<bookmark href="{file.as_uri()}" modified="2026-10-05T12:00:00Z"/>'
                         f'<bookmark href="{file.as_uri()}" modified="2026-10-06T12:00:00Z"><info><metadata><b:private/></metadata></info></bookmark>'
                         '<bookmark href="file://remote/secret.txt" modified="2026-10-07T12:00:00Z"/>'
                         '<bookmark href="https://example.org/file" modified="2026-10-07T12:00:00Z"/>'
                         f'<bookmark href="{(self.root / "deleted").as_uri()}" modified="2026-10-07T12:00:00Z"/>')
        data = recents.read_recents(self.history)
        self.assertEqual([item["uri"] for item in data], [file.as_uri()])
        self.assertEqual(data[0]["modifiedAt"], recents.timestamp("2026-10-05T12:00:00Z"))

    def test_absent_or_malformed_history_returns_app_fallback(self):
        self.assertEqual(recents.read_recents(self.history), [])
        self.history.write_text('<xbel><bookmark href="broken"')
        self.assertEqual(recents.read_recents(self.history), [])


if __name__ == "__main__":
    unittest.main()
