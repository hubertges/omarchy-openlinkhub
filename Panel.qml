import QtQuick
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
  property int pollInterval: root.setting("pollInterval", 2000)

  property bool connected: false
  property real liquidTemp: 0
  property string liquidName: ""
  property int pumpRpm: 0
  property int psuWatts: 0
  property string psuName: ""
  property real psuTemp: 0
  property real psuVrmTemp: 0
  property var psuRails: ({})
  property real cpuTemp: 0
  property real gpuTemp: 0
  property real ramTemp: 0
  property int fanRpm: 0
  property var fans: []
  property var rawData: Model.emptyData()
  property string activeFanProfile: "Quiet"
  property string activeRgbMode: "wave"
  property int brightness: 100
  property string statusMessage: ""

  readonly property string barText: {
    if (!root.connected) return "󰌢 !"
    if (root.displayMetric === "psu_power") return "󱐋 " + root.psuWatts + "W"
    if (root.displayMetric === "cpu_temp") return "󰍛 " + Math.round(root.cpuTemp) + "°"
    if (root.displayMetric === "gpu_temp") return "󰢮 " + Math.round(root.gpuTemp) + "°"
    if (root.displayMetric === "ram_temp") return "󰘚 " + root.ramTemp.toFixed(1) + "°"
    if (root.displayMetric === "pump_rpm") return "󰈐 " + root.pumpRpm
    if (root.displayMetric === "fan_rpm") return "󰠝 " + root.fanRpm
    if (root.displayMetric === "psu_vrm_temp") return "󰏈 " + root.psuVrmTemp.toFixed(1) + "°"
    return "󰌢 " + root.liquidTemp.toFixed(1) + "°"
  }

  readonly property string tooltipText: Model.formatTooltip(root.rawData, root.displayMetric)

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  function setDefaultMetric(metricId) {
    root.displayMetric = metricId
    root.statusMessage = "󰄬 Domyślna statystyka: " + Model.getMetricInfo(metricId).labelPl
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      var entry = {}
      var cur = root.bar.shell.entryFor(root.moduleName) || {}
      for (var k in cur) if (k !== "id") entry[k] = cur[k]
      entry.displayMetric = metricId
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function cycleMetric() {
    var next = Model.cycleNextMetric(root.displayMetric)
    setDefaultMetric(next)
  }

  function openWebUi() {
    Quickshell.execDetached(["xdg-open", root.apiUrl])
  }

  // --- Fan Profiles ---
  Process {
    id: setFanProc
    property string profileName: ""
    onExited: function(code) {
      if (code === 0) {
        root.statusMessage = "Zastosowano profil wentylatorów: " + profileName
        root.refresh()
      }
    }
  }

  function applyFanProfile(profileName) {
    if (setFanProc.running) return
    setFanProc.profileName = profileName
    root.activeFanProfile = profileName
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

  // --- RGB Modes ---
  Process {
    id: setRgbProc
    property string rgbModeName: ""
    onExited: function(code) {
      if (code === 0) {
        root.statusMessage = "Zastosowano tryb RGB: " + rgbModeName
        root.refresh()
      }
    }
  }

  function applyRgbMode(rgbMode) {
    if (setRgbProc.running) return
    setRgbProc.rgbModeName = rgbMode
    root.activeRgbMode = rgbMode

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

  // --- Brightness ---
  Process {
    id: setBrightnessProc
    onExited: function(code) { root.refresh() }
  }

  function applyBrightness(level) {
    var b = Math.max(0, Math.min(100, Math.round(level)))
    root.brightness = b
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

  // Polling via curl
  Process {
    id: fetchProc
    command: ["curl", "-fsSL", "--max-time", "2", root.apiUrl + "/api/devices/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw || raw.indexOf("{") !== 0) {
          root.connected = false
          return
        }
        var parsed = Model.parseOpenLinkHubData(raw)
        root.rawData = parsed
        root.connected = parsed.connected
        root.liquidTemp = parsed.liquidTemp !== null ? parsed.liquidTemp : 0
        root.liquidName = parsed.liquidName || "iCUE LINK H150i"
        root.pumpRpm = parsed.pumpRpm !== null ? parsed.pumpRpm : 0
        root.psuWatts = parsed.psuWatts !== null ? parsed.psuWatts : 0
        root.psuName = parsed.psuName || "RM850i"
        root.psuTemp = parsed.psuTemp !== null ? parsed.psuTemp : 0
        root.psuVrmTemp = parsed.psuVrmTemp !== null ? parsed.psuVrmTemp : 0
        root.psuRails = parsed.psuRails || ({})
        root.cpuTemp = parsed.cpuTemp !== null ? parsed.cpuTemp : 0
        root.gpuTemp = parsed.gpuTemp !== null ? parsed.gpuTemp : 0
        root.ramTemp = parsed.ramTemp !== null ? parsed.ramTemp : 0
        root.fanRpm = parsed.maxFanRpm !== null ? parsed.maxFanRpm : 0
        root.fans = parsed.fans || []
        root.activeFanProfile = parsed.activeFanProfile || "Quiet"
        root.activeRgbMode = parsed.activeRgbMode || "wave"
        root.brightness = parsed.brightness !== undefined ? parsed.brightness : 100
      }
    }
  }

  // --- Button on Bar ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    slotSize: Style.bar.iconSlot * 2.2
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
    contentWidth: panel.fittedContentWidth(Style.space(450))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        if (t === "1") root.applyFanProfile("Quiet")
        if (t === "2") root.applyFanProfile("Balanced")
        if (t === "3") root.applyFanProfile("Performance")
        if (t === "4") root.applyFanProfile("Extreme")
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight + Style.space(20)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: panelColumn
          width: parent.width
          spacing: Style.space(12)

          // ---------- Hero ----------
          PanelHero {
            width: parent.width
            title: root.connected ? root.barText : "OpenLinkHub Offline"
            meta: root.connected
              ? ("Domyślna statystyka: " + Model.getMetricInfo(root.displayMetric).labelPl + " · " + root.liquidName)
              : "Brak połączenia z " + root.apiUrl
            foreground: Color.accent
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            iconComponent: Component {
              Text {
                text: Model.getMetricInfo(root.displayMetric).icon
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.display
              }
            }
          }

          // ---------- Quick Actions ----------
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: "󰖟 Otwórz Web UI"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.openWebUi()
            }

            Button {
              Layout.fillWidth: true
              text: "󰑐 Odśwież (R)"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.refresh()
            }
          }

          // ---------- Toast Feedback ----------
          Rectangle {
            visible: root.statusMessage !== ""
            width: parent.width
            height: statusTxt.implicitHeight + Style.space(10)
            radius: Style.cornerRadius
            color: Style.hoverFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            Text {
              id: statusTxt
              anchors.centerIn: parent
              text: root.statusMessage
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          // ---------- Section 1: Wszystkie Statystyki (Podwójne Kliknięcie) ----------
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(sec1Hdr.implicitHeight, sec1Hint.implicitHeight)

              PanelSectionHeader {
                id: sec1Hdr
                text: "WSZYSTKIE STATYSTYKI SPRZĘTU"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: sec1Hint
                text: "KLIKNIJ = NA PASEK"
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Grid {
              width: parent.width
              columns: 2
              spacing: Style.space(8)

              readonly property real cellWidth: (width - spacing) / 2

              Repeater {
                model: Model.getMetricDisplayList(root.rawData)

                BorderSurface {
                  id: tile
                  required property var modelData
                  width: parent.cellWidth
                  height: Style.space(56)
                  radius: Style.cornerRadius
                  color: (root.displayMetric === modelData.id)
                    ? Style.selectedFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                    : Style.controlFill(false, tileMouse.containsMouse, root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                  borderSpec: (root.displayMetric === modelData.id)
                    ? Border.controlSpec("focus", root.bar ? root.bar.foreground : Color.foreground, Color.accent)
                    : Border.controlSpec(tileMouse.containsMouse ? "hover-cursor" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

                  Item {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)

                    Row {
                      anchors.left: parent.left
                      anchors.top: parent.top
                      spacing: Style.space(6)

                      Text {
                        text: tile.modelData.icon
                        color: (root.displayMetric === tile.modelData.id) ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                      }

                      Text {
                        text: tile.modelData.labelPl
                        color: (root.displayMetric === tile.modelData.id) ? Color.accent : Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Text {
                      anchors.right: parent.right
                      anchors.top: parent.top
                      visible: root.displayMetric === tile.modelData.id
                      text: "󰄬 PASEK"
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Text {
                      anchors.left: parent.left
                      anchors.bottom: parent.bottom
                      text: tile.modelData.formatted
                      color: (root.displayMetric === tile.modelData.id) ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setDefaultMetric(tile.modelData.id)
                    onDoubleClicked: root.setDefaultMetric(tile.modelData.id)
                  }
                }
              }
            }
          }

          // ---------- Section 2: Profile Wentylatorów ----------
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(fanHeader.implicitHeight, activeFanText.implicitHeight)

              PanelSectionHeader {
                id: fanHeader
                text: "PROFILE WENTYLATORÓW (FANS)"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: activeFanText
                text: "AKTYWNY: " + root.activeFanProfile.toUpperCase()
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
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
                  text: modelData.icon + "  " + modelData.name + " (" + (index + 1) + ")"
                  fontSize: Style.font.caption
                  bordered: true
                  selected: root.activeFanProfile.toLowerCase() === modelData.id.toLowerCase()
                  active: root.activeFanProfile.toLowerCase() === modelData.id.toLowerCase()
                  onClicked: root.applyFanProfile(modelData.id)
                }
              }
            }
          }

          // ---------- Section 3: Tryby Oświetlenia (RGB) ----------
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(rgbHeader.implicitHeight, activeRgbText.implicitHeight)

              PanelSectionHeader {
                id: rgbHeader
                text: "TRYBY OŚWIETLENIA (RGB)"
                foreground: root.bar ? root.bar.foreground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: activeRgbText
                text: "TRYB: " + root.activeRgbMode.toUpperCase()
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
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
                  text: modelData.icon + "  " + modelData.name
                  fontSize: Style.font.caption
                  bordered: true
                  selected: root.activeRgbMode.toLowerCase() === modelData.id.toLowerCase()
                  active: root.activeRgbMode.toLowerCase() === modelData.id.toLowerCase()
                  onClicked: root.applyRgbMode(modelData.id)
                }
              }
            }

            // Jasność RGB
            Item {
              width: parent.width
              implicitHeight: Math.max(brightLabel.implicitHeight, brightVal.implicitHeight)
              anchors.topMargin: Style.space(4)

              Text {
                id: brightLabel
                text: "JASNOŚĆ RGB"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: brightVal
                text: root.brightness + "%"
                color: root.bar ? root.bar.foreground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
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
              value: root.brightness
              onReleased: function(v) { root.applyBrightness(v) }
            }
          }

          // ---------- Section 4: Szczegóły Sprzętu ----------
          PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SZCZEGÓŁOWY STAN SPRZĘTU"
              foreground: root.bar ? root.bar.foreground : Color.foreground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            // AIO
            DetailCard {
              title: "CHŁODZENIE CIECZĄ (AIO)"
              icon: "󰌢"
              onDoubleClicked: root.setDefaultMetric("liquid_temp")
              rows: [
                { label: "Temperatura cieczy", value: root.liquidTemp > 0 ? (root.liquidTemp.toFixed(1) + " °C") : "--" },
                { label: "Obroty pompy", value: root.pumpRpm > 0 ? (root.pumpRpm + " RPM") : "--" },
                { label: "Urządzenie", value: root.liquidName }
              ]
            }

            // PSU
            DetailCard {
              title: "ZASILACZ (PSU · " + root.psuName + ")"
              icon: "󱐋"
              onDoubleClicked: root.setDefaultMetric("psu_power")
              rows: [
                { label: "Łączna moc (Power Out)", value: root.psuWatts > 0 ? (root.psuWatts + " W") : "--" },
                { label: "Linia 12V", value: root.psuRails["12V Rail"] ? (root.psuRails["12V Rail"].watts + "W (" + root.psuRails["12V Rail"].volts + "V / " + root.psuRails["12V Rail"].amps + "A)") : "--" },
                { label: "Linia 5V / 3.3V", value: ((root.psuRails["5V Rail"] ? root.psuRails["5V Rail"].watts : 0) + "W") + " · " + ((root.psuRails["3V Rail"] ? root.psuRails["3V Rail"].watts : 0) + "W") },
                { label: "Temperatura VRM / PSU", value: (root.psuVrmTemp > 0 ? (root.psuVrmTemp.toFixed(1) + "°C") : "--") + " · " + (root.psuTemp > 0 ? (root.psuTemp.toFixed(1) + "°C") : "--") }
              ]
            }

            // CPU/GPU/RAM
            DetailCard {
              title: "TEMPERATURY PODZESPOŁÓW"
              icon: "󰍛"
              onDoubleClicked: root.setDefaultMetric("cpu_temp")
              rows: [
                { label: "Procesor (CPU)", value: root.cpuTemp > 0 ? (root.cpuTemp.toFixed(1) + " °C") : "--" },
                { label: "Karta graficzna (GPU)", value: root.gpuTemp > 0 ? (root.gpuTemp.toFixed(1) + " °C") : "--" },
                { label: "Pamięć RAM (Dominator)", value: root.ramTemp > 0 ? (root.ramTemp.toFixed(1) + " °C") : "--" }
              ]
            }

            // Fans
            DetailCard {
              title: "WENTYLATORY (" + root.fans.length + " SZT.)"
              icon: "󰠝"
              onDoubleClicked: root.setDefaultMetric("fan_rpm")
              rows: root.getFanRows()
            }
          }

          Item {
            width: parent.width
            height: Style.space(6)
          }
        }
      }
    }
  }

  function getFanRows() {
    var list = []
    if (Array.isArray(root.fans)) {
      for (var i = 0; i < root.fans.length; i++) {
        var f = root.fans[i]
        list.push({
          label: f.name + " (" + f.devName + ")",
          value: f.rpm + " RPM" + (f.profile ? (" · " + f.profile) : "")
        })
      }
    }
    if (list.length === 0) list.push({ label: "Wentylatory", value: "--" })
    return list
  }

  // --- Subcomponent: DetailCard ---
  component DetailCard: BorderSurface {
    id: dCard
    property string title: ""
    property string icon: ""
    property var rows: []
    signal doubleClicked()

    width: parent.width
    radius: Style.cornerRadius
    color: Style.controlFill(false, dCardMouse.containsMouse, root.bar ? root.bar.foreground : Color.foreground, Color.accent)
    implicitHeight: dCardCol.implicitHeight + Style.space(16)

    Column {
      id: dCardCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      spacing: Style.space(6)

      Row {
        spacing: Style.space(6)
        Text {
          text: dCard.icon
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          text: dCard.title
          color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.8
        }
      }

      Repeater {
        model: dCard.rows

        Item {
          required property var modelData
          width: dCardCol.width
          implicitHeight: Math.max(lbl.implicitHeight, val.implicitHeight)

          Text {
            id: lbl
            text: modelData.label
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: val
            text: modelData.value
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }

    MouseArea {
      id: dCardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onDoubleClicked: dCard.doubleClicked()
    }
  }
}
