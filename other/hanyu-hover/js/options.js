"use strict"
const defaults = {
  theme: "auto",
  font_size_px: 13
}
const $ = id => document.getElementById(id)
const load = async () => {
  const v = await browser.storage.local.get(defaults)
  $("theme").value = v.theme
  $("font_size_px").value = v.font_size_px
}
const save = () => browser.storage.local.set({
  theme: $("theme").value,
  font_size_px: parseInt($("font_size_px").value, 10) | 0
})
$("theme").addEventListener("change", save)
$("font_size_px").addEventListener("input", save)
load()
