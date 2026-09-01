#!/usr/bin/env python3
"""
Unit and integration tests for OpenLinkHub plugin & API.
"""

import unittest
import urllib.request
import json
import os
import sys

from importlib.machinery import SourceFileLoader

ctl_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "bin", "openlinkhub-ctl"))
ctl = SourceFileLoader("openlinkhub_ctl", ctl_path).load_module()

class TestOpenLinkHub(unittest.TestCase):
    def setUp(self):
        self.api_url = "http://localhost:27003"

    def test_01_api_connectivity(self):
        """Test that OpenLinkHub /api/devices/ responds with valid JSON."""
        data = ctl.api_get("/api/devices/", self.api_url)
        self.assertIn("status", data)
        self.assertIn("devices", data)

    def test_02_parse_hardware(self):
        """Test hardware parsing logic."""
        data = ctl.api_get("/api/devices/", self.api_url)
        hw = ctl.parse_hardware(data)
        
        self.assertIsNotNone(hw["liquid_temp"], "Should find liquid coolant temperature")
        self.assertGreater(hw["liquid_temp"], 15)
        self.assertLess(hw["liquid_temp"], 80)
        
        self.assertIsNotNone(hw["psu_watts"], "Should find PSU power wattage")
        self.assertGreater(hw["psu_watts"], 0)
        
        self.assertIsNotNone(hw["cpu_temp"], "Should find CPU temp")
        self.assertGreater(hw["cpu_temp"], 20)
        
        self.assertTrue(len(hw["fans"]) > 0, "Should detect connected fans")
        self.assertIsNotNone(hw["active_fan_profile"])
        self.assertIsNotNone(hw["active_rgb_mode"])

    def test_03_fan_profile_change(self):
        """Test changing fan speed profile via API."""
        res = ctl.api_post("/api/speed", {"deviceId": "62605BBB76606751B331EACF1C495170", "channelId": -1, "profile": "Quiet"}, self.api_url)
        self.assertEqual(res.get("status"), 1)

    def test_04_rgb_mode_change(self):
        """Test changing RGB mode via API."""
        res = ctl.api_post("/api/color", {"deviceId": "cluster", "channelId": 0, "profile": "wave"}, self.api_url)
        self.assertEqual(res.get("status"), 1)

    def test_05_theme_color_sync(self):
        """Test theme-based color sync payload via API."""
        payload = {
            "deviceId": "cluster",
            "profile": "static",
            "startColor": {"red": 6, "green": 182, "blue": 212, "temperature": 0},
            "endColor": {"red": 56, "green": 189, "blue": 248, "temperature": 0},
            "middleColor": {"red": 0, "green": 0, "blue": 0, "temperature": 0},
            "speed": 2,
            "alternateColors": False,
            "rgbDirection": 0
        }
        res = ctl.api_put("/api/color/change", payload, self.api_url)
        self.assertEqual(res.get("status"), 1)

    def test_06_url_validation_security(self):
        """Test URL validation rejecting forbidden schemes and malformed URLs."""
        valid_url = ctl.validate_api_url("http://127.0.0.1:27003", "/api/devices")
        self.assertEqual(valid_url, "http://127.0.0.1:27003/api/devices")

        valid_https = ctl.validate_api_url("https://localhost:27003", "api/devices")
        self.assertEqual(valid_https, "https://localhost:27003/api/devices")

        with self.assertRaises(ValueError):
            ctl.validate_api_url("file:///etc/passwd", "/api")

        with self.assertRaises(ValueError):
            ctl.validate_api_url("ftp://example.com", "/api")

        with self.assertRaises(ValueError):
            ctl.validate_api_url("gopher://example.com", "/api")

        with self.assertRaises(ValueError):
            ctl.validate_api_url("http://", "/api")

    def test_07_response_size_limit(self):
        """Test response body size limit enforcement."""
        import io
        small_stream = io.BytesIO(b'{"status": 1}')
        res = ctl.read_limited_response(small_stream, max_bytes=100)
        self.assertEqual(res, '{"status": 1}')

        large_stream = io.BytesIO(b'x' * 200)
        with self.assertRaises(ValueError):
            ctl.read_limited_response(large_stream, max_bytes=100)

    def test_08_redirect_blocking(self):
        """Test that automatic HTTP redirects are blocked."""
        from http.server import HTTPServer, BaseHTTPRequestHandler
        import threading

        class RedirectHandler(BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(302)
                self.send_header("Location", "http://example.com/redirected")
                self.end_headers()
            def log_message(self, format, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), RedirectHandler)
        port = server.server_address[1]
        t = threading.Thread(target=server.serve_forever)
        t.daemon = True
        t.start()

        try:
            # Direct opener check ensures HTTPError 302 is raised
            req = urllib.request.Request(f"http://127.0.0.1:{port}/test")
            with self.assertRaises(urllib.error.HTTPError):
                ctl._opener.open(req, timeout=1)

            # api_get handles it gracefully and exits with code 1
            with self.assertRaises(SystemExit):
                ctl.api_get("/test", f"http://127.0.0.1:{port}")
        finally:
            server.shutdown()
            server.server_close()

    def test_09_shell_config_symlink_protection(self):
        """Test that symlinked shell.json files are rejected."""
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            real_file = os.path.join(tmpdir, "real_target.json")
            with open(real_file, "w") as f:
                f.write('{"bar": {}}')
            symlink_file = os.path.join(tmpdir, "symlink_shell.json")
            os.symlink(real_file, symlink_file)

            with self.assertRaises(ValueError):
                ctl.update_shell_config(symlink_file, lambda cfg: (cfg, True))

    def test_10_shell_config_regular_file_and_size_checks(self):
        """Test that non-regular files and oversized files are rejected."""
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            # Directory check
            dir_target = os.path.join(tmpdir, "dir_config")
            os.makedirs(dir_target, exist_ok=True)
            with self.assertRaises(ValueError):
                ctl.update_shell_config(dir_target, lambda cfg: (cfg, True))

            # Oversized file check
            big_file = os.path.join(tmpdir, "big_shell.json")
            with open(big_file, "wb") as f:
                f.write(b"0" * (ctl.MAX_CONFIG_SIZE + 10))
            with self.assertRaises(ValueError):
                ctl.update_shell_config(big_file, lambda cfg: (cfg, True))

    def test_11_shell_config_atomic_write_and_permissions(self):
        """Test atomic write, locking, and 0600 file permissions."""
        import tempfile
        import stat
        with tempfile.TemporaryDirectory() as tmpdir:
            cfg_file = os.path.join(tmpdir, "shell.json")
            with open(cfg_file, "w") as f:
                f.write('{"bar": {"layout": {"right": []}}}')
            os.chmod(cfg_file, 0o644)

            def _add_metric(cfg):
                cfg["bar"]["layout"]["right"].append({"id": "hubi.openlinkhub", "displayMetric": "psu_power"})
                return cfg, True

            success = ctl.update_shell_config(cfg_file, _add_metric)
            self.assertTrue(success)

            with open(cfg_file, "r") as f:
                updated = json.load(f)
            self.assertEqual(updated["bar"]["layout"]["right"][0]["displayMetric"], "psu_power")

            st = os.stat(cfg_file)
            # Permissions should be private 0o600
            self.assertEqual(stat.S_IMODE(st.st_mode), 0o600)

if __name__ == "__main__":
    unittest.main()
