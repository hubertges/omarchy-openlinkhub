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
        """Test that OpenLinkHub /api/devices responds with valid JSON."""
        data = ctl.api_get("/api/devices", self.api_url)
        self.assertIn("status", data)
        self.assertIn("devices", data)

    def test_02_parse_hardware(self):
        """Test hardware parsing logic."""
        data = ctl.api_get("/api/devices", self.api_url)
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

if __name__ == "__main__":
    unittest.main()
