"""Consumer-visible guarantees for safe app post-processing."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

THEMING = Path(__file__).resolve().parents[1] / 'src/theming'
sys.path.insert(0, str(THEMING))
from lib.app_config import (apply_antigravity, apply_obsidian, atomic_write,
                            discover_obsidian_configs, ensure_css_import)
from lib.renderer import TemplateRenderer


class AppConfigTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def test_antigravity_merge_keeps_unknown_values_permissions_and_unchanged_bytes(self):
        recipe = self.root / 'recipe'; recipe.write_text('{"colorScheme":"terminal"}')
        profile = self.root / 'settings.json'
        previous = {'colorScheme': 'light', 'arbitrary': {'unicode': 'Olá', 'array': [False, 2, None]},
                    'projectConfig': [{'path': '/some/project', 'nested': {'a': 1}}]}
        profile.write_text(json.dumps(previous)); profile.chmod(0o640)
        self.assertTrue(apply_antigravity(profile, recipe))
        expected = dict(previous, colorScheme='terminal')
        self.assertEqual(json.loads(profile.read_text()), expected)
        self.assertEqual(profile.stat().st_mode & 0o777, 0o640)
        content = profile.read_bytes(); mtime = profile.stat().st_mtime_ns
        self.assertFalse(apply_antigravity(profile, recipe))
        self.assertEqual(profile.read_bytes(), content)
        self.assertEqual(profile.stat().st_mtime_ns, mtime)

    def test_invalid_or_absent_antigravity_profile_is_never_destroyed_or_created(self):
        recipe = self.root / 'recipe'; recipe.write_text('{"colorScheme":"terminal"}')
        profile = self.root / 'absent/settings.json'
        self.assertFalse(apply_antigravity(profile, recipe)); self.assertFalse(profile.parent.exists())
        profile = self.root / 'invalid.json'; profile.write_bytes(b'{broken user data')
        with self.assertRaises(ValueError):
            apply_antigravity(profile, recipe)
        self.assertEqual(profile.read_bytes(), b'{broken user data')

    def test_atomic_failure_retains_original_content_and_cleans_stage(self):
        profile = self.root / 'settings.json'; profile.write_bytes(b'original')
        with patch('lib.app_config.os.replace', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                atomic_write(profile, b'new')
        self.assertEqual(profile.read_bytes(), b'original')
        self.assertEqual(set(self.root.iterdir()), {profile})

    def test_css_import_retains_all_user_bytes_and_is_idempotent(self):
        css = self.root / 'user.css'
        original = b'/* do not reformat */\r\nbutton { color: red; }\r\n'
        css.write_bytes(original)
        colors = self.root / 'hydra-colors.css'; colors.write_text('window {color:blue;}')
        self.assertTrue(ensure_css_import(css, colors))
        self.assertEqual(css.read_bytes(), b'@import url("hydra-colors.css");\n' + original)
        mtime = css.stat().st_mtime_ns
        self.assertFalse(ensure_css_import(css, colors))
        self.assertEqual(css.stat().st_mtime_ns, mtime)
        missing = self.root / 'missing/user.css'
        self.assertFalse(ensure_css_import(missing, missing.parent / 'hydra-colors.css'))
        self.assertFalse(missing.parent.exists())

    def test_owned_snippet_or_css_symlink_never_overwrites_external_file(self):
        external = self.root / 'note.md'; external.write_bytes(b'user markdown')
        link = self.root / 'hydra.css'; link.symlink_to(external)
        with self.assertRaises(ValueError):
            atomic_write(link, b'colors')
        self.assertTrue(link.is_symlink()); self.assertEqual(external.read_bytes(), b'user markdown')

    def test_obsidian_known_manifests_multiple_vaults_without_home_scan(self):
        first = self.root / 'vault one'; second = self.root / 'vault two'
        for vault in (first, second):
            (vault / '.obsidian/snippets').mkdir(parents=True)
            (vault / 'note.md').write_bytes(b'Markdown untouched')
            (vault / '.obsidian/snippets/existing.css').write_bytes(b'user snippet')
        absent = self.root / 'not a vault'
        manifest = self.root / 'obsidian.json'
        manifest.write_text(json.dumps({'vaults': {
            'one': {'path': str(first)}, 'two': {'path': str(second)},
            'duplicate': {'path': str(first)}, 'missing': {'path': str(absent)},
            'relative': {'path': 'relative'}, 'invalid': None}}))
        malformed = self.root / 'bad.json'; malformed.write_text('{bad')
        source = self.root / 'colors.css'; source.write_bytes(b'body {color:blue;}')
        manifests = [self.root / 'missing.json', malformed, manifest]
        self.assertEqual(discover_obsidian_configs(manifests), sorted([first / '.obsidian', second / '.obsidian']))
        self.assertEqual(apply_obsidian(source, manifests), 2)
        self.assertEqual(apply_obsidian(source, manifests), 0)
        self.assertFalse(absent.exists())
        for vault in (first, second):
            self.assertEqual((vault / '.obsidian/snippets/hydra.css').read_bytes(), source.read_bytes())
            self.assertEqual((vault / '.obsidian/snippets/existing.css').read_bytes(), b'user snippet')
            self.assertEqual((vault / 'note.md').read_bytes(), b'Markdown untouched')

    def test_newly_registered_vault_receives_unchanged_rendered_snippet(self):
        home = self.root / 'home'; config = self.root / 'config'; cache = self.root / 'cache'
        (config / 'obsidian').mkdir(parents=True); home.mkdir(); cache.mkdir()
        source = self.root / 'source.css'; source.write_bytes(b'body {color:blue;}')
        first = self.root / 'first'; second = self.root / 'second'
        (first / '.obsidian').mkdir(parents=True); (second / '.obsidian').mkdir(parents=True)
        manifest = config / 'obsidian/obsidian.json'
        apply_script = THEMING / 'app-theme-apply.py'
        import shlex
        hook = f'{shlex.quote(sys.executable)} {shlex.quote(str(apply_script))} obsidian'
        config_file = self.root / 'templates.toml'
        config_file.write_text('[templates.obsidian]\ninput_path=' + json.dumps(str(source)) +
                               '\noutput_path="$XDG_CACHE_HOME/hydra/obsidian.css"\n'
                               'hook_on_unchanged=true\npost_hook=' + json.dumps(hook) + '\n')
        with patch.dict(os.environ, {'HOME': str(home), 'XDG_CONFIG_HOME': str(config), 'XDG_CACHE_HOME': str(cache)}):
            renderer = TemplateRenderer({})
            manifest.write_text(json.dumps({'vaults': {'first': {'path': str(first)}}}))
            renderer.process_config_file(config_file)
            self.assertTrue((first / '.obsidian/snippets/hydra.css').is_file())
            mtime = (cache / 'hydra/obsidian.css').stat().st_mtime_ns
            manifest.write_text(json.dumps({'vaults': {'second': {'path': str(second)}}}))
            renderer.process_config_file(config_file)
            self.assertEqual((second / '.obsidian/snippets/hydra.css').read_bytes(), source.read_bytes())
            self.assertEqual((cache / 'hydra/obsidian.css').stat().st_mtime_ns, mtime)


if __name__ == '__main__':
    unittest.main()
