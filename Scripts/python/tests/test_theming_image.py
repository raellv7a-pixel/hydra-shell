"""Regression tests for bounded wallpaper color sampling."""

import importlib.util
import subprocess
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch


MODULE_PATH = (
    Path(__file__).parents[1] / "src" / "theming" / "lib" / "image.py"
)
SPEC = importlib.util.spec_from_file_location("theming_image", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
theming_image = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(theming_image)

PPM_FRAME = b"P6\n1 1\n255\n\x12\x34\x56"


class ReadVideoFrameTests(unittest.TestCase):
    @patch("subprocess.run")
    def test_video_uses_ffmpeg_for_exactly_one_frame(self, run_mock):
        run_mock.return_value = SimpleNamespace(stdout=PPM_FRAME, stderr=b"")

        pixels = theming_image.read_image(Path("wallpaper.mp4"), "Triangle")

        self.assertEqual(pixels, [(0x12, 0x34, 0x56)])
        command = run_mock.call_args.args[0]
        self.assertEqual(command[0], "ffmpeg")
        self.assertEqual(command[command.index("-frames:v") + 1], "1")
        self.assertEqual(command[command.index("-threads") + 1], "2")
        self.assertEqual(command[command.index("-map") + 1], "0:v:0")
        self.assertIn("scale=112x112:flags=bilinear", command)
        self.assertNotIn("magick", command)
        self.assertEqual(run_mock.call_args.kwargs["timeout"], 30)

    @patch("subprocess.run")
    def test_short_video_retries_from_first_frame(self, run_mock):
        run_mock.side_effect = [
            SimpleNamespace(stdout=b"", stderr=b""),
            SimpleNamespace(stdout=PPM_FRAME, stderr=b""),
        ]

        pixels = theming_image.read_image(Path("short.webm"), "Box")

        self.assertEqual(pixels, [(0x12, 0x34, 0x56)])
        self.assertEqual(run_mock.call_count, 2)
        first_command = run_mock.call_args_list[0].args[0]
        retry_command = run_mock.call_args_list[1].args[0]
        self.assertIn("-ss", first_command)
        self.assertNotIn("-ss", retry_command)
        self.assertIn("scale=112x112:flags=area", retry_command)

    @patch("subprocess.run")
    def test_failed_seek_retries_from_first_frame(self, run_mock):
        run_mock.side_effect = [
            subprocess.CalledProcessError(1, ["ffmpeg"], stderr=b"seek failed"),
            SimpleNamespace(stdout=PPM_FRAME, stderr=b""),
        ]

        pixels = theming_image.read_image(Path("short.mov"))

        self.assertEqual(pixels, [(0x12, 0x34, 0x56)])
        self.assertEqual(run_mock.call_count, 2)

    @patch("subprocess.run")
    def test_video_timeout_is_reported(self, run_mock):
        run_mock.side_effect = subprocess.TimeoutExpired("ffmpeg", 30)

        with self.assertRaisesRegex(
            theming_image.ImageReadError, "FFmpeg timed out"
        ):
            theming_image.read_image(Path("wallpaper.mkv"))


if __name__ == "__main__":
    unittest.main()
