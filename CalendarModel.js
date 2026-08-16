// The clock talks to Caldir through a small local command rather than parsing
// ICS itself. Caldir already handles recurrence, time zones, and provider IDs.

function parseBridgeOutput(text) {
  try {
    var result = JSON.parse(String(text || ""))
    if (result && result.ok === true && Array.isArray(result.events)) {
      var start = /^\d{4}-\d{2}-\d{2}$/.test(String(result.range_start || "")) ? result.range_start : ""
      var end = /^\d{4}-\d{2}-\d{2}$/.test(String(result.range_end || "")) ? result.range_end : ""
      return { events: result.events, rangeStart: start, rangeEnd: end, error: "" }
    }
    return { events: [], rangeStart: "", rangeEnd: "", error: String((result && result.error) || "Calendar data is unavailable") }
  } catch (error) {
    return { events: [], rangeStart: "", rangeEnd: "", error: "Calendar data is unavailable" }
  }
}

function localDateKey(value) {
  var text = String(value || "")
  if (/^\d{4}-\d{2}-\d{2}$/.test(text)) return text
  var date = new Date(text)
  if (isNaN(date.getTime())) return ""
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate())
}

function pad2(value) {
  return Number(value) < 10 ? "0" + Number(value) : String(Number(value))
}

function eventDateKeys(event) {
  var first = localDateKey(event && event.start)
  if (!first) return []
  var last = localDateKey(event && event.end)
  if (!last || last < first) return [first]

  var cursor = new Date(first + "T12:00:00")
  var end = new Date(last + "T12:00:00")
  // All-day calendar end values are exclusive. Timed events ending exactly at
  // midnight should not appear to span into the following day either.
  if (event.all_day || /T00:00(?::00)?(?:Z|[+-]\d\d:\d\d)?$/.test(String(event.end || "")))
    end.setDate(end.getDate() - 1)

  var keys = []
  while (cursor <= end && keys.length < 370) {
    keys.push(localDateKey(cursor.toISOString()))
    cursor.setDate(cursor.getDate() + 1)
  }
  return keys.length > 0 ? keys : [first]
}

function eventsForDate(events, dateKey) {
  var list = []
  for (var i = 0; i < (events || []).length; i++) {
    if (eventDateKeys(events[i]).indexOf(String(dateKey)) !== -1) list.push(events[i])
  }
  return list
}

function countForDate(events, dateKey) {
  return eventsForDate(events, dateKey).length
}

function calendarColor(event) {
  var color = String((event && event.calendar_color) || "")
  return /^#[0-9a-fA-F]{6}$/.test(color) ? color : ""
}

var URL_PATTERN = /https?:\/\/[^\s<>"']+/g
var CONFERENCE_HOST_PATTERN = /(meet\.google\.com|zoom\.us|zoom\.com|teams\.microsoft\.com|webex\.com|whereby\.com|jitsi\.me|meet\.jit\.si|gotomeeting\.com|goto\.me)/i

function extractUrls(text) {
  var urls = []
  var seen = {}
  var match
  URL_PATTERN.lastIndex = 0
  while ((match = URL_PATTERN.exec(String(text || ""))) !== null) {
    var url = String(match[0]).replace(/[.,;:!?]+$/, "").replace(/[)\]}>]+$/, "")
    if (url !== "" && !seen[url]) {
      seen[url] = true
      urls.push(url)
    }
  }
  return urls
}

// Meeting links first: Google puts Meet links in the event's dedicated
// conference field, then in the location. Any conference-host URLs found in
// the description follow, then the remaining URLs in description order.
// Returns a de-duplicated ordered list.
function eventMeetingLinks(event) {
  var links = []
  var seen = {}
  function add(list) {
    for (var i = 0; i < list.length; i++) {
      if (!seen[list[i]]) {
        seen[list[i]] = true
        links.push(list[i])
      }
    }
  }
  add(extractUrls(event && event.conference_url))
  add(extractUrls(event && event.location))
  var description = extractUrls(event && event.description)
  var conference = []
  var rest = []
  for (var i = 0; i < description.length; i++) {
    if (CONFERENCE_HOST_PATTERN.test(description[i])) conference.push(description[i])
    else rest.push(description[i])
  }
  add(conference)
  add(rest)
  return links
}

// Same identity the agenda rows use, so reminders and the next-event
// highlight can address the exact event occurrence on screen.
function eventKeyFor(event) {
  return String(event.instance_id
    || (String(event.calendar || "") + ":" + String(event.uid || "")
      + ":" + String(event.start || "")))
}

function calendarColorsForDate(events, dateKey) {
  var dayEvents = eventsForDate(events, dateKey)
  var colors = []
  for (var i = 0; i < dayEvents.length; i++) {
    var color = calendarColor(dayEvents[i])
    if (color !== "" && colors.indexOf(color) === -1) colors.push(color)
  }
  return colors
}

// Build this once as a cache snapshot arrives instead of asking every one of
// the 42 month cells to scan every event whenever the visible month changes.
// Each entry deliberately carries both the events and its unique calendar
// colours, making grid dots, tooltips, and the agenda simple lookups.
function indexEventsByDate(events) {
  var index = {}
  for (var i = 0; i < (events || []).length; i++) {
    var event = events[i]
    var keys = eventDateKeys(event)
    var color = calendarColor(event)
    for (var j = 0; j < keys.length; j++) {
      var key = keys[j]
      if (!index[key]) index[key] = { events: [], colors: [] }
      index[key].events.push(event)
      if (color !== "" && index[key].colors.indexOf(color) === -1)
        index[key].colors.push(color)
    }
  }
  return index
}
