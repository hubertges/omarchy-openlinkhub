import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "OpenLinkHubModel.js" as Model

BarWidget {
  id: root
  moduleName: "hubi.openlinkhub"

  property string apiUrl: root.setting("apiUrl", "http://localhost:27003")
  property string displayMetric: root.setting("displayMetric", "liquid_temp")
  property int pollInterval: root.setting("pollInterval", 2000)

  property var data: Model.emptyData()
  property var badge: Model.formatBarBadge(root.data, root.displayMetric)
  property string statusMessage: ""
  property bool isBusy: false

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property string indicatorText: (root.data && root.data.connected)
    ? (root.badge.icon + "  " + root.badge.text)
    : "󰌢  Offline"

  readonly property string indicatorTooltip: Model.formatTooltip(root.data, root.displayMetric)

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch)
      panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("data" in target) target.data = root.data
    if ("displayMetric" in target) target.displayMetric = root.displayMetric
    if ("apiUrl" in target) target.apiUrl = root.apiUrl
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: {
    var savedMetric = root.setting("displayMetric", "")
    if (savedMetric && savedMetric !== root.displayMetric) {
      root.displayMetric = savedMetric
      root.badge = Model.formatBarBadge(root.data, savedMetric)
    }
    injectPanel()
  }

  Component.onCompleted: {
    root.refresh()
  }

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  // --- Fetch Hardware Data (-L follows redirects, /api/devices/) ---
  Process {
    id: fetchProc
    command: ["curl", "-fsSL", "--max-time", "2", root.apiUrl + "/api/devices/"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw || raw.indexOf("{") !== 0) {
          root.data = Model.emptyData()
          root.badge = Model.formatBarBadge(root.data, root.displayMetric)
          root.injectPanel()
          return
        }
        var parsed = Model.parseOpenLinkHubData(raw)
        root.data = parsed
        root.badge = Model.formatBarBadge(parsed, root.displayMetric)
        root.injectPanel()
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
        root.statusMessage = "Zastosowano profil wentylatorów: " + profileName
        root.refresh()
      } else {
        root.statusMessage = "Błąd zmiany profilu wentylatorów"
      }
      if (panelLoader.item) panelLoader.item.statusMessage = root.statusMessage
    }
  }

  function applyFanProfile(profileName) {
    if (setFanProc.running) return
    root.isBusy = true
    setFanProc.profileName = profileName
    if (root.data) root.data.activeFanProfile = profileName

    var devices = (root.data && root.data.fanControllableDevices && root.data.fanControllableDevices.length > 0)
      ? root.data.fanControllableDevices
      : ["62605BBB76606751B331EACF1C495170", "1005010593341009"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], channelId: -1, profile: profileName })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/speed >/dev/null 2>&1; "
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
      if (panelLoader.item) panelLoader.item.statusMessage = root.statusMessage
    }
  }

  function applyRgbMode(rgbMode) {
    if (setRgbProc.running) return
    root.isBusy = true
    setRgbProc.rgbModeName = rgbMode
    if (root.data) root.data.activeRgbMode = rgbMode

    var clusterPayload = JSON.stringify({ deviceId: "cluster", channelId: 0, profile: rgbMode })
    var script = "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + clusterPayload + "' " + root.apiUrl + "/api/color >/dev/null 2>&1; "

    var devices = (root.data && root.data.rgbControllableDevices && root.data.rgbControllableDevices.length > 0)
      ? root.data.rgbControllableDevices
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
    onExited: function(code) {
      root.refresh()
    }
  }

  function applyBrightness(level) {
    var b = Math.max(0, Math.min(100, Math.round(level)))
    if (root.data) root.data.brightness = b
    var devices = ["cluster", "62605BBB76606751B331EACF1C495170", "i2c11"]
    var script = ""
    for (var i = 0; i < devices.length; i++) {
      var payload = JSON.stringify({ deviceId: devices[i], brightness: b })
      script += "curl -s -L -X POST -H 'Content-Type: application/json' -d '" + payload + "' " + root.apiUrl + "/api/brightness/gradual >/dev/null 2>&1; "
    }
    setBrightnessProc.command = ["bash", "-c", script]
    setBrightnessProc.running = true
  }

  // --- Settings Persistence & Default Metric ---
  function setDefaultMetric(metricId) {
    root.displayMetric = metricId
    root.badge = Model.formatBarBadge(root.data, metricId)
    root.statusMessage = "󰄬 Ustawiono jako domyślną statystykę paska: " + root.badge.label + " (" + root.badge.text + ")"
    if (panelLoader.item) {
      panelLoader.item.displayMetric = metricId
      panelLoader.item.statusMessage = root.statusMessage
    }
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

  // --- Loader for Popout Panel ---
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // --- IPC Handler for CLI / Hotkeys ---
  IpcHandler {
    target: root.moduleName

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function next(): void { root.cycleMetric() }
    function refresh(): void { root.refresh() }
    function setMetric(id: string): void { root.setDefaultMetric(id) }
    function setFan(profile: string): void { root.applyFanProfile(profile) }
    function setRgb(mode: string): void { root.applyRgbMode(mode) }
    function setBrightness(val: string): void { root.applyBrightness(parseInt(val, 10)) }
  }

  // --- Bar Button (WidgetButton matching Keyboard Layout Switcher & NVIDIA) ---
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.indicatorText
    fontSize: Style.font.caption
    horizontalMargin: 7
    active: root.opened
    tooltipText: root.indicatorTooltip

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.cycleMetric()
      } else if (buttonCode === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }

    onWheelMoved: function(delta) {
      root.cycleMetric()
    }
  }
}
