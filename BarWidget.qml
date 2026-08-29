import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Date/time label for the bar, and the host for the calendar popup.
//
// Left click reveals the calendar — asking "what is the date?" is what a
// click on a clock means — right click walks the common label formats, and
// middle click opens the timezone picker.
BarWidget {
  id: root
  moduleName: "omarchy-google-calendar-clock"

  property date displayDate: clock.date

  readonly property string displayText: formatted(displayDate)
  readonly property var verticalLines: displayText.split("\n")

  // The locale every date/time string in this widget renders with: the
  // `locale` setting, or the system locale when it is unset. Qt.locale(name)
  // silently becomes the C locale for a bogus name, so the normalized name
  // is checked and anything that does not resolve falls back to the system
  // locale — an override typo must not silently render English.
  function resolvedLocale() {
    var name = String(setting("locale", "system"))
    if (name === "" || name === "system") return Qt.locale()
    var loc = Qt.locale(name)
    return loc.name === "C" || loc.name === "" ? Qt.locale() : loc
  }

  // Active slot index, 1..3, shared between horizontal and vertical.
  function activeSlot() {
    var slot = parseInt(setting("activeFormatSlot", "1"), 10)
    return isFinite(slot) && slot >= 1 && slot <= 3 ? slot : 1
  }

  // Effective Qt-token format for the active slot: configured → legacy key
  // → slot default, then strftime translation. An invalid custom format
  // falls back to the slot's own default; the stored value is never touched.
  function currentFormat() {
    var slot = activeSlot()
    var stored = Model.slotFormat(slot, root.settings, root.vertical)
    if (!Model.isStrftimeFormat(stored)) return stored
    var translated = Model.strftimeToQtFormat(stored)
    return translated !== null ? translated : Model.slotFormat(slot, {}, root.vertical)
  }

  function formatted(date) {
    var slot = activeSlot()
    var stored = Model.slotFormat(slot, root.settings, root.vertical)
    var fmt = currentFormat()
    // Qt-token formats may carry the 'ww' ISO-week token, which Qt has no
    // specifier for; strftime formats spell the same value as %V instead.
    if (!Model.isStrftimeFormat(stored))
      fmt = fmt.replace(/ww/g, Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate()))
    return expandMarkers(resolvedLocale().toString(date, fmt), date)
  }

  // Marker codes the strftime translator emits for values Qt has no token
  // for (space-padded fields, week numbers, offsets, epoch) and for the
  // locale compound formats (%x/%X/%c). Substituted after Qt renders the
  // tokens, because they need the date and the resolved locale.
  function expandMarkers(text, date) {
    var loc = resolvedLocale()
    return text.replace(/\u0001([^\u0001]*)\u0001/g, function (match, code) {
      return markerValue(code, date, loc)
    })
  }

  function markerValue(code, date, loc) {
    var y = date.getFullYear()
    var month = date.getMonth()
    var day = date.getDate()
    switch (code) {
      case "pd": return padded(day, " ")
      case "pm": return padded(month + 1, " ")
      case "pH": return padded(date.getHours(), " ")
      case "ph": return padded(hour12(date.getHours()), " ")
      case "I": return padded(hour12(date.getHours()), "0")
      case "i": return String(hour12(date.getHours()))
      case "pM": return padded(date.getMinutes(), " ")
      case "pS": return padded(date.getSeconds(), " ")
      case "C": return padded(Math.floor(y / 100), "0")
      case "j": return pad3(Model.dayOfYear(y, month, day))
      case "U": return padded(weekNumber(date, 0), "0")
      case "W": return padded(weekNumber(date, 1), "0")
      case "V": return Model.isoWeekLiteral(y, month, day)
      case "u": return String(date.getDay() === 0 ? 7 : date.getDay())
      case "w": return String(date.getDay())
      case "z": return offsetString(date, false)
      case "zc": return offsetString(date, true)
      case "s": return String(Math.floor(date.getTime() / 1000))
      // Locale short forms: QML's Locale.FormatType has no ShortDate/ShortTime
      // members, so the format string comes from dateFormat/timeFormat instead.
      case "x": return loc.toString(date, loc.dateFormat(Locale.ShortFormat))
      case "X": return loc.toString(date, loc.timeFormat(Locale.ShortFormat))
      case "c": return loc.toString(date, loc.dateTimeFormat(Locale.ShortFormat))
    }
    return ""
  }

  // Two-char field with a chosen pad char; Qt has no space-padded tokens.
  function padded(value, padChar) {
    value = String(value)
    return value.length < 2 ? padChar + value : value
  }

  function pad3(value) {
    return ("00" + String(value)).slice(-3)
  }

  function hour12(hours) {
    var h = hours % 12
    return h === 0 ? 12 : h
  }

  // Week of the year with the week starting on Sunday (0) or Monday (1);
  // the first partial week counts, so January 1 can be week 00.
  function weekNumber(date, firstDay) {
    var yday = Model.dayOfYear(date.getFullYear(), date.getMonth(), date.getDate()) - 1
    var offset = firstDay === 0 ? date.getDay() : (date.getDay() + 6) % 7
    return Math.floor((yday + 7 - offset) / 7)
  }

  // UTC offset as +0800 or +08:00, computed from the local timezone.
  function offsetString(date, colon) {
    var minutes = -date.getTimezoneOffset()
    var sign = minutes < 0 ? "-" : "+"
    var abs = Math.abs(minutes)
    return (colon ? sign + padded(Math.floor(abs / 60), "0") + ":" + padded(abs % 60, "0")
                 : sign + padded(Math.floor(abs / 60), "0") + padded(abs % 60, "0"))
  }

  function refresh() {
    displayDate = new Date()
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function cycleFormat() {
    var next = Model.nextSlot(activeSlot(), 3)

    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    entry.activeFormatSlot = next

    // Applied locally first so the label changes on the click itself; the
    // shell.json write comes back through the bar as the same value.
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // ---- Calendar popup. Shape contract for shell.summon/hide/toggle
  //      routing: Bar.findPanelWidget requires open/close/opened on the
  //      bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function toggleWeekStart() {
    if (panelLoader.item) panelLoader.item.toggleWeekStart()
  }

  // The clock fills more slot than it paints a mark for, at both
  // orientations: horizontally it is a text label in a padded slot, so the
  // dot takes the label width; vertically it is a stack of icon-sized lines,
  // so the dot takes one line — the same mark every icon widget gets, rather
  // than a rule running the height of the whole stack.
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Injects this widget's state into the popup, so the panel never holds a
  // stale copy of the bar or its settings. `locale` is the resolved locale
  // object; the panel consumes it when it declares the property.
  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("locale" in target) target.locale = resolvedLocale()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

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

  IpcHandler {
    target: "omarchy-google-calendar-clock"

    function refresh(): void { root.broadcast("refresh") }
    function cycleFormat(): void { root.cycleFormat() }
    function toggleWeekStart(): void { root.toggleWeekStart() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refreshCalendar(): void {
      if (panelLoader.item) panelLoader.item.refreshCalendar()
    }
    function calendarStatus(): string {
      return panelLoader.item ? panelLoader.item.calendarStatus() : "{\"error\":\"Calendar panel is unavailable\"}"
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.cycleFormat()
      else if (b === Qt.MiddleButton) { if (root.bar) root.bar.run("omarchy-menu-timezone") }
      else root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: modelData.length > 3
            ? button.fontSize * 0.9
            : button.fontSize
          color: button.foreground
        }
      }
    }
  }
}
