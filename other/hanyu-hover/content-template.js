"use strict"

const word_data = __word_data__

const hanzi_ranges = [
  [0x2E80,0x2EFF],[0x31C0,0x31EF],[0x3400,0x4DBF],[0x4E00,0x9FFF],
  [0x20000,0x2A6DF],[0x2A700,0x2B73F],[0x2B740,0x2B81F],[0x2B820,0x2CEAF],
  [0x2CEB0,0x2EBEF],[0x30000,0x3134F],[0x31350,0x323AF],[0x2EBF0,0x2EE5F],
  [0x30A0,0x30FF]
]

const is_hanzi = c => {
  if (!c || c.length !== 1) return false
  const u = c.codePointAt(0)
  for (let i = 0; i < hanzi_ranges.length; i++) {
    const r = hanzi_ranges[i]
    if (u >= r[0] && u <= r[1]) return true
  }
  return false
}

const build_index = data => {
  const idx = new Map()
  let max_len = 1
  for (let i = 0; i < data.length; i++) {
    const e = data[i]
    const k = e[0]
    if (!idx.has(k)) idx.set(k, e)
    if (k.length > max_len) max_len = k.length
  }
  return {idx, max_len}
}

const {idx: dict_index, max_len: max_word_len} = build_index(word_data)

let ui = null
let ui_host = null
let listeners_installed = false
let enabled = true
let raf_id = 0
let last_target = null
let last_word = ""
let last_time = 0
let settings = {theme:"auto", font_size_px:null}

const create_ui = () => {
  const host = document.createElement("div")
  host.style.position = "fixed"
  host.style.zIndex = "2147483647"
  host.style.top = "0"
  host.style.left = "0"
  host.style.width = "0"
  host.style.height = "0"
  host.style.pointerEvents = "none"
  const shadow = host.attachShadow({mode: "closed"})
  const box = document.createElement("div")
  box.setAttribute("data-minzhint","1")
  box.style.position = "fixed"
  box.style.minWidth = "120px"
  box.style.maxWidth = "360px"
  box.style.padding = "6px 8px"
  box.style.fontFamily = "system-ui, -apple-system, Segoe UI, Roboto, Noto Sans, sans-serif"
  box.style.fontSize = "13px"
  box.style.lineHeight = "1.25"
  box.style.color = "#111"
  box.style.background = "rgba(255,255,255,0.98)"
  box.style.border = "1px solid rgba(0,0,0,0.15)"
  box.style.borderRadius = "4px"
  box.style.boxShadow = "0 2px 8px rgba(0,0,0,0.2)"
  box.style.pointerEvents = "none"
  box.style.display = "none"
  shadow.appendChild(box)
  document.documentElement.appendChild(host)
  ui_host = host
  ui = {
    show: (x, y, html) => {
      box.innerHTML = html
      const margin = 12, vw = window.innerWidth, vh = window.innerHeight
      const ox = 12, oy = 30
      box.style.display = "block"
      box.style.left = Math.min(vw - box.offsetWidth - margin, Math.max(margin, x + ox)) + "px"
      box.style.top  = Math.min(vh - box.offsetHeight - margin, Math.max(margin, y + oy)) + "px"
    },
    hide: () => { box.style.display = "none"; box.innerHTML = "" },
    set_style: o => {
      if (o.fontSizePx != null) box.style.fontSize = (o.fontSizePx|0) + "px"
      if (o.mode === "dark") {
        box.style.color = "#eee"
        box.style.background = "rgba(18,18,18,0.98)"
        box.style.border = "1px solid rgba(255,255,255,0.18)"
        box.style.boxShadow = "0 2px 8px rgba(0,0,0,0.8)"
      } else if (o.mode === "light") {
        box.style.color = "#111"
        box.style.background = "rgba(255,255,255,0.98)"
        box.style.border = "1px solid rgba(0,0,0,0.15)"
        box.style.boxShadow = "0 2px 8px rgba(0,0,0,0.2)"
      }
    }
  }
}

const ensure_ui = () => {
  if (!ui_host || !document.documentElement.contains(ui_host)) create_ui()
}

const get_range_at_point = (x, y) => {
  if (document.caretRangeFromPoint) return document.caretRangeFromPoint(x, y)
  if (document.caretPositionFromPoint) {
    const pos = document.caretPositionFromPoint(x, y)
    if (!pos) return null
    const r = document.createRange()
    r.setStart(pos.offsetNode, pos.offset)
    r.setEnd(pos.offsetNode, pos.offset)
    return r
  }
  return null
}

const is_ignored_node = n => {
  if (!n) return true
  if (n.nodeType !== 3) return true
  const p = n.parentElement
  if (!p) return true
  if (p.closest("input, textarea, [contenteditable=''], [contenteditable='true']")) return true
  if (p.closest("select, option, script, style")) return true
  return false
}

const longest_match_in_textnode = (node, offset) => {
  const s = node.nodeValue || ""
  if (!s) return null
  let i = offset
  if (i >= s.length) i = s.length - 1
  if (i < 0) return null
  if (!is_hanzi(s[i])) return null
  let L = Math.min(max_word_len, s.length - i)
  while (L > 0) {
    const cand = s.slice(i, i + L)
    if ([...cand].every(is_hanzi) && dict_index.has(cand)) return {text: cand, start: i, end: i + L}
    L -= 1
  }
  let left = i - 1
  while (left >= 0 && is_hanzi(s[left])) {
    let l2 = Math.min(max_word_len, s.length - left)
    while (l2 > 0) {
      const cand2 = s.slice(left, left + l2)
      if ([...cand2].every(is_hanzi) && dict_index.has(cand2)) return {text: cand2, start: left, end: left + l2}
      l2 -= 1
    }
    left -= 1
  }
  return null
}

const render_entry = e => {
  const hanzi = e[0]
  const pinyin = e[1]
  const gloss = Array.isArray(e[2]) ? e[2].join("; ") : String(e[2] || "")
  return "<div><b>"+hanzi+"</b> "+pinyin+"</div><div>"+gloss+"</div>"
}

const on_move = ev => {
  if (!enabled) return
  ensure_ui()
  const now = performance.now()
  if (now - last_time < 12) return
  last_time = now
  if (raf_id) cancelAnimationFrame(raf_id)
  const x = ev.clientX, y = ev.clientY
  raf_id = requestAnimationFrame(() => {
    if (window.getSelection && String(window.getSelection())) { ui.hide(); return }
    const r = get_range_at_point(x, y)
    if (!r) { ui.hide(); return }
    const n = r.startContainer
    if (is_ignored_node(n)) { ui.hide(); return }
    if (n !== last_target) last_word = ""
    last_target = n
    const m = longest_match_in_textnode(n, r.startOffset)
    if (!m) { ui.hide(); last_word = ""; return }
    if (m.text === last_word) return
    last_word = m.text
    const entry = dict_index.get(m.text)
    if (!entry) { ui.hide(); return }
    ui.show(x, y, render_entry(entry))
  })
}

const on_out = () => { if (ui) ui.hide(); last_word = ""; last_target = null }
const on_key = ev => { if (ev.key === "Escape") on_out() }

const install_listeners = () => {
  if (listeners_installed) return
  listeners_installed = true
  const root = document
  root.addEventListener("mousemove", on_move, {passive:true, capture:true})
  root.addEventListener("mouseleave", on_out, {passive:true, capture:true})
  root.addEventListener("scroll", on_out, {passive:true, capture:true})
  root.addEventListener("keydown", on_key, {passive:true, capture:true})
}

const prefers_dark = () => window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches
const compute_mode = () => settings.theme === "auto" ? (prefers_dark() ? "dark" : "light") : settings.theme
const apply_style = () => { if (ui) ui.set_style({mode: compute_mode(), fontSizePx: settings.font_size_px}) }

const init_settings = () => {
  browser.storage?.local.get({theme:"auto", font_size_px:null}).then(v => { settings = v; apply_style() })
  browser.storage?.onChanged.addListener(ch => {
    if (ch.theme) settings.theme = ch.theme.newValue
    if (ch.font_size_px) settings.font_size_px = ch.font_size_px.newValue
    apply_style()
  })
  if (window.matchMedia) {
    const mq = window.matchMedia("(prefers-color-scheme: dark)")
    mq.addEventListener?.("change", () => { if (settings.theme === "auto") apply_style() })
  }
}

const init_toggle_state = () => {
  browser.storage?.local.get({enabled:true}).then(v => { enabled = v.enabled })
}

const handle_messages = () => {
  browser.runtime?.onMessage.addListener(m => {
    if (typeof m.enabled === "boolean") { enabled = m.enabled; if (!enabled && ui) ui.hide() }
  })
}

const init_observers = () => {
  const mo = new MutationObserver(() => ensure_ui())
  mo.observe(document.documentElement, {childList:true, subtree:true})
  window.addEventListener("pageshow", e => { if (e.persisted) { ensure_ui(); install_listeners() } })
  window.addEventListener("popstate", () => { ensure_ui(); install_listeners() })
  window.addEventListener("hashchange", () => { ensure_ui(); install_listeners() })
}

const init = () => {
  ensure_ui()
  install_listeners()
  init_settings()
  init_toggle_state()
  handle_messages()
  init_observers()
}

init()
