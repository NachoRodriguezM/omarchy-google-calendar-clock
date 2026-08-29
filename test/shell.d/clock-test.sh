#!/usr/bin/env node
// Node unit tests for Model.js, per its header convention
// ("unit tested under node (test/shell.d/clock-test.sh)").
// Run: node test/shell.d/clock-test.sh
//
// Covers the pure format math only: strftime detection and translation, the
// three-slot ring, and the read-time migration fallback chain. Expected
// values are literals from the spec's strftime support table, not recomputed
// by the code under test.

var assert = require("assert")
var Model = require("../../Model.js")

var failures = 0
function check(name, fn) {
  try {
    fn()
    console.log("ok - " + name)
  } catch (e) {
    failures++
    console.error("FAIL - " + name + ": " + e.message)
  }
}

// ---- strftime detection ---------------------------------------------------

check("detects strftime only when the format contains %", function () {
  assert.strictEqual(Model.isStrftimeFormat("dddd HH:mm"), false)
  assert.strictEqual(Model.isStrftimeFormat("12:30"), false)
  assert.strictEqual(Model.isStrftimeFormat(""), false)
  assert.strictEqual(Model.isStrftimeFormat("%Y-%m-%d"), true)
  assert.strictEqual(Model.isStrftimeFormat("100%"), true)
  assert.strictEqual(Model.isStrftimeFormat("%%"), true)
  assert.strictEqual(Model.isStrftimeFormat("50%"), true)
})

// ---- strftime translation: every supported specifier ----------------------

check("translates year, century, month, day specifiers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%Y"), "yyyy")
  assert.strictEqual(Model.strftimeToQtFormat("%y"), "yy")
  assert.strictEqual(Model.strftimeToQtFormat("%C"), "'\x01C\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%m"), "MM")
  assert.strictEqual(Model.strftimeToQtFormat("%d"), "dd")
  assert.strictEqual(Model.strftimeToQtFormat("%e"), "'\x01pd\x01'")
})

check("translates hour, minute, second specifiers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%H"), "HH")
  assert.strictEqual(Model.strftimeToQtFormat("%I"), "'\x01I\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%k"), "'\x01pH\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%l"), "'\x01ph\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%M"), "mm")
  assert.strictEqual(Model.strftimeToQtFormat("%S"), "ss")
})

check("translates meridiem and name specifiers to Qt tokens", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%p"), "AP")
  assert.strictEqual(Model.strftimeToQtFormat("%P"), "ap")
  assert.strictEqual(Model.strftimeToQtFormat("%a"), "ddd")
  assert.strictEqual(Model.strftimeToQtFormat("%A"), "dddd")
  assert.strictEqual(Model.strftimeToQtFormat("%b"), "MMM")
  assert.strictEqual(Model.strftimeToQtFormat("%h"), "MMM")
  assert.strictEqual(Model.strftimeToQtFormat("%B"), "MMMM")
})

check("translates day-of-year, weekday, and week-number specifiers to markers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%j"), "'\x01j\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%u"), "'\x01u\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%w"), "'\x01w\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%U"), "'\x01U\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%W"), "'\x01W\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%V"), "'\x01V\x01'")
})

check("expands compound specifiers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%D"), "MM/dd/yy")
  assert.strictEqual(Model.strftimeToQtFormat("%F"), "yyyy-MM-dd")
  assert.strictEqual(Model.strftimeToQtFormat("%R"), "HH:mm")
  assert.strictEqual(Model.strftimeToQtFormat("%T"), "HH:mm:ss")
  assert.strictEqual(Model.strftimeToQtFormat("%r"), "hh:mm:ss AP")
})

check("translates locale compound and offset specifiers to markers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%x"), "'\x01x\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%X"), "'\x01X\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%c"), "'\x01c\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%z"), "'\x01z\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%:z"), "'\x01zc\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%s"), "'\x01s\x01'")
})

check("translates literal specifiers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%n"), "\n")
  assert.strictEqual(Model.strftimeToQtFormat("%t"), "\t")
  assert.strictEqual(Model.strftimeToQtFormat("%%"), "%")
  assert.strictEqual(Model.strftimeToQtFormat("100%%"), "100%")
})

// ---- strftime translation: pad modifiers ----------------------------------

check("maps %- (no pad) and %0 (zero pad) modifiers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%-d"), "d")
  assert.strictEqual(Model.strftimeToQtFormat("%0d"), "dd")
  assert.strictEqual(Model.strftimeToQtFormat("%-m"), "M")
  assert.strictEqual(Model.strftimeToQtFormat("%0m"), "MM")
  assert.strictEqual(Model.strftimeToQtFormat("%-H"), "H")
  assert.strictEqual(Model.strftimeToQtFormat("%0H"), "HH")
  assert.strictEqual(Model.strftimeToQtFormat("%-I"), "'\x01i\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%0I"), "'\x01I\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%-M"), "m")
  assert.strictEqual(Model.strftimeToQtFormat("%0M"), "mm")
  assert.strictEqual(Model.strftimeToQtFormat("%-S"), "s")
  assert.strictEqual(Model.strftimeToQtFormat("%0S"), "ss")
})

check("maps %_ (space pad) modifiers to markers", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%_d"), "'\x01pd\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_m"), "'\x01pm\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_H"), "'\x01pH\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_I"), "'\x01ph\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_M"), "'\x01pM\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_S"), "'\x01pS\x01'")
})

check("treats %e %k %l as space-padded and %I as 12-hour, with modifier variants", function () {
  assert.strictEqual(Model.strftimeToQtFormat("%e"), "'\x01pd\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%-e"), "d")
  assert.strictEqual(Model.strftimeToQtFormat("%0e"), "dd")
  assert.strictEqual(Model.strftimeToQtFormat("%_e"), "'\x01pd\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%k"), "'\x01pH\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%-k"), "H")
  assert.strictEqual(Model.strftimeToQtFormat("%0k"), "HH")
  assert.strictEqual(Model.strftimeToQtFormat("%_k"), "'\x01pH\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%l"), "'\x01ph\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%-l"), "'\x01i\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%0l"), "'\x01I\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_l"), "'\x01ph\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%I"), "'\x01I\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%-I"), "'\x01i\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%0I"), "'\x01I\x01'")
  assert.strictEqual(Model.strftimeToQtFormat("%_I"), "'\x01ph\x01'")
})

// ---- strftime translation: literal text and combined formats ---------------

check("preserves surrounding literal text", function () {
  assert.strictEqual(Model.strftimeToQtFormat("Hello %Y world"), "Hello yyyy world")
  assert.strictEqual(Model.strftimeToQtFormat("%Y年%m月%d日 %A %H:%M"), "yyyy年MM月dd日 dddd HH:mm")
  assert.strictEqual(Model.strftimeToQtFormat("plain"), "plain")
  assert.strictEqual(Model.strftimeToQtFormat(""), "")
})

// ---- strftime translation: invalid formats are null ------------------------

check("rejects unsupported specifiers with null", function () {
  var invalid = ["%Z", "%N", "%Q", "%q", "%G", "%g", "%E", "%O", "%E1", "%O3", "%:q", "%::z", "%:Z"]
  invalid.forEach(function (fmt) {
    assert.strictEqual(Model.strftimeToQtFormat(fmt), null, fmt)
  })
})

check("rejects modifiers on non-pad-able specifiers", function () {
  var invalid = ["%-a", "%0A", "%_B", "%0Y", "%-p", "%_Z"]
  invalid.forEach(function (fmt) {
    assert.strictEqual(Model.strftimeToQtFormat(fmt), null, fmt)
  })
})

check("rejects dangling or malformed percent signs", function () {
  var invalid = ["%", "50%", "%-", "%0", "%_", "%-%", "%0%", "%_%"]
  invalid.forEach(function (fmt) {
    assert.strictEqual(Model.strftimeToQtFormat(fmt), null, fmt)
  })
})

// ---- slot ring --------------------------------------------------------------

check("nextSlot wraps 1→2→3→1", function () {
  assert.strictEqual(Model.nextSlot(1, 3), 2)
  assert.strictEqual(Model.nextSlot(2, 3), 3)
  assert.strictEqual(Model.nextSlot(3, 3), 1)
  assert.strictEqual(Model.nextSlot(1, 1), 1)
})

check("clockSlotRing returns the three slot formats in order, as a copy", function () {
  var input = ["A", "B", "C"]
  var ring = Model.clockSlotRing(input)
  assert.deepStrictEqual(ring, ["A", "B", "C"])
  input.push("D")
  assert.strictEqual(ring.length, 3)
})

// ---- slot defaults ----------------------------------------------------------

check("slotFormat returns the horizontal slot defaults when unset", function () {
  assert.strictEqual(Model.slotFormat(1, {}, false), "dddd HH:mm")
  assert.strictEqual(Model.slotFormat(2, {}, false), "M月d日 dddd HH:mm")
  assert.strictEqual(Model.slotFormat(3, {}, false), "yyyy-MM-dd HH:mm")
})

check("slotFormat returns the vertical slot defaults when unset", function () {
  assert.strictEqual(Model.slotFormat(1, {}, true), "HH\n—\nmm")
  assert.strictEqual(Model.slotFormat(2, {}, true), "dd\nMMM\n'W'ww\n''yy")
  assert.strictEqual(Model.slotFormat(3, {}, true), "ddd\nHH:mm")
})

// ---- migration fallback chain ----------------------------------------------

check("slotFormat prefers the new key over the legacy one", function () {
  assert.strictEqual(Model.slotFormat(1, { format1: "A", format: "B" }, false), "A")
  assert.strictEqual(Model.slotFormat(2, { format2: "C", formatAlt: "D" }, false), "C")
  assert.strictEqual(Model.slotFormat(1, { verticalFormat1: "VA", verticalFormat: "VB" }, true), "VA")
  assert.strictEqual(Model.slotFormat(2, { verticalFormat2: "VC", verticalFormatAlt: "VD" }, true), "VC")
})

check("slotFormat falls back to the legacy key", function () {
  assert.strictEqual(Model.slotFormat(1, { format: "L1" }, false), "L1")
  assert.strictEqual(Model.slotFormat(2, { formatAlt: "L2" }, false), "L2")
  assert.strictEqual(Model.slotFormat(1, { verticalFormat: "VL1" }, true), "VL1")
  assert.strictEqual(Model.slotFormat(2, { verticalFormatAlt: "VL2" }, true), "VL2")
})

check("slotFormat treats an empty new key as unset", function () {
  assert.strictEqual(Model.slotFormat(1, { format1: "" }, false), "dddd HH:mm")
  assert.strictEqual(Model.slotFormat(1, { format1: "", format: "X" }, false), "X")
  assert.strictEqual(Model.slotFormat(2, { format2: "", formatAlt: "Y" }, false), "Y")
})

check("slotFormat has no legacy key for slot 3, and handles missing settings", function () {
  assert.strictEqual(Model.slotFormat(3, { format: "X" }, false), "yyyy-MM-dd HH:mm")
  assert.strictEqual(Model.slotFormat(3, { format3: "Z" }, false), "Z")
  assert.strictEqual(Model.slotFormat(1, null, false), "dddd HH:mm")
  assert.strictEqual(Model.slotFormat(1, undefined, true), "HH\n—\nmm")
})

// ---- regression: the old preset ring is gone, isoWeekLiteral survives -------

check("old ring exports are removed and isoWeekLiteral survives", function () {
  assert.strictEqual(Model.clockFormats, undefined)
  assert.strictEqual(Model.clockFormatRing, undefined)
  assert.strictEqual(Model.nextClockFormat, undefined)
  assert.strictEqual(Model.isoWeekLiteral(2026, 0, 1), "01")
})

if (failures > 0) {
  console.error(failures + " check(s) failed")
  process.exit(1)
}
console.log("all checks passed")
