.pragma library

// OpenLinkHub Model & Helper Utilities for Omarchy shell plugin
// Handles API parsing, metric resolution, fan & RGB presets.

var METRICS = [
  { id: "liquid_temp", name: "Liquid Temp", labelPl: "Ciecz (AIO)", icon: "󰌢", unit: "°C" },
  { id: "psu_power",   name: "PSU Power",   labelPl: "Zasilacz (W)", icon: "󱐋", unit: "W" },
  { id: "cpu_temp",    name: "CPU Temp",    labelPl: "CPU Temp",     icon: "󰍛", unit: "°C" },
  { id: "gpu_temp",    name: "GPU Temp",    labelPl: "GPU Temp",     icon: "󰢮", unit: "°C" },
  { id: "ram_temp",    name: "RAM Temp",    labelPl: "Pamięć RAM",   icon: "󰘚", unit: "°C" },
  { id: "pump_rpm",    name: "Pump Speed",  labelPl: "Pompa AIO",    icon: "󰈐", unit: "RPM" },
  { id: "fan_rpm",     name: "Max Fan RPM", labelPl: "Wentylatory",  icon: "󰠝", unit: "RPM" },
  { id: "psu_vrm_temp",name: "PSU VRM Temp",labelPl: "PSU VRM",      icon: "󰏈", unit: "°C" }
];

var FAN_PROFILES = [
  { id: "Quiet",       name: "Quiet",       labelPl: "Cichy",          icon: "󰠝" },
  { id: "Balanced",    name: "Balanced",    labelPl: "Zrównoważony",    icon: "󰠝" },
  { id: "Performance", name: "Performance", labelPl: "Wydajny",        icon: "󰠝" },
  { id: "Extreme",     name: "Extreme",     labelPl: "Maksymalny",     icon: "󰠝" }
];

var RGB_MODES = [
  { id: "wave",                name: "Wave",           labelPl: "Fala (Wave)",             icon: "󰏌" },
  { id: "rainbow",             name: "Rainbow",        labelPl: "Tęcza (Rainbow)",         icon: "󰏌" },
  { id: "spiralrainbow",       name: "Spiral Rainbow", labelPl: "Spirala (Spiral)",        icon: "󰏌" },
  { id: "colorpulse",          name: "Color Pulse",    labelPl: "Puls (Color Pulse)",      icon: "󰏌" },
  { id: "static",              name: "Static",         labelPl: "Jednolity (Static)",      icon: "󰏌" },
  { id: "watercolor",          name: "Water Color",    labelPl: "Akwarela (Water Color)",  icon: "󰏌" },
  { id: "storm",               name: "Storm",          labelPl: "Burza (Storm)",           icon: "󰏌" },
  { id: "rotator",             name: "Rotator",        labelPl: "Rotator",                 icon: "󰏌" },
  { id: "spinner",             name: "Spinner",        labelPl: "Spinner",                 icon: "󰏌" },
  { id: "flickering",          name: "Flickering",     labelPl: "Migotanie (Flicker)",     icon: "󰏌" },
  { id: "colorwarp",           name: "Color Warp",     labelPl: "Zniekształcenie (Warp)",  icon: "󰏌" },
  { id: "rain",                name: "Rain",           labelPl: "Deszcz (Rain)",           icon: "󰏌" },
  { id: "visor",               name: "Visor",          labelPl: "Wizjer (Visor)",          icon: "󰏌" },
  { id: "off",                 name: "Off",            labelPl: "Wyłączone (Off)",         icon: "󰏌" }
];

function emptyData() {
  return {
    connected: false,
    liquidTemp: null,
    liquidName: "",
    pumpRpm: null,
    psuWatts: null,
    psuName: "",
    psuTemp: null,
    psuVrmTemp: null,
    psuRails: {},
    cpuTemp: null,
    gpuTemp: null,
    ramTemp: null,
    maxFanRpm: null,
    avgFanRpm: null,
    fans: [],
    probes: [],
    devices: [],
    fanControllableDevices: [],
    rgbControllableDevices: [],
    activeFanProfile: "Quiet",
    activeRgbMode: "wave",
    isCluster: false,
    rgbOff: false,
    brightness: 100
  };
}

function parseOpenLinkHubData(rawText) {
  var out = emptyData();
  if (!rawText) return out;

  var json;
  try {
    json = JSON.parse(rawText);
  } catch (e) {
    return out;
  }

  if (!json || typeof json !== "object") return out;
  var devicesMap = json.devices || {};
  out.connected = true;

  var totalFanRpm = 0;
  var fanCount = 0;
  var maxFan = 0;

  for (var devId in devicesMap) {
    if (!devicesMap.hasOwnProperty(devId)) continue;
    var dev = devicesMap[devId];
    if (!dev) continue;

    var devName = dev.Product || devId;
    var getDev = dev.GetDevice;
    if (!getDev) continue;

    var devProfile = getDev.DeviceProfile || {};
    if (devProfile) {
      if (devProfile.MultiProfile) out.activeFanProfile = String(devProfile.MultiProfile);
      if (devProfile.MultiRGB) out.activeRgbMode = String(devProfile.MultiRGB);
      if (devProfile.RGBCluster !== undefined) out.isCluster = Boolean(devProfile.RGBCluster);
      if (devProfile.RgbOff !== undefined) out.rgbOff = Boolean(devProfile.RgbOff);
      if (devProfile.BrightnessSlider !== undefined) out.brightness = Number(devProfile.BrightnessSlider);
    }

    if (getDev.CpuTemp && (out.cpuTemp === null || getDev.CpuTemp > 0)) {
      out.cpuTemp = Math.round(Number(getDev.CpuTemp) * 10) / 10;
    }
    if (getDev.GpuTemp && (out.gpuTemp === null || getDev.GpuTemp > 0)) {
      out.gpuTemp = Math.round(Number(getDev.GpuTemp) * 10) / 10;
    }

    var channels = getDev.devices || {};
    var devChannelsList = [];
    var hasFans = false;
    var hasRgb = Array.isArray(getDev.RGBModes) && getDev.RGBModes.length > 0;

    for (var chId in channels) {
      if (!channels.hasOwnProperty(chId)) continue;
      var ch = channels[chId];
      if (!ch) continue;

      var chName = String(ch.name || ("Channel " + chId));
      var desc = String(ch.description || "");
      var rpm = ch.rpm !== undefined && ch.rpm !== null ? Number(ch.rpm) : null;
      var temp = ch.temperature !== undefined && ch.temperature !== null ? Number(ch.temperature) : null;
      var watts = ch.watts !== undefined && ch.watts !== null ? Number(ch.watts) : null;
      var profile = ch.profile ? String(ch.profile) : "";

      // Detect AIO Liquid Cooler
      if (desc === "AIO" || chName.indexOf("LCD") !== -1 || chName.indexOf("H150") !== -1 || chName.indexOf("Cooler") !== -1 || chName.indexOf("AIO") !== -1) {
        if (temp !== null && temp > 0) {
          out.liquidTemp = Math.round(temp * 10) / 10;
          out.liquidName = chName;
        }
        if (rpm !== null && rpm > 0) {
          out.pumpRpm = rpm;
        }
      }

      // Detect PSU (RM850i etc.)
      if (getDev.IsPSU || devName.indexOf("RM") !== -1 || devName.indexOf("PSU") !== -1 || desc === "Output Power" || chName === "Power Out") {
        if (watts !== null && (out.psuWatts === null || watts > (out.psuWatts || 0))) {
          out.psuWatts = Math.round(watts);
          out.psuName = devName;
        }
        if (chName.indexOf("VRM") !== -1 && temp !== null && temp > 0) {
          out.psuVrmTemp = Math.round(temp * 10) / 10;
        } else if (chName.indexOf("PSU") !== -1 && temp !== null && temp > 0) {
          out.psuTemp = Math.round(temp * 10) / 10;
        }
        if (chName.indexOf("Rail") !== -1) {
          out.psuRails[chName] = {
            watts: watts !== null ? Math.round(watts * 10) / 10 : 0,
            volts: ch.volts !== undefined ? Number(ch.volts) : 0,
            amps: ch.amps !== undefined ? Number(ch.amps) : 0
          };
        }
      }

      // Detect RAM Temperature (Dominator Titanium etc.)
      if (chName.indexOf("DOMINATOR") !== -1 || devName.indexOf("Memory") !== -1 || desc.indexOf("Memory") !== -1) {
        if (temp !== null && temp > 0 && (out.ramTemp === null || temp > out.ramTemp)) {
          out.ramTemp = Math.round(temp * 10) / 10;
        }
      }

      // Detect Fans
      if (desc === "Fan" || chName.indexOf("Fan") !== -1) {
        hasFans = true;
        if (rpm !== null) {
          totalFanRpm += rpm;
          fanCount++;
          if (rpm > maxFan) maxFan = rpm;
          out.fans.push({
            devId: devId,
            devName: devName,
            channelId: chId,
            name: chName,
            rpm: rpm,
            profile: profile
          });
        }
      }

      // Detect Probes
      if (desc === "Probe" || chName.indexOf("Probe") !== -1 || (chName.indexOf("Temperature") !== -1 && desc !== "AIO")) {
        if (temp !== null && temp > 0) {
          out.probes.push({
            devId: devId,
            devName: devName,
            channelId: chId,
            name: chName,
            temp: Math.round(temp * 10) / 10
          });
        }
      }

      devChannelsList.push({
        id: chId,
        name: chName,
        desc: desc,
        rpm: rpm,
        temp: temp,
        watts: watts,
        profile: profile
      });
    }

    if (hasFans) out.fanControllableDevices.push(devId);
    if (hasRgb) out.rgbControllableDevices.push(devId);

    out.devices.push({
      id: devId,
      name: devName,
      hasFans: hasFans,
      hasRgb: hasRgb,
      channels: devChannelsList
    });
  }

  if (fanCount > 0) {
    out.maxFanRpm = maxFan;
    out.avgFanRpm = Math.round(totalFanRpm / fanCount);
  }

  return out;
}

function getMetricInfo(metricId) {
  for (var i = 0; i < METRICS.length; i++) {
    if (METRICS[i].id === metricId) return METRICS[i];
  }
  return METRICS[0];
}

function formatBarBadge(data, metricId) {
  if (!data || !data.connected) {
    return {
      icon: "󰌢",
      text: "Offline",
      fullText: "OpenLinkHub Offline",
      label: "Offline",
      isWarning: false,
      isUrgent: true,
      raw: null
    };
  }

  var mId = metricId || "liquid_temp";

  if (mId === "liquid_temp") {
    var lTemp = data.liquidTemp !== null ? data.liquidTemp : data.cpuTemp;
    if (lTemp === null) return { icon: "󰌢", text: "--°", fullText: "Liquid Temp: --", label: "Ciecz", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰌢",
      text: lTemp.toFixed(1) + "°",
      fullText: lTemp.toFixed(1) + " °C (Ciecz)",
      label: "Ciecz",
      isWarning: lTemp >= 45,
      isUrgent: lTemp >= 55,
      raw: lTemp
    };
  }

  if (mId === "psu_power") {
    var pWatts = data.psuWatts;
    if (pWatts === null) return { icon: "󱐋", text: "--W", fullText: "PSU Power: --", label: "Zasilacz", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󱐋",
      text: Math.round(pWatts) + "W",
      fullText: Math.round(pWatts) + " W (Zasilacz)",
      label: "Zasilacz",
      isWarning: pWatts >= 650,
      isUrgent: pWatts >= 780,
      raw: pWatts
    };
  }

  if (mId === "cpu_temp") {
    var cTemp = data.cpuTemp;
    if (cTemp === null) return { icon: "󰍛", text: "--°", fullText: "CPU Temp: --", label: "CPU", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰍛",
      text: Math.round(cTemp) + "°",
      fullText: cTemp.toFixed(1) + " °C (CPU)",
      label: "CPU",
      isWarning: cTemp >= 75,
      isUrgent: cTemp >= 88,
      raw: cTemp
    };
  }

  if (mId === "gpu_temp") {
    var gTemp = data.gpuTemp;
    if (gTemp === null) return { icon: "󰢮", text: "--°", fullText: "GPU Temp: --", label: "GPU", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰢮",
      text: Math.round(gTemp) + "°",
      fullText: gTemp.toFixed(1) + " °C (GPU)",
      label: "GPU",
      isWarning: gTemp >= 75,
      isUrgent: gTemp >= 85,
      raw: gTemp
    };
  }

  if (mId === "ram_temp") {
    var rTemp = data.ramTemp;
    if (rTemp === null) return { icon: "󰘚", text: "--°", fullText: "RAM Temp: --", label: "RAM", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰘚",
      text: rTemp.toFixed(1) + "°",
      fullText: rTemp.toFixed(1) + " °C (RAM)",
      label: "RAM",
      isWarning: rTemp >= 55,
      isUrgent: rTemp >= 65,
      raw: rTemp
    };
  }

  if (mId === "pump_rpm") {
    var pRpm = data.pumpRpm;
    if (pRpm === null) return { icon: "󰈐", text: "--", fullText: "Pompa: -- RPM", label: "Pompa", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰈐",
      text: String(pRpm),
      fullText: pRpm + " RPM (Pompa AIO)",
      label: "Pompa",
      isWarning: pRpm < 800,
      isUrgent: pRpm < 400,
      raw: pRpm
    };
  }

  if (mId === "fan_rpm") {
    var fRpm = data.maxFanRpm;
    if (fRpm === null) return { icon: "󰠝", text: "--", fullText: "Wentylatory: -- RPM", label: "Wentylator", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰠝",
      text: String(fRpm),
      fullText: fRpm + " RPM (Wentylatory)",
      label: "Wentylator",
      isWarning: fRpm >= 1800,
      isUrgent: fRpm >= 2200,
      raw: fRpm
    };
  }

  if (mId === "psu_vrm_temp") {
    var vTemp = data.psuVrmTemp;
    if (vTemp === null) return { icon: "󰏈", text: "--°", fullText: "PSU VRM: --", label: "PSU VRM", isWarning: false, isUrgent: false, raw: null };
    return {
      icon: "󰏈",
      text: vTemp.toFixed(1) + "°",
      fullText: vTemp.toFixed(1) + " °C (PSU VRM)",
      label: "PSU VRM",
      isWarning: vTemp >= 65,
      isUrgent: vTemp >= 80,
      raw: vTemp
    };
  }

  return { icon: "󰌢", text: "--", fullText: "--", label: "", isWarning: false, isUrgent: false, raw: null };
}

function cycleNextMetric(currentId) {
  var idx = 0;
  for (var i = 0; i < METRICS.length; i++) {
    if (METRICS[i].id === currentId) {
      idx = (i + 1) % METRICS.length;
      return METRICS[idx].id;
    }
  }
  return METRICS[0].id;
}

function formatTooltip(data, currentMetricId) {
  if (!data || !data.connected) {
    return "OpenLinkHub: Offline (nie połączono z http://localhost:27003)";
  }

  var lines = ["OpenLinkHub · Status sprzętu:"];
  if (data.liquidTemp !== null) lines.push("• Temperatura cieczy: " + data.liquidTemp.toFixed(1) + "°C (" + (data.liquidName || "AIO") + ")");
  if (data.pumpRpm !== null) lines.push("• Obroty pompy: " + data.pumpRpm + " RPM");
  if (data.psuWatts !== null) lines.push("• Pobór mocy (PSU): " + Math.round(data.psuWatts) + " W (" + (data.psuName || "Zasilacz") + ")");
  if (data.cpuTemp !== null) lines.push("• CPU: " + data.cpuTemp.toFixed(1) + "°C");
  if (data.gpuTemp !== null) lines.push("• GPU: " + data.gpuTemp.toFixed(1) + "°C");
  if (data.ramTemp !== null) lines.push("• Pamięć RAM: " + data.ramTemp.toFixed(1) + "°C");
  lines.push("• Profil wentylatorów: " + (data.activeFanProfile || "Quiet"));
  lines.push("• Tryb RGB: " + (data.activeRgbMode || "wave"));
  lines.push("");
  lines.push("Kliknij lewym: Otwórz panel sterowania");
  lines.push("Kliknij prawym: Zmień wyświetlany status na pasku");
  lines.push("Kliknij środkowym: Odśwież dane");

  return lines.join("\n");
}
