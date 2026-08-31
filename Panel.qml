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
  property int pollInterval: root.setting("pollInterval", 2000)

  property bool connected: false
  property var rawData: Model.emptyData()
  property string statusMessage: ""
  property var badge: Model.resolveBarBadge(root.rawData, root.displayMetric, root.lang)

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property string barText: root.connected ? (root.badge.icon + " " + root.badge.text) : "💧 !"
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

  // --- Apply Fan Profile ---
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
    if (setFanProc.running) return
    setFanProc.profileName = profileName
    if (root.rawData) root.rawData.activeFanProfile = profileName
    var devices = (root.rawData && root.rawData.fanControllableDevices && root.rawData.fanControllableDevices.length > 0)
      ? root.rawData.fanControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "1005010593341009"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], channelId: -1, profile: profileName })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/speed >/dev/null 2>&1; "
    }
    setFanProc.command = ["bash", "-c", script]
    setFanProc.running = true
  }

  // --- Apply RGB Mode ---
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
    if (setRgbProc.running) return
    setRgbProc.rgbModeName = rgbMode
    if (root.rawData) root.rawData.activeRgbMode = rgbMode
    var clusterPayload = JSON.stringify({ deviceId: "cluster", channelId: 0, profile: rgbMode })
    var script = "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + clusterPayload + "' " + root.apiUrl + "/api/color >/dev/null 2>&1; "

    var devices = (root.rawData && root.rawData.rgbControllableDevices && root.rawData.rgbControllableDevices.length > 0)
      ? root.rawData.rgbControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "i2c11"]
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], channelId: -1, profile: rgbMode })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/color >/dev/null 2>&1; "
    }
    setRgbProc.command = ["bash", "-c", script]
    setRgbProc.running = true
  }

  // --- Apply Brightness ---
  Process {
    id: setBrightnessProc
    onExited: function(code) { root.refresh() }
  }

  function applyBrightness(level) {
    var b = Math.max(0, Math.min(100, Math.round(level)))
    if (root.rawData) root.rawData.brightness = b
    var devices = ["cluster", "62605BBB76606751B331EACF1C495170", "i2c11"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], brightness: b })
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

  // --- Polling via curl ---
  Process {
    id: fetchProc
    command: ["curl", "-fsSL", "--max-time", "2", root.apiUrl + "/api/devices/"]
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
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        if (t === "l" || t === "L") root.toggleLanguage()
        if (t === "1") root.applyFanProfile("Quiet")
        if (t === "2") root.applyFanProfile("Balanced")
        if (t === "3") root.applyFanProfile("Performance")
        if (t === "4") root.applyFanProfile("Extreme")
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

          // ---------- Quick Action Buttons ----------
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
              text: root.t("refresh")
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.refresh()
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

          // ---------- Section 2: Fan Profiles ----------
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
              model: Model.FAN_PROFILES

              Button {
                required property var modelData
                required property int index
                width: parent.cellWidth
                text: modelData.icon + "  " + (root.lang === "pl" ? modelData.labelPl : modelData.name) + " (" + (index + 1) + ")"
                fontFamily: root.ff
                fontSize: Style.font.caption
                bordered: true
                selected: (root.rawData && (root.rawData.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                active: (root.rawData && (root.rawData.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                onClicked: root.applyFanProfile(modelData.id)
              }
            }
          }

          // ---------- Section 3: RGB Modes & Brightness ----------
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

          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing) / 2

            Repeater {
              model: Model.RGB_MODES

              Button {
                required property var modelData
                width: parent.cellWidth
                text: modelData.icon + "  " + (root.lang === "pl" ? modelData.labelPl : modelData.name)
                fontFamily: root.ff
                fontSize: Style.font.caption
                bordered: true
                selected: (root.rawData && (root.rawData.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                active: (root.rawData && (root.rawData.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                onClicked: root.applyRgbMode(modelData.id)
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
                color: sensorRow.isCurrent ? Color.accent : (sensorRow.modelData.icon === "💧" ? "#38bdf8" : root.fg)
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
