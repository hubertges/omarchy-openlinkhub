# omarchy-openlinkhub 󰌢 󱐋

> Omarchy bar widget and control panel for OpenLinkHub-enabled hardware, including Corsair iCUE Link devices, Commander Pro, PSU telemetry, RGB lighting, and fan profiles.

![Omarchy OpenLinkHub](https://img.shields.io/badge/Omarchy-Shell%20Plugin-blue)
![OpenLinkHub](https://img.shields.io/badge/OpenLinkHub-0.9.1+-success)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Overview

`omarchy-openlinkhub` is a Omarchy bar widget and popout panel built for systems running **OpenLinkHub**. It provides real-time monitoring for coolant temperature, PSU power, CPU/GPU/RAM thermal readings, pump speed, fan RPM, and RGB/device states with a compact UI for quick adjustments.

### Key features

1. **Selectable bar metric**
   - Coolant / AIO temperature
   - PSU output power
   - CPU temperature
   - GPU temperature
   - RAM temperature
   - Pump RPM
   - Fan RPM
   - PSU VRM temperature
   - Right-click cycles the active bar sensor quickly.

2. **RGB lighting control**
   - Built-in profiles such as Wave, Rainbow, Spiral Rainbow, Color Pulse, Static, Storm, Rotator, Spinner, Rain, Visor, and Off.
   - Cluster support and per-device control.
   - Brightness slider with 0–100% adjustment.

3. **Fan profile control**
   - Quiet, Balanced, Performance, and Extreme profiles.
   - One click applies the profile across supported devices.

4. **Hardware overview panel**
   - Liquid cooling telemetry
   - PSU rails and VRM details
   - CPU/GPU/RAM temperatures
   - Fan list and RPM values
   - Thermal probe summary

5. **Keyboard navigation**
   - Left click: open/close panel
   - Right click: cycle the bar metric
   - Middle click / `R`: refresh data
   - `1`-`4`: quick fan profile selection
   - `Esc`: close panel
   - `Tab`: move between bar panels

6. **CLI tool**
   - `openlinkhub-ctl` for terminal automation and Hyprland shortcuts.

---

## Installation

### 1. Clone and install automatically

```bash
cd ~/Projects/omarchy-openlinkhub
./install.sh
```

The script:
1. Copies the plugin into `~/.config/omarchy/plugins/hubi.openlinkhub`
2. Validates the plugin manifest with `omarchy plugin validate`
3. Adds the widget to `~/.config/omarchy/shell.json`
4. Reloads Omarchy shell plugins

### 2. Manual installation

```bash
mkdir -p ~/.config/omarchy/plugins/hubi.openlinkhub
cp -r manifest.json BarWidget.qml Panel.qml OpenLinkHubModel.js bin ~/.config/omarchy/plugins/hubi.openlinkhub/

omarchy plugin validate ~/.config/omarchy/plugins/hubi.openlinkhub/
omarchy bar put hubi.openlinkhub --section right
```

---

## Configuration

Add the widget to the Omarchy bar config in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        {
          "id": "hubi.openlinkhub",
          "displayMetric": "liquid_temp",
          "apiUrl": "http://localhost:27003",
          "pollInterval": 2000
        }
      ]
    }
  }
}
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `displayMetric` | string | `"liquid_temp"` | Active bar metric (`liquid_temp`, `psu_power`, `cpu_temp`, `gpu_temp`, `ram_temp`, `pump_rpm`, `fan_rpm`, `psu_vrm_temp`) |
| `apiUrl` | string | `"http://localhost:27003"` | OpenLinkHub API base URL |
| `pollInterval` | number | `2000` | Refresh interval in milliseconds |

---

## CLI usage

The `openlinkhub-ctl` utility can be used from terminal scripts or Hyprland shortcuts:

```bash
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl status
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get liquid
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get psu
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl get pump

~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl fan Quiet
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl fan Performance

~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl rgb wave
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl rgb rainbow

~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl brightness 50
~/.config/omarchy/plugins/hubi.openlinkhub/bin/openlinkhub-ctl metric psu_power
```

---

## Validation and tests

```bash
./tests/test_manifest.sh
python3 ./tests/test_api.py
```

---

## License

This project is distributed under the **MIT** license. See [LICENSE](LICENSE) for details.
Copyright (c) 2026 Hubert Ges.
