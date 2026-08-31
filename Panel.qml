import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Ui
import qs.Commons
import "OpenLinkHubModel.js" as Model

Panel {
  id: root
  moduleName: "hubi.openlinkhub"
  manageIpc: false

  property var hostWidget: null
  property var anchorItem: null
  property var data: hostWidget ? hostWidget.data : Model.emptyData()
  property string displayMetric: hostWidget ? hostWidget.displayMetric : "liquid_temp"
  property string apiUrl: hostWidget ? hostWidget.apiUrl : "http://localhost:27003"
  property string statusMessage: ""

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var badge: Model.formatBarBadge(root.data, root.displayMetric)

  function openFromHotkey() { open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(450))
    contentHeight: panel.fittedContentHeight(scrollColumn.implicitHeight, Style.space(660))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") { if (root.hostWidget) root.hostWidget.refresh() }
        if (text === "1") { if (root.hostWidget) root.hostWidget.applyFanProfile("Quiet") }
        if (text === "2") { if (root.hostWidget) root.hostWidget.applyFanProfile("Balanced") }
        if (text === "3") { if (root.hostWidget) root.hostWidget.applyFanProfile("Performance") }
        if (text === "4") { if (root.hostWidget) root.hostWidget.applyFanProfile("Extreme") }
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: scrollColumn.implicitHeight + Style.space(20)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: scrollColumn
          width: parent.width
          spacing: Style.space(12)

          // ---------- Hero: Primary Sensor & Connection ----------
          PanelHero {
            width: parent.width
            title: root.data && root.data.connected ? root.badge.fullText : "OpenLinkHub Offline"
            meta: root.data && root.data.connected
              ? ("Domyślna: " + root.badge.label + " · " + (root.data.liquidName || "iCUE LINK H150i"))
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
              onClicked: if (root.hostWidget) root.hostWidget.openWebUi()
            }

            Button {
              Layout.fillWidth: true
              text: "󰑐 Odśwież (R)"
              fontFamily: root.ff
              fontSize: Style.font.caption
              bordered: true
              onClicked: if (root.hostWidget) root.hostWidget.refresh()
            }
          }

          // ---------- Status Toast Feedback ----------
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

          // ---------- Section 1: Wszystkie Statystyki (Podwójny Klik = Domyślna) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(sec1Hdr.implicitHeight, sec1Hint.implicitHeight)

              PanelSectionHeader {
                id: sec1Hdr
                text: "WSZYSTKIE STATYSTYKI SPRZĘTU"
                foreground: root.fg
                fontFamily: root.ff
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: sec1Hint
                text: "KLIKNIJ = NA PASEK"
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
              spacing: Style.space(8)

              readonly property real cellWidth: (width - spacing) / 2

              Repeater {
                model: Model.getMetricDisplayList(root.data)

                MetricCardTile {
                  required property var modelData
                  width: parent.cellWidth
                  metricItem: modelData
                  isDefault: root.displayMetric === modelData.id
                  onClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric(modelData.id)
                  onDoubleClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric(modelData.id)
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
                text: "AKTYWNY: " + ((root.data && root.data.activeFanProfile) ? root.data.activeFanProfile : "Quiet").toUpperCase()
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
                  selected: (root.data && (root.data.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                  active: (root.data && (root.data.activeFanProfile || "").toLowerCase() === modelData.id.toLowerCase())
                  onClicked: if (root.hostWidget) root.hostWidget.applyFanProfile(modelData.id)
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
                text: "TRYB: " + ((root.data && root.data.activeRgbMode) ? root.data.activeRgbMode : "wave").toUpperCase()
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
                  selected: (root.data && (root.data.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                  active: (root.data && (root.data.activeRgbMode || "").toLowerCase() === modelData.id.toLowerCase())
                  onClicked: if (root.hostWidget) root.hostWidget.applyRgbMode(modelData.id)
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
                text: ((root.data && root.data.brightness !== undefined) ? root.data.brightness : 100) + "%"
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
              onReleased: function(v) { if (root.hostWidget) root.hostWidget.applyBrightness(v) }
            }
          }

          // ---------- Section 4: Szczegóły Sprzętu (Hardware Breakdown) ----------
          PanelSeparator { foreground: root.fg }

          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "SZCZEGÓŁOWY STAN SPRZĘTU"
              foreground: root.fg
              fontFamily: root.ff
            }

            // Chłodzenie Cieczą (AIO Liquid)
            InfoCard {
              width: parent.width
              title: "CHŁODZENIE CIECZĄ (AIO)"
              icon: "󰌢"
              onClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("liquid_temp")
              onDoubleClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("liquid_temp")
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
              onClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("psu_power")
              onDoubleClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("psu_power")
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
              onClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("cpu_temp")
              onDoubleClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("cpu_temp")
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
              onClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("fan_rpm")
              onDoubleClicked: if (root.hostWidget) root.hostWidget.setDefaultMetric("fan_rpm")
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

  // --- Subcomponent: MetricCardTile ---
  component MetricCardTile: BorderSurface {
    id: tile
    property var metricItem: null
    property bool isDefault: false
    signal clicked()
    signal doubleClicked()

    height: Style.space(56)
    radius: Style.cornerRadius
    color: isDefault ? Style.selectedFillFor(root.fg, Color.accent) : Style.controlFill(false, tileMouse.containsMouse, root.fg, Color.accent)
    borderSpec: isDefault ? Border.controlSpec("focus", root.fg, Color.accent) : Border.controlSpec(tileMouse.containsMouse ? "hover-cursor" : "normal", root.fg, Color.accent)

    Item {
      anchors.fill: parent
      anchors.margins: Style.space(8)

      Row {
        anchors.left: parent.left
        anchors.top: parent.top
        spacing: Style.space(6)

        Text {
          text: tile.metricItem ? tile.metricItem.icon : ""
          color: tile.isDefault ? Color.accent : root.fg
          font.family: root.ff
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          text: tile.metricItem ? tile.metricItem.labelPl : ""
          color: tile.isDefault ? Color.accent : Qt.darker(root.fg, 1.3)
          font.family: root.ff
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        visible: tile.isDefault
        text: "󰄬 PASEK"
        color: Color.accent
        font.family: root.ff
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: tile.metricItem ? tile.metricItem.formatted : "--"
        color: tile.isDefault ? Color.accent : root.fg
        font.family: root.ff
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    MouseArea {
      id: tileMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.clicked()
      onDoubleClicked: tile.doubleClicked()
    }
  }

  // --- Subcomponent: InfoCard ---
  component InfoCard: BorderSurface {
    id: card
    property string title: ""
    property string icon: ""
    property var rows: []
    signal clicked()
    signal doubleClicked()

    width: parent.width
    radius: Style.cornerRadius
    color: Style.controlFill(false, cardMouse.containsMouse, root.fg, Color.accent)
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

    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.clicked()
      onDoubleClicked: card.doubleClicked()
    }
  }
}
