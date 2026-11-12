import tempfile
import unittest
from pathlib import Path

from profile_grid import distribution, read_xctrace, summarize_android, summarize_ios


class FrameMetricsTests(unittest.TestCase):
    def test_percentiles_keep_the_tail_and_empty_is_unavailable(self):
        self.assertEqual(distribution([1] * 99 + [80]), {'p50': 1, 'p95': 1, 'p99': 1, 'max': 80})
        self.assertIsNone(distribution([])['p95'])

    def test_android_distinguishes_jank_from_dropped_frames(self):
        rows = [
            {'surface_frame_token': '1', 'dur': '8000000', 'jank_type': 'None', 'present_type': 'Presented', 'overrun_ns': '-1000000'},
            {'surface_frame_token': '2', 'dur': '24000000', 'jank_type': 'App Deadline Missed', 'present_type': 'Presented', 'overrun_ns': '8000000'},
            {'surface_frame_token': '3', 'dur': '32000000', 'jank_type': 'App Deadline Missed', 'present_type': 'Dropped Frame', 'overrun_ns': ''},
        ]
        result = summarize_android(rows, (100, 1000000100))
        self.assertAlmostEqual(result['janky_frame_percent'], 200 / 3)
        self.assertAlmostEqual(result['dropped_frame_percent'], 100 / 3)
        self.assertAlmostEqual(result['app_deadline_missed_frame_percent'], 200 / 3)
        self.assertEqual(result['jank_type_counts'], {'App Deadline Missed': 2})
        self.assertEqual(result['app_frame_production_ms']['max'], 32)
        self.assertEqual(result['frame_overrun_ms']['max'], 8)
        with self.assertRaises(ValueError):
            summarize_android(rows + [rows[0]], (0, 1))
        with self.assertRaises(ValueError):
            summarize_android([], (0, 1))

    def test_ios_clips_to_app_and_marker_without_inventing_drop_rate(self):
        tables = [
            ('os-signpost-interval', [{'name': 'GridProfile', 'start-time': '1000000000', 'duration': '2000000000'}]),
            ('hitches-frame-lifetimes', [
                {'process': 'sandbox (42)', 'start-time': '1000000000', 'duration': '20000000'},
                {'process': 'other (7)', 'start-time': '1000000000', 'duration': '90000000'},
                {'process': 'sandboxd (8)', 'start-time': '1000000000', 'duration': '90000000'},
                {'process': 'sandbox (42)', 'start-time': '0', 'duration': '90000000'}]),
            ('hitches', [
                {'process': 'sandbox (42)', 'start-time': '1000000000', 'duration': '20000000'},
                {'process': 'sandbox (42)', 'start-time': '1010000000', 'duration': '20000000'}])]
        result = summarize_ios(tables)
        self.assertEqual(result['frame_count'], 1)
        self.assertEqual(result['hitch_count'], 2)
        self.assertEqual(result['hitch_ms_per_second'], 15)
        self.assertIsNone(result['dropped_frame_percent'])
        with self.assertRaises(ValueError):
            summarize_ios([])

    def test_xctrace_uses_raw_nanoseconds_and_resolves_shared_references(self):
        xml = '''<trace-query-result><node><schema name="hitches"><col><mnemonic>start-time</mnemonic></col><col><mnemonic>duration</mnemonic></col><col><mnemonic>process</mnemonic></col></schema>
        <row><time id="1" fmt="1 ms">1000001</time><duration id="2" fmt="2 ms">2000001</duration><process id="3" fmt="sandbox (42)"><pid>42</pid></process></row>
        <row><time ref="1"/><duration ref="2"/><process ref="3"/></row></node></trace-query-result>'''
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'table.xml'
            path.write_text(xml)
            _, rows = read_xctrace(path)[0]
        self.assertEqual(rows[1], {'start-time': '1000001', 'duration': '2000001', 'process': 'sandbox (42)'})


if __name__ == '__main__':
    unittest.main()
