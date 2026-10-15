import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from desktop_app import _updater_environment, _write_update_script, _is_newer_version


class UpdaterTests(unittest.TestCase):
    def test_restart_does_not_reuse_parent_extraction_directory(self):
        with patch.dict(os.environ, {
            '_PYI_APPLICATION_HOME_DIR': 'old-extraction',
            '_PYI_PARENT_PROCESS_LEVEL': '1',
            '_MEIPASS2': 'old-extraction',
            'PATH': 'preserved-path',
        }):
            environment = _updater_environment()
        self.assertFalse(any(key.startswith('_PYI_') for key in environment))
        self.assertNotIn('_MEIPASS2', environment)
        self.assertEqual(environment['PYINSTALLER_RESET_ENVIRONMENT'], '1')
        self.assertEqual(environment['PATH'], 'preserved-path')

    def test_installer_uses_target_directory_and_retries_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch('desktop_app.tempfile.gettempdir', return_value=directory):
                script = _write_update_script(
                    root / 'download.exe', root / 'new.exe', root / 'old.exe', 1234,
                ).read_text()
            self.assertIn('PYINSTALLER_RESET_ENVIRONMENT=1', script)
            self.assertIn('for /l %%i in (1,1,15)', script)
            self.assertIn(f'start "" /D "{root}" "%TARGET_EXE%"', script)
            self.assertIn('exit /b 1', script)

    def test_new_release_is_detected(self):
        self.assertTrue(_is_newer_version('1.0.23', '1.0.22'))
        self.assertFalse(_is_newer_version('1.0.23', '1.0.23'))
