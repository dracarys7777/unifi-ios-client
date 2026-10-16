import unittest
from watch_upstream import digest, changes

class WatchTests(unittest.TestCase):
    def test_html_ignores_script_noise(self):
        self.assertEqual(digest('<p>Model A</p><script>one()</script>'), digest('<p>Model A</p><script>two()</script>'))
    def test_release_ignores_download_counts(self):
        self.assertEqual(digest('{"tag_name":"v1","downloads":1}', True), digest('{"tag_name":"v1","downloads":2}', True))
    def test_actual_release_change_detected(self):
        self.assertNotEqual(digest('{"tag_name":"v1"}', True), digest('{"tag_name":"v2"}', True))
    def test_baseline_and_changed_sources(self):
        self.assertEqual(changes({}, {'sdk':'a'}), [])
        self.assertEqual(changes({'sdk':'a'}, {'sdk':'b'}), ['sdk'])

if __name__ == '__main__': unittest.main()
