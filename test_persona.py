import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import persona


class PersonaTests(unittest.TestCase):
    def setUp(self):
        mock = patch('persona.subprocess.run')
        self.run_config = mock.start()
        self.addCleanup(mock.stop)

    def cli(self, *args):
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            status = persona.main(args)
        return status, out.getvalue()

    def test_list_and_preview_never_call_config(self):
        self.assertEqual(self.cli('list'), (0, 'concise\nreview\nwriting\n'))
        for key in persona.load(persona.PRESETS):
            status, preview = self.cli('preview', '--preset', key)
            self.assertEqual(status, 0)
            self.assertEqual(set(json.loads(preview)), {'soul.body', 'soul.style'})
        self.run_config.assert_not_called()

    def test_custom_exact_batch(self):
        values = {'style': '简洁', 'body': '中文\n"quotes" \\ $HOME `echo`'}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'custom.json'
            path.write_text(json.dumps(values), encoding='utf-8')
            self.run_config.return_value.returncode = 0
            self.assertEqual(self.cli('apply', '--file', str(path))[0], 0)
        args, kwargs = self.run_config.call_args
        self.assertEqual(args, (['minis-config', 'set-batch'],))
        self.assertEqual(json.loads(kwargs['input']), [
            {'path': 'soul.' + key, 'value_json': json.dumps(value, ensure_ascii=False)}
            for key, value in values.items()
        ])
        self.run_config.assert_called_once()

    def test_reject_invalid_before_config(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'custom.json'
            for text in ('{', '{"style":"x","body":"y","soul.name":"z"}',
                         '{"style":true,"body":"y"}', '{"style":"x","body":" "}'):
                with self.subTest(text=text):
                    path.write_text(text, encoding='utf-8')
                    self.assertEqual(self.cli('apply', '--file', str(path))[0], 1)
        self.assertEqual(self.cli('apply', '--preset', 'missing')[0], 1)
        self.run_config.assert_not_called()

    def test_exit_status_no_retry(self):
        for status in (1, 124, 125, 126):
            with self.subTest(status=status):
                self.run_config.reset_mock()
                self.run_config.return_value.returncode = status
                self.assertEqual(self.cli('apply', '--preset', 'concise')[0], status)
                self.run_config.assert_called_once()

    def test_missing_config(self):
        self.run_config.side_effect = FileNotFoundError('minis-config')
        self.assertEqual(self.cli('apply', '--preset', 'concise')[0], 1)
        self.run_config.assert_called_once()
