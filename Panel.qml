import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "OpenLinkHubModel.js" as Model

Panel {
  id: root
  moduleName: "hubi.openlinkhub"
  ipcTarget: "hubi.openlinkhub"

  property string apiUrl: root.setting("apiUrl", "http://localhost:27003")
  property string displayMetric: root.setting("displayMetric", "liquid_temp")
  property string lang: root.setting("lang", "en")
  property bool themeSync: root.setting("themeSync", false)
  property string primaryColorHex: root.setting("primaryColor", "#06b6d4")
  property string secondaryColorHex: root.setting("secondaryColor", "#3b82f6")
  property var themeColorsMap: root.setting("themeColorsMap", ({}))
  property string activeThemeSlug: "vantablack"
  property int pollInterval: root.setting("pollInterval", 2000)

  property bool connected: false
  property var rawData: Model.emptyData()
  property string statusMessage: ""
  property var badge: Model.resolveBarBadge(root.rawData, root.displayMetric, root.lang)

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string themeAccentHex: Model.colorToHex(Color.accent)
  readonly property string themeSecondaryHex: Model.colorToHex(Color.warning)

  readonly property string activePrimaryHex: root.primaryColorHex
  readonly property string activeSecondaryHex: root.secondaryColorHex
  readonly property string activeRgbMode: (root.rawData && root.rawData.activeRgbMode) ? root.rawData.activeRgbMode : "wave"
  readonly property bool activeModeSupportsColor: Model.modeSupportsCustomColors(root.activeRgbMode)

  readonly property string barText: root.connected ? (root.badge.icon + " " + root.badge.text) : "󰔏 !"
  readonly property string tooltipText: Model.formatTooltip(root.rawData, root.displayMetric, root.lang)

  function t(key) {
    return Model.t(key, root.lang)
  }

  function toggleLanguage() {
    var nextLang = (root.lang === "en") ? "pl" : "en"
    root.lang = nextLang
    root.badge = Model.resolveBarBadge(root.rawData, root.displayMetric, nextLang)
    saveSetting("lang", nextLang)
  }

  function toggleThemeSync() {
    var nextSync = !root.themeSync
    root.themeSync = nextSync
    saveSetting("themeSync", nextSync)
    if (nextSync) {
      root.statusMessage = Model.t("toastThemeSyncOn", root.lang) + root.themeAccentHex
      setCustomColor(true, root.themeAccentHex)
      setCustomColor(false, root.themeSecondaryHex)
    } else {
      root.statusMessage = Model.t("toastThemeSyncOff", root.lang)
      applyRgbColors(root.activeRgbMode, root.primaryColorHex, root.secondaryColorHex)
    }
  }

  function setCustomColor(isPrimary, hex) {
    var targetMode = root.activeRgbMode
    if (!Model.modeSupportsCustomColors(targetMode)) {
      targetMode = "static"
      if (root.rawData) root.rawData.activeRgbMode = "static"
    }

    var newP1 = isPrimary ? hex : root.primaryColorHex
    var newP2 = isPrimary ? root.secondaryColorHex : hex

    if (isPrimary) {
      root.primaryColorHex = hex
      saveSetting("primaryColor", hex)
    } else {
      root.secondaryColorHex = hex
      saveSetting("secondaryColor", hex)
    }

    // Save into theme memory
    var currentMap = Object.assign({}, root.themeColorsMap)
    currentMap[root.activeThemeSlug] = { primary: newP1, secondary: newP2 }
    root.themeColorsMap = currentMap
    saveSetting("themeColorsMap", currentMap)

    // Persist to state file
    var jsonPayload = JSON.stringify(currentMap).replace(/'/g, "'\\''")
    Quickshell.execDetached(["bash", "-c", "echo '" + jsonPayload + "' > ~/.local/state/omarchy/openlinkhub-theme-colors.json"])

    applyRgbColors(targetMode, newP1, newP2)
    root.statusMessage = Model.t("toastColors", root.lang) + root.activeThemeSlug + ": " + newP1 + " / " + newP2
  }

  function setDefaultMetric(sensorKey) {
    root.displayMetric = sensorKey
    root.badge = Model.resolveBarBadge(root.rawData, sensorKey, root.lang)
    root.statusMessage = Model.t("toastDefault", root.lang) + root.badge.label + " (" + root.badge.text + ")"
    saveSetting("displayMetric", sensorKey)
  }

  function saveSetting(key, val) {
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      var entry = {}
      var cur = root.bar.shell.entryFor(root.moduleName) || {}
      for (var k in cur) if (k !== "id") entry[k] = cur[k]
      entry[key] = val
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function cycleMetric() {
    var next = Model.cycleNextSensor(root.rawData, root.displayMetric)
    setDefaultMetric(next)
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  function openWebUi() {
    Quickshell.execDetached(["xdg-open", root.apiUrl])
  }

  // --- Theme color change listener ---
  Connections {
    target: Color
    function onAccentChanged() {
      if (root.themeSync && Model.modeSupportsCustomColors(root.activeRgbMode)) {
        root.setCustomColor(true, Model.colorToHex(Color.accent))
        root.setCustomColor(false, Model.colorToHex(Color.warning))
      }
    }
  }

  // --- Apply Fan Speed Profile to All Controllable Devices & Channels ---
  Process {
    id: setFanProc
    property string profileName: ""
    onExited: function(code) {
      if (code === 0) {
        root.statusMessage = Model.t("toastFan", root.lang) + profileName
        root.refresh()
      } else {
        root.statusMessage = Model.t("toastErrorFan", root.lang)
      }
    }
  }

  function applyFanProfile(profileName) {
    if (setFanProc.running) setFanProc.running = false
    setFanProc.profileName = profileName
    if (root.rawData) root.rawData.activeFanProfile = profileName

    var script = ""
    var fanDevs = (root.rawData && root.rawData.fanControllableDevices && root.rawData.fanControllableDevices.length > 0)
      ? root.rawData.fanControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "1005010593341009"]

    // 1. Device-level broadcast (-1)
    for (var i = 0; i < fanDevs.length; i++) {
      var pGlobal = JSON.stringify({ deviceId: fanDevs[i], channelId: -1, profile: profileName })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + pGlobal + "' " + root.apiUrl + "/api/speed >/dev/null 2>&1; "
    }

    // 2. Per-channel broadcast (mandatory for Commander Pro)
    var allFans = (root.rawData && Array.isArray(root.rawData.fans) && root.rawData.fans.length > 0)
      ? root.rawData.fans
      : [
          { devId: "1005010593341009", channelId: 0 },
          { devId: "1005010593341009", channelId: 1 },
          { devId: "1005010593341009", channelId: 2 },
          { devId: "1005010593341009", channelId: 3 },
          { devId: "1005010593341009", channelId: 4 },
          { devId: "1005010593341009", channelId: 5 },
          { devId: "62605BBB76606751B331EACF1C495170", channelId: 1 },
          { devId: "62605BBB76606751B331EACF1C495170", channelId: 13 },
          { devId: "62605BBB76606751B331EACF1C495170", channelId: 14 },
          { devId: "62605BBB76606751B331EACF1C495170", channelId: 15 },
          { devId: "62605BBB76606751B331EACF1C495170", channelId: 17 }
        ]

    for (var j = 0; j < allFans.length; j++) {
      var f = allFans[j]
      var pCh = JSON.stringify({ deviceId: f.devId, channelId: parseInt(f.channelId, 10), profile: profileName })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + pCh + "' " + root.apiUrl + "/api/speed >/dev/null 2>&1; "
    }

    setFanProc.command = ["bash", "-c", script]
    setFanProc.running = true
  }

  // --- Apply RGB Mode & Colors ---
  Process {
    id: setRgbProc
    property string rgbModeName: ""
    onExited: function(code) {
      if (code === 0) {
        root.statusMessage = Model.t("toastRgb", root.lang) + rgbModeName
        root.refresh()
      } else {
        root.statusMessage = Model.t("toastErrorRgb", root.lang)
      }
    }
  }

  function applyRgbMode(rgbMode) {
    if (setRgbProc.running) setRgbProc.running = false
    setRgbProc.rgbModeName = rgbMode
    if (root.rawData) root.rawData.activeRgbMode = rgbMode

    if (Model.modeSupportsCustomColors(rgbMode)) {
      applyRgbColors(rgbMode, root.activePrimaryHex, root.activeSecondaryHex)
    } else {
      var targets = ["cluster", "62605BBB76606751B331EACF1C495170", "1005010593341009", "1D700317A81C7CAF9619A75F051C00F5", "i2c11"]
      var script = "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"deviceId\":\"cluster\",\"channelId\":0,\"profile\":\"" + rgbMode + "\"}' " + root.apiUrl + "/api/color >/dev/null 2>&1; "
      for (var i = 1; i < targets.length; i++) {
        script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"deviceId\":\"" + targets[i] + "\",\"channelId\":-1,\"profile\":\"" + rgbMode + "\"}' " + root.apiUrl + "/api/color >/dev/null 2>&1; "
      }
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"profile\":\"" + rgbMode + "\"}' " + root.apiUrl + "/api/color/global >/dev/null 2>&1; "
      setRgbProc.command = ["bash", "-c", script]
      setRgbProc.running = true
    }
  }

  // --- Apply Custom Colors via PUT /api/color/change and Instant Bounce Reload ---
  Process {
    id: setColorsProc
    onExited: function(code) {
      root.refresh()
    }
  }

  function applyRgbColors(mode, primaryHex, secondaryHex) {
    if (setColorsProc.running) setColorsProc.running = false
    var targetMode = mode
    if (!Model.modeSupportsCustomColors(targetMode)) {
      targetMode = "static"
      if (root.rawData) root.rawData.activeRgbMode = "static"
    }

    var p1 = Model.hexToRgb(primaryHex)
    var p2 = Model.hexToRgb(secondaryHex)
    var targets = ["cluster", "62605BBB76606751B331EACF1C495170", "1005010593341009", "1D700317A81C7CAF9619A75F051C00F5", "i2c11"]
    var script = ""

    // 1. Update color configuration for cluster and all devices via PUT /api/color/change
    for (var i = 0; i < targets.length; i++) {
      var payload = JSON.stringify({
        deviceId: targets[i],
        profile: targetMode,
        startColor: p1,
        endColor: p2,
        middleColor: { red: 0, green: 0, blue: 0, temperature: 0 },
        speed: 2,
        alternateColors: false,
        rgbDirection: 0
      })
      script += "curl -s -L -X PUT -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/color/change >/dev/null 2>&1; "
    }

    // 2. Fast bounce transition on cluster to force hardware animation engine to immediately render new colors
    var bounceMode = (targetMode === "circle") ? "wave" : "circle"
    script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"deviceId\":\"cluster\",\"channelId\":0,\"profile\":\"" + bounceMode + "\"}' " + root.apiUrl + "/api/color >/dev/null 2>&1; "

    // 3. Immediately re-apply active mode
    script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"deviceId\":\"cluster\",\"channelId\":0,\"profile\":\"" + targetMode + "\"}' " + root.apiUrl + "/api/color >/dev/null 2>&1; "

    // 4. Global broadcast
    script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '{\"profile\":\"" + targetMode + "\"}' " + root.apiUrl + "/api/color/global >/dev/null 2>&1; "

    setColorsProc.command = ["bash", "-c", script]
    setColorsProc.running = true
  }

  // --- Apply Brightness ---
  Process {
    id: setBrightnessProc
  }

  function applyBrightness(level) {
    if (setBrightnessProc.running) setBrightnessProc.running = false
    var b = Math.max(0, Math.min(100, Math.round(level)))
    if (root.rawData) root.rawData.brightness = b
    var targets = ["cluster", "62605BBB76606751B331EACF1C495170", "1005010593341009", "1D700317A81C7CAF9619A75F051C00F5", "i2c11"]
    var script = ""
    for (var i = 0; i < targets.length; i++) {
      var payload = JSON.stringify({ deviceId: targets[i], brightness: b })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/brightness/gradual >/dev/null 2>&1; "
    }
    setBrightnessProc.command = ["bash", "-c", script]
    setBrightnessProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Polling Devices & Temperatures & Cluster RGB in Parallel ---
  Process {
    id: fetchProc
    command: ["bash", "-c", "curl -fsSL --max-time 2 " + root.apiUrl + "/api/devices/ && echo '===TEMPS===' && curl -fsSL --max-time 2 " + root.apiUrl + "/api/temperatures && echo '===RGB===' && curl -fsSL --max-time 2 " + root.apiUrl + "/api/color/cluster && echo '===THEME===' && cat ~/.local/state/omarchy/current/theme.name 2>/dev/null && echo '===SAVED===' && cat ~/.local/state/omarchy/openlinkhub-theme-colors.json 2>/dev/null || true"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw || raw.indexOf("{") !== 0) {
          root.connected = false
          root.badge = Model.resolveBarBadge(root.rawData, root.displayMetric, root.lang)
          return
        }
        var parsed = Model.parseOpenLinkHubData(raw)
        root.rawData = parsed
        root.connected = parsed.connected
        root.badge = Model.resolveBarBadge(parsed, root.displayMetric, root.lang)

        // Handle per-theme color memory
        if (parsed.currentThemeSlug && parsed.currentThemeSlug !== root.activeThemeSlug) {
          root.activeThemeSlug = parsed.currentThemeSlug
          var saved = (parsed.savedThemeColors && parsed.savedThemeColors[parsed.currentThemeSlug])
            ? parsed.savedThemeColors[parsed.currentThemeSlug]
            : (root.themeColorsMap[parsed.currentThemeSlug] || null)

          if (saved && saved.primary && saved.secondary) {
            root.primaryColorHex = saved.primary
            root.secondaryColorHex = saved.secondary
            root.applyRgbColors(root.activeRgbMode, saved.primary, saved.secondary)
          } else if (root.themeSync) {
            root.setCustomColor(true, root.themeAccentHex)
            root.setCustomColor(false, root.themeSecondaryHex)
          }
        }
      }
    }
  }

  // --- Bar Button on Right Section ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    slotSize: Style.bar.iconSlot * 2.3
    tooltipText: root.tooltipText
    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleMetric()
      else if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  // --- Popout Keyboard Panel ---
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(700))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        if (t === "s" || t === "S") root.toggleThemeSync()
        if (t === "l" || t === "L") root.toggleLanguage()
        var num = parseInt(t, 10)
        if (!isNaN(num) && num >= 1 && root.rawData && root.rawData.fanProfiles && num <= root.rawData.fanProfiles.length) {
          root.applyFanProfile(root.rawData.fanProfiles[num - 1].id)
        }
      }

      Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width - Style.space(10)
        contentHeight: panelColumn.implicitHeight + Style.space(24)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
          policy: ScrollBar.AlwaysOn
          active: true
          width: Style.space(6)
          contentItem: Rectangle {
            implicitWidth: Style.space(6)
            radius: width / 2
            color: Style.controlFill(false, parent.hovered || parent.pressed, root.fg, Color.accent)
          }
        }

        Column {
          id: panelColumn
          width: parent.width
          spacing: Style.space(12)

          // ---------- Hero: Primary Sensor & Language Switcher ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroItem.implicitHeight, langBtn.implicitHeight)

            PanelHero {
              id: heroItem
              anchors.left: parent.left
              anchors.right: langBtn.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              title: root.connected ? root.badge.fullText : ("OpenLinkHub: " + root.t("offline"))
              meta: root.connected
                ? (root.t("defaultOnBar") + ": " + root.badge.label)
                : ("http://localhost:27003 (" + root.t("offline") + ")")
              foreground: Color.accent
              fontFamily: root.ff
              iconComponent: Component {
                Text {
                  text: root.badge.icon
                  color: Color.accent
                  font.family: root.ff
                  font.pixelSize: Style.font.display
                }
              }
            }

            // Compact Language Switcher Button (EN / PL)
            Button {
              id: langBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "🌐 " + root.lang.toUpperCase()
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(4)
              onClicked: root.toggleLanguage()
            }
          }

          // ---------- Quick Action Buttons (Web UI + Theme Sync) ----------
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: root.t("webUi")
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.openWebUi()
            }

            Button {
              Layout.fillWidth: true
              text: root.themeSync ? ("🎨 " + root.t("themeSyncOn")) : ("🎨 " + root.t("themeSyncOff"))
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              selected: root.themeSync
              active: root.themeSync
              onClicked: root.toggleThemeSync()
            }
          }

          // ---------- Toast Feedback Message ----------
          Rectangle {
            visible: root.statusMessage !== ""
            width: parent.width
            height: statusTxt.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: Style.hoverFillFor(root.fg, Color.accent)

            Text {
              id: statusTxt
              anchors.centerIn: parent
              text: root.statusMessage
              color: Color.accent
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // ---------- Consolidated Section 1: Devices & Sensors ----------
          PanelSeparator { foreground: root.fg }

          Item {
            width: parent.width
            implicitHeight: Math.max(devHdr.implicitHeight, devHint.implicitHeight)

            PanelSectionHeader {
              id: devHdr
              text: root.t("devicesOverview")
              foreground: root.fg
              fontFamily: root.ff
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: devHint
              text: root.t("setAsDefault")
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Repeater {
            model: Model.getDeviceGroups(root.rawData, root.lang)

            DeviceCard {
              required property var modelData
              width: parent.width
              deviceGroup: modelData
              selectedMetric: root.displayMetric
              onSensorSelected: function(key) { root.setDefaultMetric(key) }
            }
          }

          // ---------- Section 2: Fan Speed Profiles (Dynamic from OpenLinkHub) ----------
          PanelSeparator { foreground: root.fg }

          Item {
            width: parent.width
            implicitHeight: Math.max(fanHeader.implicitHeight, activeFanText.implicitHeight)

            PanelSectionHeader {
              id: fanHeader
              text: root.t("fanProfiles")
              foreground: root.fg
              fontFamily: root.ff
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: activeFanText
              text: root.t("activeProfile") + ": " + (root.rawData ? (root.rawData.activeFanProfile || "Quiet").toUpperCase() : "QUIET")
              color: Color.accent
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing) / 2

            Repeater {
              model: root.rawData && root.rawData.fanProfiles && root.rawData.fanProfiles.length > 0
                ? root.rawData.fanProfiles
                : Model.DEFAULT_FAN_PROFILES

              Button {
                required property var modelData
                required property int index
                width: parent.cellWidth
                text: modelData.icon + "  " + (root.lang === "pl" ? (modelData.labelPl || modelData.name) : modelData.name) + " (" + (index + 1) + ")"
                fontFamily: root.ff
                fontSize: Style.font.caption
                bordered: true
                selected: (root.rawData && (root.rawData.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                active: (root.rawData && (root.rawData.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                onClicked: root.applyFanProfile(modelData.id)
              }
            }
          }

          // ---------- Section 3: RGB Modes, Theme Sync & Custom Colors ----------
          PanelSeparator { foreground: root.fg }

          Item {
            width: parent.width
            implicitHeight: Math.max(rgbHeader.implicitHeight, activeRgbText.implicitHeight)

            PanelSectionHeader {
              id: rgbHeader
              text: root.t("rgbModes")
              foreground: root.fg
              fontFamily: root.ff
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: activeRgbText
              text: root.t("activeMode") + ": " + (root.rawData ? (root.rawData.activeRgbMode || "wave").toUpperCase() : "WAVE")
              color: Color.accent
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Dynamic RGB Modes Grid from Cluster
          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing) / 2

            Repeater {
              model: root.rawData && root.rawData.rgbModes && root.rawData.rgbModes.length > 0
                ? root.rawData.rgbModes
                : Model.DEFAULT_RGB_MODES

              Button {
                required property var modelData
                width: parent.cellWidth
                text: modelData.icon + "  " + (root.lang === "pl" ? (modelData.labelPl || modelData.name) : modelData.name)
                fontFamily: root.ff
                fontSize: Style.font.caption
                bordered: true
                selected: (root.rawData && (root.rawData.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                active: (root.rawData && (root.rawData.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                opacity: (root.themeSync && !modelData.supportsColors) ? 0.45 : 1.0
                onClicked: root.applyRgbMode(modelData.id)
              }
            }
          }

          // ---------- RGB Color Customization / Theme Sync Panel ----------
          BorderSurface {
            width: parent.width
            radius: Style.cornerRadius
            color: Style.controlFill(false, false, root.fg, Color.accent)
            implicitHeight: colorCol.implicitHeight + Style.space(16)

            Column {
              id: colorCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Item {
                width: parent.width
                implicitHeight: Math.max(cTitle.implicitHeight, cHint.implicitHeight)

                Text {
                  id: cTitle
                  text: root.t("rgbColors")
                  color: root.fg
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: cHint
                  text: !root.activeModeSupportsColor
                    ? root.t("rainbowFixedNotice")
                    : (root.themeSync ? ("󰄬 " + root.t("themeSyncedNotice")) : (root.t("manualColorsNotice") + root.activeThemeSlug))
                  color: !root.activeModeSupportsColor ? Qt.darker(root.fg, 1.5) : Color.accent
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              // Color Palette Swatches (Primary / Accent & Secondary)
              Column {
                width: parent.width
                spacing: Style.space(6)
                opacity: 1.0

                Text {
                  text: root.t("primaryColor") + ": " + root.activePrimaryHex.toUpperCase()
                  color: Qt.darker(root.fg, 1.2)
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Grid {
                  width: parent.width
                  columns: 7
                  spacing: Style.space(6)
                  readonly property real swatchWidth: (width - (spacing * 6)) / 7

                  Repeater {
                    model: Model.COLOR_PALETTES
                    Rectangle {
                      id: pSwatch
                      required property var modelData
                      width: parent.swatchWidth
                      height: Style.space(22)
                      radius: Style.space(4)
                      color: modelData.hex
                      border.color: (root.activePrimaryHex.toLowerCase() === modelData.hex.toLowerCase()) ? Color.accent : Qt.darker(root.fg, 1.6)
                      border.width: (root.activePrimaryHex.toLowerCase() === modelData.hex.toLowerCase()) ? 2 : 1

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setCustomColor(true, pSwatch.modelData.hex)
                      }
                    }
                  }
                }

                Text {
                  text: root.t("secondaryColor") + ": " + root.activeSecondaryHex.toUpperCase()
                  color: Qt.darker(root.fg, 1.2)
                  font.family: root.ff
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.topMargin: Style.space(4)
                }

                Grid {
                  width: parent.width
                  columns: 7
                  spacing: Style.space(6)
                  readonly property real swatchWidth: (width - (spacing * 6)) / 7

                  Repeater {
                    model: Model.COLOR_PALETTES
                    Rectangle {
                      id: sSwatch
                      required property var modelData
                      width: parent.swatchWidth
                      height: Style.space(22)
                      radius: Style.space(4)
                      color: modelData.hex
                      border.color: (root.activeSecondaryHex.toLowerCase() === modelData.hex.toLowerCase()) ? Color.accent : Qt.darker(root.fg, 1.6)
                      border.width: (root.activeSecondaryHex.toLowerCase() === modelData.hex.toLowerCase()) ? 2 : 1

                      MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setCustomColor(false, sSwatch.modelData.hex)
                      }
                    }
                  }
                }
              }
            }
          }

          // Brightness Slider
          Item {
            width: parent.width
            implicitHeight: Math.max(brightLabel.implicitHeight, brightVal.implicitHeight)
            anchors.topMargin: Style.space(4)

            Text {
              id: brightLabel
              text: root.t("brightness")
              color: Qt.darker(root.fg, 1.4)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: brightVal
              text: ((root.rawData && root.rawData.brightness !== undefined) ? root.rawData.brightness : 100) + "%"
              color: root.fg
              font.family: root.ff
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          PanelSlider {
            width: parent.width
            bar: root.bar
            minimum: 0
            maximum: 100
            step: 5
            integer: true
            value: (root.rawData && root.rawData.brightness !== undefined) ? root.rawData.brightness : 100
            onMoved: function(v) { root.applyBrightness(v) }
            onReleased: function(v) { root.applyBrightness(v) }
          }

          Item {
            width: parent.width
            height: Style.space(10)
          }
        }
      }
    }
  }

  // --- Subcomponent: DeviceCard (Consolidated Device Sensor Box) ---
  component DeviceCard: BorderSurface {
    id: card
    property var deviceGroup: null
    property string selectedMetric: ""
    signal sensorSelected(string key)

    width: parent.width
    radius: Style.cornerRadius
    color: Style.controlFill(false, false, root.fg, Color.accent)
    implicitHeight: cardCol.implicitHeight + Style.space(16)

    Column {
      id: cardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      spacing: Style.space(6)

      // Device Title Header
      Row {
        spacing: Style.space(6)
        Text {
          text: card.deviceGroup ? card.deviceGroup.icon : ""
          color: Color.accent
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          text: card.deviceGroup ? card.deviceGroup.title : ""
          color: Qt.darker(root.fg, 1.2)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.6
        }
      }

      // Sensor Rows
      Repeater {
        model: card.deviceGroup ? card.deviceGroup.sensors : []

        BorderSurface {
          id: sensorRow
          required property var modelData
          readonly property bool isCurrent: card.selectedMetric === modelData.key
          width: cardCol.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: isCurrent
            ? Style.selectedFillFor(root.fg, Color.accent)
            : Style.controlFill(false, rowMouse.containsMouse, root.fg, Color.accent)
          borderSpec: isCurrent
            ? Border.controlSpec("focus", root.fg, Color.accent)
            : Border.controlSpec(rowMouse.containsMouse ? "hover-cursor" : "normal", root.fg, Color.accent)

          Item {
            anchors.fill: parent
            anchors.margins: Style.space(6)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: sensorRow.modelData.icon
                color: sensorRow.isCurrent ? Color.accent : (sensorRow.modelData.icon === "󰔏" ? "#38bdf8" : root.fg)
                font.family: root.ff
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                text: sensorRow.modelData.label
                color: sensorRow.isCurrent ? Color.accent : root.fg
                font.family: root.ff
                font.pixelSize: Style.font.bodySmall
                font.bold: sensorRow.isCurrent
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                visible: sensorRow.isCurrent
                text: "󰄬 " + root.t("defaultOnBar")
                color: Color.accent
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                text: sensorRow.modelData.value
                color: sensorRow.isCurrent ? Color.accent : root.fg
                font.family: root.ff
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.sensorSelected(sensorRow.modelData.key)
            onDoubleClicked: card.sensorSelected(sensorRow.modelData.key)
          }
        }
      }
    }
  }
}
