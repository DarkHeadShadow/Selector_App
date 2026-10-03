import importlib.util
import logging
import os
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace


_APP_DATA = tempfile.TemporaryDirectory()
_PREVIOUS_LOCALAPPDATA = os.environ.get("LOCALAPPDATA")
os.environ["LOCALAPPDATA"] = _APP_DATA.name

_APP_PATH = Path(__file__).resolve().parents[1] / "Selector-app.py"
_SPEC = importlib.util.spec_from_file_location("selector_app_under_test", _APP_PATH)
app = importlib.util.module_from_spec(_SPEC)
sys.modules[_SPEC.name] = app
_SPEC.loader.exec_module(app)
app.results_listbox = SimpleNamespace(insert=lambda *args: None)
app.progress = SimpleNamespace(config=lambda **kwargs: None)
app.label_status = SimpleNamespace(config=lambda **kwargs: None)


def tearDownModule():
    logging.shutdown()
    if _PREVIOUS_LOCALAPPDATA is None:
        os.environ.pop("LOCALAPPDATA", None)
    else:
        os.environ["LOCALAPPDATA"] = _PREVIOUS_LOCALAPPDATA
    _APP_DATA.cleanup()


class SearchBehaviorTests(unittest.TestCase):
    def test_folder_names_cannot_escape_output_or_use_reserved_windows_names(self):
        self.assertEqual(app.sanitize_folder_name(".."), "talalat")
        self.assertEqual(app.sanitize_folder_name("."), "talalat")
        self.assertEqual(app.sanitize_folder_name("CON"), "_CON")
        self.assertEqual(app.sanitize_folder_name("COM1.txt"), "_COM1.txt")
        self.assertEqual(app.sanitize_folder_name("CONIN$"), "_CONIN$")
        self.assertNotIn("\x01", app.sanitize_folder_name("bad\x01name"))

    def test_xls_search_releases_workbook(self):
        class Workbook:
            def __init__(self):
                self.released = False

            def sheets(self):
                return [SimpleNamespace(nrows=1, row=lambda _: [SimpleNamespace(value="needle")])]

            def release_resources(self):
                self.released = True

        workbook = Workbook()
        old_xlrd = app.xlrd
        app.xlrd = SimpleNamespace(open_workbook=lambda path, on_demand: workbook)
        try:
            self.assertTrue(app.search_in_xlsx("sample.xls", "needle"))
            self.assertTrue(workbook.released)
        finally:
            app.xlrd = old_xlrd

    def test_search_skips_output_tree_and_keeps_same_named_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source"
            output = source / "results"
            (source / "left").mkdir(parents=True)
            (source / "right").mkdir()
            output.mkdir()
            (source / "left" / "same.txt").write_text("needle ..", encoding="utf-8")
            (source / "right" / "same.txt").write_text("needle ..", encoding="utf-8")
            (output / "old.txt").write_text("needle ..", encoding="utf-8")
            terms = Path(temp) / "terms.txt"
            terms.write_text("..\nneedle\n", encoding="utf-8")

            app.CANCEL_EVENT.clear()
            app.start_search(str(terms), str(source), str(output), (".txt",))

            self.assertEqual(len(app.report_data["per_term_hits"][".."]), 2)
            self.assertEqual(len(app.report_data["per_term_hits"]["needle"]), 2)
            self.assertTrue((output / "talalat" / "left" / "same.txt").is_file())
            self.assertTrue((output / "talalat" / "right" / "same.txt").is_file())
            self.assertFalse((output / "needle" / "old.txt").exists())


if __name__ == "__main__":
    unittest.main()
