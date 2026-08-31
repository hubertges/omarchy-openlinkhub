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

  property var data: Model.emptyData()
  property var badge: Model.formatBarBadge(root.data, root.displayMetric)
  property string statusMessage: ""
  property bool isBusy: false

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: root.refresh()

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Fetch Hardware Data ---
  Process {
    id: fetchProc
    command: ["curl", "-fsS", "--max-time", "2", root.apiUrl + "/api/devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) {
          root.data = Model.emptyData()
          root.badge = Model.formatBarBadge(root.data, root.displayMetric)
          return
        }
        var parsed = Model.parseOpenLinkHubData(raw)
        root.data = parsed
        root.badge = Model.formatBarBadge(parsed, root.displayMetric)
      }
    }
  }

  function refresh() {
    if (!fetchProc.running) fetchProc.running = true
  }

  // --- Apply Fan Profile ---
  Process {
    id: setFanProc
    property string profileName: ""
    onExited: function(code) {
      root.isBusy = false
      if (code === 0) {
        root.statusMessage = "Zastosowano profil: " + profileName
        root.refresh()
      } else {
        root.statusMessage = "Błąd zmiany profilu wentylatorów"
      }
    }
  }

  function applyFanProfile(profileName) {
    if (setFanProc.running) return
    root.isBusy = true
    setFanProc.profileName = profileName
    root.data.activeFanProfile = profileName

    var devices = root.data.fanControllableDevices.length > 0
      ? root.data.fanControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "1005010593341009"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], channelId: -1, profile: profileName })
      script += "curl -s -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/speed >/dev/null 2>&1; "
    }
    setFanProc.command = ["bash", "-c", script]
    setFanProc.running = true
  }

  // --- Apply RGB Lighting Mode ---
  Process {
    id: setRgbProc
    property string rgbModeName: ""
    onExited: function(code) {
      root.isBusy = false
      if (code === 0) {
        root.statusMessage = "Zastosowano tryb RGB: " + rgbModeName
        root.refresh()
      } else {
        root.statusMessage = "Błąd zmiany trybu RGB"
      }
    }
  }

  function applyRgbMode(rgbMode) {
    if (setRgbProc.running) return
    root.isBusy = true
    setRgbProc.rgbModeName = rgbMode
    root.data.activeRgbMode = rgbMode

    var clusterPayload = JSON.stringify({ deviceId: "cluster", channelId: 0, profile: rgbMode })
    var script = "curl -s -X POST -H 'Content-Type: application/json' -d '" + clusterPayload + "' " + root.apiUrl + "/api/color >/dev/null 2>&1; "

    var devices = root.data.rgbControllableDevices.length > 0
      ? root.data.rgbControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "i2c11"]
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], channelId: -1, profile: rgbMode })
      script += "curl -s -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/color >/dev/null 2>&1; "
    }
    setRgbProc.command = ["bash", "-c", script]
    setRgbProc.running = true
  }

  // --- Apply Brightness ---
  Process {
    id: setBrightnessProc
    onExited: function(code) {
      root.refresh()
    }
  }

  function applyBrightness(level) {
    var b = Math.max(0, Math.min(100, Math.round(level)))
    root.data.brightness = b
    var devices = ["cluster", "62605BBB76606751B331EACF1C495170", "i2c11"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], brightness: b })
      script += "curl -s -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/brightness/gradual >/dev/null 2>&1; "
    }
    setBrightnessProc.command = ["bash", "-c", script]
    setBrightnessProc.running = true
  }

  // --- Settings Persistence ---
  function setDisplayMetric(metricId) {
    root.displayMetric = metricId
    root.badge = Model.formatBarBadge(root.data, metricId)
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
    setDisplayMetric(next)
  }

  function openWebUi() {
    Quickshell.execDetached(["xdg-open", root.apiUrl])
  }

  // --- Bar Button ---
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.data.connected ? (root.badge.icon + " " + root.badge.text) : "󰌢 !"
    slotSize: Style.bar.iconSlot * 2.4
    active: root.badge.isUrgent
    useActiveColor: true
    activeColor: Color.urgent
    tooltipText: Model.formatTooltip(root.data, root.displayMetric)
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.cycleMetric()
      } else if (b === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.toggle()
      }
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
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(scrollColumn.implicitHeight, Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        if (text === "1") root.applyFanProfile("Quiet")
        if (text === "2") root.applyFanProfile("Balanced")
        if (text === "3") root.applyFanProfile("Performance")
        if (text === "4") root.applyFanProfile("Extreme")
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: scrollColumn.implicitHeight + Style.space(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: scrollColumn
          width: parent.width
          spacing: Style.space(12)

          // ---------- Hero: Primary Sensor & Connection ----------
          PanelHero {
            width: parent.width
            title: root.data.connected ? root.badge.fullText : "OpenLinkHub Offline"
            meta: root.data.connected
              ? ("Połączono · " + (root.data.liquidName || "iCUE LINK H150i") + " · " + (root.data.psuName || "RM850i"))
              : "Brak połączenia z " + root.apiUrl
            foreground: root.badge.isUrgent ? Color.urgent : (root.badge.isWarning ? Color.warning : Color.accent)
            fontFamily: root.ff
            iconComponent: Component {
              Text {
                text: root.badge.icon
                color: root.badge.isUrgent ? Color.urgent : (root.badge.isWarning ? Color.warning : Color.accent)
                font.family: root.ff
                font.pixelSize: Style.font.display
              }
            }
          }

          // ---------- Quick Action Buttons ----------
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              text: "󰖟 Otwórz Web UI"
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.openWebUi()
            }

            Button {
              Layout.fillWidth: true
              text: "󰑐 Odśwież (R)"
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.refresh()
            }
          }

          // ---------- Status Message / Feedback ----------
          Text {
            visible: root.statusMessage !== ""
            text: root.statusMessage
            color: Color.accent
            font.family: root.ff
            font.pixelSize: Style.font.caption
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
          }

          // ---------- Section 1: Wyświetlany Status (Bar Metric) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "STATUS NA PASKU (BAR METRIC)"
              foreground: root.fg
              fontFamily: root.ff
            }

            Grid {
              width: parent.width
              columns: 2
              spacing: Style.space(6)

              readonly property real cellWidth: (width - spacing) / 2

              Repeater {
                model: Model.METRICS

                Button {
                  required property var modelData
                  width: parent.cellWidth
                  text: modelData.icon + "  " + modelData.labelPl
                  fontFamily: root.ff
                  fontSize: Style.font.caption
                  bordered: true
                  selected: root.displayMetric === modelData.id
                  active: root.displayMetric === modelData.id
                  onClicked: root.setDisplayMetric(modelData.id)
                }
              }
            }
          }

          // ---------- Section 2: Profile Wentylatorów (Fan Profiles) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(fanHeader.implicitHeight, activeFanText.implicitHeight)

              PanelSectionHeader {
                id: fanHeader
                text: "PROFILE WENTYLATORÓW (FANS)"
                foreground: root.fg
                fontFamily: root.ff
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: activeFanText
                text: "AKTYWNY: " + (root.data.activeFanProfile || "Quiet").toUpperCase()
                color: Color.accent
                font.family: root.ff
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
                  fontFamily: root.ff
                  fontSize: Style.font.caption
                  bordered: true
                  selected: (root.data.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase()
                  active: (root.data.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase()
                  onClicked: root.applyFanProfile(modelData.id)
                }
              }
            }
          }

          // ---------- Section 3: Tryby Oświetlenia (RGB Lighting Modes) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(rgbHeader.implicitHeight, activeRgbText.implicitHeight)

              PanelSectionHeader {
                id: rgbHeader
                text: "TRYBY OŚWIETLENIA (RGB)"
                foreground: root.fg
                fontFamily: root.ff
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: activeRgbText
                text: "TRYB: " + (root.data.activeRgbMode || "wave").toUpperCase()
                color: Color.accent
                font.family: root.ff
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
                  fontFamily: root.ff
                  fontSize: Style.font.caption
                  bordered: true
                  selected: (root.data.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase()
                  active: (root.data.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase()
                  onClicked: root.applyRgbMode(modelData.id)
                }
              }
            }

            // ---------- Jasność RGB (Brightness) ----------
            Item {
              width: parent.width
              implicitHeight: Math.max(brightLabel.implicitHeight, brightVal.implicitHeight)
              anchors.topMargin: Style.space(4)

              Text {
                id: brightLabel
                text: "JASNOŚĆ RGB"
                color: Qt.darker(root.fg, 1.4)
                font.family: root.ff
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: brightVal
                text: root.data.brightness + "%"
                color: root.fg
                font.family: root.ff
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
              value: root.data && root.data.brightness !== undefined ? root.data.brightness : 100
              onReleased: function(v) { root.applyBrightness(v) }
            }
          }

          // ---------- Section 4: Szczegóły Sprzętu (Hardware Status) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "STATUS SPRZĘTU (HARDWARE)"
              foreground: root.fg
              fontFamily: root.ff
            }

            // Chłodzenie Cieczą (AIO Liquid)
            InfoCard {
              width: parent.width
              title: "CHŁODZENIE CIECZĄ (AIO)"
              icon: "󰌢"
              rows: [
                { label: "Temperatura cieczy", value: root.data && root.data.liquidTemp !== null && root.data.liquidTemp !== undefined ? (root.data.liquidTemp + " °C") : "--" },
                { label: "Obroty pompy", value: root.data && root.data.pumpRpm !== null && root.data.pumpRpm !== undefined ? (root.data.pumpRpm + " RPM") : "--" },
                { label: "Urządzenie", value: (root.data && root.data.liquidName) || "iCUE LINK H150i" }
              ]
            }

            // Zasilacz (RM850i PSU)
            InfoCard {
              width: parent.width
              title: "ZASILACZ (PSU · " + ((root.data && root.data.psuName) || "RM850i") + ")"
              icon: "󱐋"
              rows: [
                { label: "Łączna moc (Power Out)", value: root.data && root.data.psuWatts !== null && root.data.psuWatts !== undefined ? (root.data.psuWatts + " W") : "--" },
                { label: "Linia 12V", value: root.data && root.data.psuRails && root.data.psuRails["12V Rail"] ? (root.data.psuRails["12V Rail"].watts + "W (" + root.data.psuRails["12V Rail"].volts + "V / " + root.data.psuRails["12V Rail"].amps + "A)") : "--" },
                { label: "Linia 5V / 3.3V", value: ((root.data && root.data.psuRails && root.data.psuRails["5V Rail"]) ? (root.data.psuRails["5V Rail"].watts + "W") : "--") + " · " + ((root.data && root.data.psuRails && root.data.psuRails["3V Rail"]) ? (root.data.psuRails["3V Rail"].watts + "W") : "--") },
                { label: "Temperatura VRM / PSU", value: ((root.data && root.data.psuVrmTemp) ? (root.data.psuVrmTemp + "°C") : "--") + " · " + ((root.data && root.data.psuTemp) ? (root.data.psuTemp + "°C") : "--") }
              ]
            }

            // Temperatury CPU / GPU / RAM
            InfoCard {
              width: parent.width
              title: "TEMPERATURY PODZESPOŁÓW"
              icon: "󰍛"
              rows: [
                { label: "Procesor (CPU)", value: root.data && root.data.cpuTemp !== null && root.data.cpuTemp !== undefined ? (root.data.cpuTemp + " °C") : "--" },
                { label: "Karta graficzna (GPU)", value: root.data && root.data.gpuTemp !== null && root.data.gpuTemp !== undefined ? (root.data.gpuTemp + " °C") : "--" },
                { label: "Pamięć RAM (Dominator)", value: root.data && root.data.ramTemp !== null && root.data.ramTemp !== undefined ? (root.data.ramTemp + " °C") : "--" }
              ]
            }

            // Wentylatory
            InfoCard {
              width: parent.width
              title: "WENTYLATORY (" + (root.data && root.data.fans ? root.data.fans.length : 0) + " SZT.)"
              icon: "󰠝"
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
    if (root.data && Array.isArray(root.data.fans)) {
      for (var i = 0; i < root.data.fans.length; i++) {
        var f = root.data.fans[i]
        list.push({
          label: f.name + " (" + f.devName + ")",
          value: f.rpm + " RPM" + (f.profile ? (" · " + f.profile) : "")
        })
      }
    }
    if (list.length === 0) list.push({ label: "Wentylatory", value: "--" })
    return list
  }

  // --- Subcomponent: InfoCard ---
  component InfoCard: BorderSurface {
    id: card
    property string title: ""
    property string icon: ""
    property var rows: []

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

      Row {
        spacing: Style.space(6)
        Text {
          text: card.icon
          color: Color.accent
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.bold: true
        }
        Text {
          text: card.title
          color: Qt.darker(root.fg, 1.3)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.8
        }
      }

      Repeater {
        model: card.rows

        Item {
          required property var modelData
          width: cardCol.width
          implicitHeight: Math.max(lbl.implicitHeight, val.implicitHeight)

          Text {
            id: lbl
            text: modelData.label
            color: Qt.darker(root.fg, 1.4)
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: val
            text: modelData.value
            color: root.fg
            font.family: root.ff
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
