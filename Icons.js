// Font Awesome codepoints. Every Nerd Font build carries the f0xx/f1xx
// range, so these render on whatever family the shell resolved for
// Style.font.family without shipping an icon font of our own.
var GLYPH = {
  search: "",
  refresh: "",
  updates: "",
  settings: "",
  filter: "",
  warning: "",
  add: "",
  update: "",
  enable: "",
  disable: "",
  remove: "",
  website: "",
  source: "",
  info: "",
  cancel: "",
  close: "",
  back: ""
}

function glyph(name) {
  var value = GLYPH[String(name || "")]
  return value === undefined ? "" : value
}

if (typeof module !== "undefined") {
  module.exports = { GLYPH: GLYPH, glyph: glyph }
}
