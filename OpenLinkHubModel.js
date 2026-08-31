.pragma library

// OpenLinkHub Model & Helper Utilities for Omarchy shell plugin
// Handles API parsing, multi-language i18n, device sensor consolidation, fan & RGB presets.

var I18N = {
  en: {
    langName: "EN",
    offline: "Offline",
    connected: "Connected",
    defaultOnBar: "BAR",
    setAsDefault: "Click to set as bar metric",
    webUi: "󰖟 Open Web UI",
    refresh: "󰑐 Refresh (R)",
    fanProfiles: "FAN PROFILES",
    activeProfile: "ACTIVE",
    rgbModes: "RGB LIGHTING MODES",
    activeMode: "MODE",
    brightness: "RGB BRIGHTNESS",
    devicesOverview: "HARDWARE DEVICES & SENSORS",
    systemSensors: "System Sensors",
    liquidCooler: "iCUE LINK Liquid Cooler",
    coolantTemp: "Coolant Temp",
    pumpSpeed: "Pump Speed",
    psu: "Corsair RM850i Power Supply",
    psuPower: "Total Output Power",
    rail12v: "12V Rail",
    rail5v: "5V Rail",
    rail3v: "3.3V Rail",
    vrmTemp: "VRM Temperature",
    psuTemp: "PSU Internal Temp",
    commanderPro: "Corsair Commander Pro",
    memory: "Dominator Titanium Memory",
    cpu: "CPU Package",
    gpu: "GPU Core",
    ram: "RAM Memory",
    fans: "Fans",
    probes: "Thermal Probes",
    toastDefault: "󰄬 Set as default bar metric: ",
    toastFan: "󰄬 Applied fan profile: ",
    toastRgb: "󰄬 Applied RGB mode: ",
    toastErrorFan: "Error applying fan profile",
    toastErrorRgb: "Error applying RGB mode",
    tooltipTitle: "OpenLinkHub Hardware Monitor",
    clickHint: "• Left click: Panel\n• Right click: Next sensor\n• Middle click: Refresh"
  },
  pl: {
    langName: "PL",
    offline: "Offline",
    connected: "Połączono",
    defaultOnBar: "PASEK",
    setAsDefault: "Kliknij, aby ustawić na pasku",
    webUi: "󰖟 Otwórz Web UI",
    refresh: "󰑐 Odśwież (R)",
    fanProfiles: "PROFILE WENTYLATORÓW",
    activeProfile: "AKTYWNY",
    rgbModes: "TRYBY OŚWIETLENIA (RGB)",
    activeMode: "TRYB",
    brightness: "JASNOŚĆ RGB",
    devicesOverview: "URZĄDZENIA I CZUJNIKI SPRZĘTU",
    systemSensors: "Sensory Systemowe",
    liquidCooler: "Chłodzenie Cieczą (iCUE LINK)",
    coolantTemp: "Temperatura cieczy",
    pumpSpeed: "Obroty pompy",
    psu: "Zasilacz Corsair RM850i",
    psuPower: "Łączna moc (Power Out)",
    rail12v: "Linia 12V",
    rail5v: "Linia 5V",
    rail3v: "Linia 3.3V",
    vrmTemp: "Temperatura VRM",
    psuTemp: "Temperatura zasilacza",
    commanderPro: "Kontroler Corsair Commander Pro",
    memory: "Pamięć Dominator Titanium",
    cpu: "Procesor (CPU)",
    gpu: "Karta graficzna (GPU)",
    ram: "Pamięć RAM",
    fans: "Wentylatory",
    probes: "Sondy temperatur",
    toastDefault: "󰄬 Ustawiono jako domyślną statystykę: ",
    toastFan: "󰄬 Zastosowano profil wentylatorów: ",
    toastRgb: "󰄬 Zastosowano tryb RGB: ",
    toastErrorFan: "Błąd zmiany profilu wentylatorów",
    toastErrorRgb: "Błąd zmiany trybu RGB",
    tooltipTitle: "OpenLinkHub · Stan sprzętu",
    clickHint: "• Lewy klik: Panel\n• Prawy klik: Kolejny czujnik\n• Środkowy klik: Odśwież"
  }
};

function t(key, lang) {
  var l = (lang === "pl") ? "pl" : "en";
  var dict = I18N[l] || I18N.en;
  return dict[key] !== undefined ? dict[key] : (I18N.en[key] || key);
}

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

      // Detect RAM Temperature
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
            temp: temp,
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
        volts: ch.volts,
        amps: ch.amps,
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

// Build consolidated device groups with individual clickable sensors
function getDeviceGroups(data, lang) {
  var groups = [];
  if (!data || !data.connected) return groups;

  // 1. iCUE LINK Liquid Cooler & System Hub
  var linkSensors = [];
  if (data.liquidTemp !== null && data.liquidTemp !== undefined) {
    linkSensors.push({
      key: "liquid_temp",
      label: t("coolantTemp", lang),
      icon: "💧",
      value: data.liquidTemp.toFixed(1) + " °C",
      raw: data.liquidTemp,
      unit: "°C"
    });
  }
  if (data.pumpRpm !== null && data.pumpRpm !== undefined) {
    linkSensors.push({
      key: "pump_rpm",
      label: t("pumpSpeed", lang),
      icon: "󰈐",
      value: data.pumpRpm + " RPM",
      raw: data.pumpRpm,
      unit: "RPM"
    });
  }
  // iCUE LINK fans
  for (var i = 0; i < data.fans.length; i++) {
    var f = data.fans[i];
    if (f.devName.indexOf("LINK") !== -1 || f.devName.indexOf("H150") !== -1 || f.devId === "62605BBB76606751B331EACF1C495170") {
      var fanLabel = f.name + (f.temp ? (" (" + f.temp.toFixed(1) + "°C)") : "");
      linkSensors.push({
        key: "fan:" + f.devId + ":" + f.channelId,
        label: fanLabel,
        icon: "󰠝",
        value: f.rpm + " RPM" + (f.profile ? (" · " + f.profile) : ""),
        raw: f.rpm,
        unit: "RPM"
      });
    }
  }
  if (linkSensors.length > 0) {
    groups.push({
      id: "icue_link",
      title: (data.liquidName || "iCUE LINK H150i LCD") + " (" + t("liquidCooler", lang) + ")",
      icon: "💧",
      sensors: linkSensors
    });
  }

  // 2. Corsair RM850i PSU
  var psuSensors = [];
  if (data.psuWatts !== null && data.psuWatts !== undefined) {
    psuSensors.push({
      key: "psu_power",
      label: t("psuPower", lang),
      icon: "󱐋",
      value: Math.round(data.psuWatts) + " W",
      raw: data.psuWatts,
      unit: "W"
    });
  }
  if (data.psuRails["12V Rail"]) {
    var r12 = data.psuRails["12V Rail"];
    psuSensors.push({
      key: "psu_12v",
      label: t("rail12v", lang),
      icon: "󱐋",
      value: r12.watts + " W (" + r12.volts + "V / " + r12.amps + "A)",
      raw: r12.watts,
      unit: "W"
    });
  }
  if (data.psuRails["5V Rail"]) {
    var r5 = data.psuRails["5V Rail"];
    psuSensors.push({
      key: "psu_5v",
      label: t("rail5v", lang),
      icon: "󱐋",
      value: r5.watts + " W (" + r5.volts + "V / " + r5.amps + "A)",
      raw: r5.watts,
      unit: "W"
    });
  }
  if (data.psuRails["3V Rail"]) {
    var r3 = data.psuRails["3V Rail"];
    psuSensors.push({
      key: "psu_3v",
      label: t("rail3v", lang),
      icon: "󱐋",
      value: r3.watts + " W (" + r3.volts + "V / " + r3.amps + "A)",
      raw: r3.watts,
      unit: "W"
    });
  }
  if (data.psuVrmTemp !== null && data.psuVrmTemp !== undefined) {
    psuSensors.push({
      key: "psu_vrm_temp",
      label: t("vrmTemp", lang),
      icon: "󰏈",
      value: data.psuVrmTemp.toFixed(1) + " °C",
      raw: data.psuVrmTemp,
      unit: "°C"
    });
  }
  if (data.psuTemp !== null && data.psuTemp !== undefined) {
    psuSensors.push({
      key: "psu_temp",
      label: t("psuTemp", lang),
      icon: "󰏈",
      value: data.psuTemp.toFixed(1) + " °C",
      raw: data.psuTemp,
      unit: "°C"
    });
  }
  if (psuSensors.length > 0) {
    groups.push({
      id: "psu",
      title: data.psuName || t("psu", lang),
      icon: "󱐋",
      sensors: psuSensors
    });
  }

  // 3. Commander Pro Fans & Probes
  var cmdSensors = [];
  for (var j = 0; j < data.fans.length; j++) {
    var f2 = data.fans[j];
    if (f2.devName.indexOf("COMMANDER") !== -1 || f2.devId === "1005010593341009") {
      cmdSensors.push({
        key: "fan:" + f2.devId + ":" + f2.channelId,
        label: f2.name,
        icon: "󰠝",
        value: f2.rpm + " RPM" + (f2.profile ? (" · " + f2.profile) : ""),
        raw: f2.rpm,
        unit: "RPM"
      });
    }
  }
  for (var p = 0; p < data.probes.length; p++) {
    var pr = data.probes[p];
    if (pr.devName.indexOf("COMMANDER") !== -1 || pr.devId === "1005010593341009") {
      cmdSensors.push({
        key: "probe:" + pr.devId + ":" + pr.channelId,
        label: pr.name,
        icon: "󰏈",
        value: pr.temp.toFixed(1) + " °C",
        raw: pr.temp,
        unit: "°C"
      });
    }
  }
  if (cmdSensors.length > 0) {
    groups.push({
      id: "commander_pro",
      title: t("commanderPro", lang),
      icon: "󰠝",
      sensors: cmdSensors
    });
  }

  // 4. Memory (Dominator Titanium)
  var memSensors = [];
  if (data.ramTemp !== null && data.ramTemp !== undefined) {
    memSensors.push({
      key: "ram_temp",
      label: t("memory", lang),
      icon: "󰘚",
      value: data.ramTemp.toFixed(1) + " °C",
      raw: data.ramTemp,
      unit: "°C"
    });
  }
  if (memSensors.length > 0) {
    groups.push({
      id: "memory",
      title: t("memory", lang),
      icon: "󰘚",
      sensors: memSensors
    });
  }

  // 5. Host System Sensors (CPU / GPU)
  var sysSensors = [];
  if (data.cpuTemp !== null && data.cpuTemp !== undefined) {
    sysSensors.push({
      key: "cpu_temp",
      label: t("cpu", lang),
      icon: "󰍛",
      value: data.cpuTemp.toFixed(1) + " °C",
      raw: data.cpuTemp,
      unit: "°C"
    });
  }
  if (data.gpuTemp !== null && data.gpuTemp !== undefined) {
    sysSensors.push({
      key: "gpu_temp",
      label: t("gpu", lang),
      icon: "󰢮",
      value: data.gpuTemp.toFixed(1) + " °C",
      raw: data.gpuTemp,
      unit: "°C"
    });
  }
  if (sysSensors.length > 0) {
    groups.push({
      id: "system",
      title: t("systemSensors", lang),
      icon: "󰍛",
      sensors: sysSensors
    });
  }

  return groups;
}

// Resolve bar badge for any selected sensor key
function resolveBarBadge(data, sensorKey, lang) {
  if (!data || !data.connected) {
    return {
      icon: "💧",
      text: t("offline", lang),
      fullText: "OpenLinkHub: " + t("offline", lang),
      label: t("offline", lang),
      raw: null
    };
  }

  var key = sensorKey || "liquid_temp";

  // Standard Presets
  if (key === "liquid_temp") {
    var lt = data.liquidTemp !== null && data.liquidTemp !== undefined ? data.liquidTemp : data.cpuTemp;
    if (lt === null || lt === undefined) return { icon: "💧", text: "--°", fullText: t("coolantTemp", lang) + ": --", label: t("coolantTemp", lang), raw: null };
    return { icon: "💧", text: lt.toFixed(1) + "°", fullText: lt.toFixed(1) + " °C (" + t("coolantTemp", lang) + ")", label: t("coolantTemp", lang), raw: lt };
  }

  if (key === "psu_power") {
    var pw = data.psuWatts;
    if (pw === null || pw === undefined) return { icon: "󱐋", text: "--W", fullText: t("psuPower", lang) + ": --", label: t("psuPower", lang), raw: null };
    return { icon: "󱐋", text: Math.round(pw) + "W", fullText: Math.round(pw) + " W (" + t("psuPower", lang) + ")", label: t("psuPower", lang), raw: pw };
  }

  if (key === "psu_12v") {
    var r12 = data.psuRails["12V Rail"];
    var w12 = r12 ? r12.watts : 0;
    return { icon: "󱐋", text: Math.round(w12) + "W", fullText: w12 + " W (" + t("rail12v", lang) + ")", label: t("rail12v", lang), raw: w12 };
  }

  if (key === "cpu_temp") {
    var ct = data.cpuTemp;
    if (ct === null || ct === undefined) return { icon: "󰍛", text: "--°", fullText: t("cpu", lang) + ": --", label: t("cpu", lang), raw: null };
    return { icon: "󰍛", text: Math.round(ct) + "°", fullText: ct.toFixed(1) + " °C (" + t("cpu", lang) + ")", label: t("cpu", lang), raw: ct };
  }

  if (key === "gpu_temp") {
    var gt = data.gpuTemp;
    if (gt === null || gt === undefined) return { icon: "󰢮", text: "--°", fullText: t("gpu", lang) + ": --", label: t("gpu", lang), raw: null };
    return { icon: "󰢮", text: Math.round(gt) + "°", fullText: gt.toFixed(1) + " °C (" + t("gpu", lang) + ")", label: t("gpu", lang), raw: gt };
  }

  if (key === "ram_temp") {
    var rt = data.ramTemp;
    if (rt === null || rt === undefined) return { icon: "󰘚", text: "--°", fullText: t("ram", lang) + ": --", label: t("ram", lang), raw: null };
    return { icon: "󰘚", text: rt.toFixed(1) + "°", fullText: rt.toFixed(1) + " °C (" + t("ram", lang) + ")", label: t("ram", lang), raw: rt };
  }

  if (key === "pump_rpm") {
    var pr = data.pumpRpm;
    if (pr === null || pr === undefined) return { icon: "󰈐", text: "--", fullText: t("pumpSpeed", lang) + ": --", label: t("pumpSpeed", lang), raw: null };
    return { icon: "󰈐", text: String(pr), fullText: pr + " RPM (" + t("pumpSpeed", lang) + ")", label: t("pumpSpeed", lang), raw: pr };
  }

  if (key === "fan_rpm") {
    var fr = data.maxFanRpm;
    if (fr === null || fr === undefined) return { icon: "󰠝", text: "--", fullText: t("fans", lang) + ": --", label: t("fans", lang), raw: null };
    return { icon: "󰠝", text: String(fr), fullText: fr + " RPM (" + t("fans", lang) + ")", label: t("fans", lang), raw: fr };
  }

  if (key === "psu_vrm_temp") {
    var vt = data.psuVrmTemp;
    if (vt === null || vt === undefined) return { icon: "󰏈", text: "--°", fullText: t("vrmTemp", lang) + ": --", label: t("vrmTemp", lang), raw: null };
    return { icon: "󰏈", text: vt.toFixed(1) + "°", fullText: vt.toFixed(1) + " °C (" + t("vrmTemp", lang) + ")", label: t("vrmTemp", lang), raw: vt };
  }

  // Individual Fan Sensor: fan:<devId>:<channelId>
  if (key.indexOf("fan:") === 0) {
    var parts = key.split(":");
    var dId = parts[1];
    var cId = parts[2];
    for (var i = 0; i < data.fans.length; i++) {
      var fan = data.fans[i];
      if (fan.devId === dId && String(fan.channelId) === String(cId)) {
        return {
          icon: "󰠝",
          text: String(fan.rpm),
          fullText: fan.rpm + " RPM (" + fan.name + ")",
          label: fan.name,
          raw: fan.rpm
        };
      }
    }
  }

  // Individual Probe Sensor: probe:<devId>:<channelId>
  if (key.indexOf("probe:") === 0) {
    var pParts = key.split(":");
    var pdId = pParts[1];
    var pcId = pParts[2];
    for (var k = 0; k < data.probes.length; k++) {
      var probe = data.probes[k];
      if (probe.devId === pdId && String(probe.channelId) === String(pcId)) {
        return {
          icon: "󰏈",
          text: probe.temp.toFixed(1) + "°",
          fullText: probe.temp.toFixed(1) + " °C (" + probe.name + ")",
          label: probe.name,
          raw: probe.temp
        };
      }
    }
  }

  return { icon: "💧", text: "--", fullText: "--", label: "", raw: null };
}

// Get ordered list of sensor keys for right-click cycling
function getCycleSensorKeys(data) {
  var list = ["liquid_temp", "psu_power", "cpu_temp", "gpu_temp", "ram_temp", "pump_rpm", "fan_rpm", "psu_vrm_temp"];
  if (data && data.fans) {
    for (var i = 0; i < data.fans.length; i++) {
      list.push("fan:" + data.fans[i].devId + ":" + data.fans[i].channelId);
    }
  }
  return list;
}

function cycleNextSensor(data, currentKey) {
  var keys = getCycleSensorKeys(data);
  var idx = keys.indexOf(currentKey);
  if (idx === -1) return keys[0];
  return keys[(idx + 1) % keys.length];
}

// Left-aligned multi-line tooltip text
function formatTooltip(data, currentKey, lang) {
  if (!data || !data.connected) {
    return t("tooltipTitle", lang) + "\nStatus: " + t("offline", lang) + "\nhttp://localhost:27003\n\n" + t("clickHint", lang);
  }

  var lines = [];
  lines.push(t("tooltipTitle", lang) + " (" + t("connected", lang) + ")");
  lines.push("────────────────────────────────────────");
  if (data.liquidTemp !== null && data.liquidTemp !== undefined) {
    lines.push("💧 " + t("coolantTemp", lang) + ": " + data.liquidTemp.toFixed(1) + " °C (" + (data.liquidName || "AIO") + ")");
  }
  if (data.pumpRpm !== null && data.pumpRpm !== undefined) {
    lines.push("󰈐 " + t("pumpSpeed", lang) + ": " + data.pumpRpm + " RPM");
  }
  if (data.psuWatts !== null && data.psuWatts !== undefined) {
    lines.push("󱐋 " + t("psuPower", lang) + ": " + Math.round(data.psuWatts) + " W (" + (data.psuName || "RM850i") + ")");
  }
  if (data.cpuTemp !== null && data.cpuTemp !== undefined) {
    lines.push("󰍛 " + t("cpu", lang) + ": " + data.cpuTemp.toFixed(1) + " °C");
  }
  if (data.gpuTemp !== null && data.gpuTemp !== undefined) {
    lines.push("󰢮 " + t("gpu", lang) + ": " + data.gpuTemp.toFixed(1) + " °C");
  }
  if (data.ramTemp !== null && data.ramTemp !== undefined) {
    lines.push("󰘚 " + t("ram", lang) + ": " + data.ramTemp.toFixed(1) + " °C");
  }
  if (data.maxFanRpm !== null && data.maxFanRpm !== undefined) {
    lines.push("󰠝 " + t("fans", lang) + ": " + data.fans.length + " fans (Max " + data.maxFanRpm + " RPM · " + (data.activeFanProfile || "Quiet") + ")");
  }
  lines.push("󰏌 " + t("rgbModes", lang) + ": " + (data.activeRgbMode || "wave").toUpperCase());
  lines.push("────────────────────────────────────────");
  lines.push(t("clickHint", lang));

  return lines.join("\n");
}
