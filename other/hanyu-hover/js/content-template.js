"use strict"

const word_data = __word_data__;
const traditional_data = __traditional_data__;

const hanzi_ranges = [
  [0x2E80, 0x2EFF],
  [0x31C0, 0x31EF],
  [0x3400, 0x4DBF],
  [0x4E00, 0x9FFF],
  [0x20000, 0x2A6DF],
  [0x2A700, 0x2B73F],
  [0x2B740, 0x2B81F],
  [0x2B820, 0x2CEAF],
  [0x2CEB0, 0x2EBEF],
  [0x30000, 0x3134F],
  [0x31350, 0x323AF],
  [0x2EBF0, 0x2EE5F],
  [0x30A0, 0x30FF]
]

const helpers = {
  is_hanzi: c => {
    if (!c || c.length !== 1) return false
    const u = c.codePointAt(0)
    for (let i = 0; i < hanzi_ranges.length; i++) {
      const r = hanzi_ranges[i]
      if (u >= r[0] && u <= r[1]) return true
    }
    return false
  },
  in_lang_u: u => {
    for (let i = 0; i < hanzi_ranges.length; i++) {
      const r = hanzi_ranges[i]
      if (u >= r[0] && u <= r[1]) return true
    }
    return false
  },
  normalize_traditional_f() {
    const all_keys = Object.keys(traditional_data)
    const class_string = all_keys.join("")
    const test_regex = new RegExp("[" + class_string + "]")
    const replace_regex = new RegExp("[" + class_string + "]", "g")
    return s =>
      test_regex.test(s) ?
      s.replace(replace_regex, c => traditional_data[c]) :
      s
  }
}

helpers.normalize_traditional = helpers.normalize_traditional_f()

const dict = {
  idx: null,
  max_len: 1,
  build: data => {
    const m = new Map()
    let M = 1
    for (let i = 0; i < data.length; i++) {
      const e = data[i],
        k = e[0]
      if (!m.has(k)) m.set(k, e)
      if (k.length > M) M = k.length
    }
    dict.idx = m
    dict.max_len = M
  },
  lookup_prefixes: s => {
    let best = null,
      parts = []
    const run_max = Math.min(dict.max_len, s.length)
    for (let L = run_max; L >= 1; L--) {
      const cand = s.slice(0, L)
      let ok = true
      for (let k = 0; k < cand.length; k++)
        if (!helpers.is_hanzi(cand[k])) {
          ok = false;
          break
        }
      if (!ok) continue
      if (dict.idx.has(cand)) {
        if (!best) best = cand
        else parts.push(cand)
      }
    }
    if (!best) return null
    const uniq = [best, ...parts.filter(w => w !== best)]
    return {
      primary: uniq[0],
      parts: uniq.slice(1)
    }
  }
}

dict.build(word_data)

const overlay = {
  host: null,
  box: null,
  last_html: "",
  last_bw: 0,
  last_bh: 0,
  ensure: () => {
    if (overlay.host && document.documentElement.contains(overlay.host)) return
    const host = document.createElement("div")
    host.style.position = "fixed"
    host.style.zIndex = "2147483647"
    host.style.top = "0"
    host.style.left = "0"
    host.style.width = "0"
    host.style.height = "0"
    host.style.pointerEvents = "none"
    const shadow = host.attachShadow({
      mode: "closed"
    })
    const box = document.createElement("div")
    box.setAttribute("data-minzhint", "1")
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
    overlay.host = host
    overlay.box = box
    overlay.last_html = ""
    overlay.last_bw = 0
    overlay.last_bh = 0
  },
  set_style: o => {
    if (!overlay.box) return
    if (o.fontSizePx != null) overlay.box.style.fontSize = (o.fontSizePx | 0) + "px"
    if (o.mode === "dark") {
      overlay.box.style.color = "#eee"
      overlay.box.style.background = "rgba(18,18,18,0.98)"
      overlay.box.style.border = "1px solid rgba(255,255,255,0.18)"
      overlay.box.style.boxShadow = "0 2px 8px rgba(0,0,0,0.8)"
    } else if (o.mode === "light") {
      overlay.box.style.color = "#111"
      overlay.box.style.background = "rgba(255,255,255,0.98)"
      overlay.box.style.border = "1px solid rgba(0,0,0,0.15)"
      overlay.box.style.boxShadow = "0 2px 8px rgba(0,0,0,0.2)"
    }
  },
  set_html_and_measure: html => {
    if (html !== overlay.last_html || !overlay.box.firstChild) {
      overlay.box.innerHTML = html
      overlay.box.style.display = "block"
      overlay.last_bw = overlay.box.offsetWidth
      overlay.last_bh = overlay.box.offsetHeight
      overlay.last_html = html
    } else {
      overlay.box.style.display = "block"
    }
  },
  show: (x, y, html) => {
    overlay.set_html_and_measure(html)
    const margin = 12,
      cursor_w = 30,
      cursor_h = 30,
      ox = 12,
      oy = 30
    const vw = window.innerWidth,
      vh = window.innerHeight
    const bw = overlay.last_bw,
      bh = overlay.last_bh
    const cur = {
      l: x - cursor_w / 2,
      t: y - cursor_h / 2,
      r: x + cursor_w / 2,
      b: y + cursor_h / 2
    }
    const clamp = (L, T) => [Math.min(vw - bw - margin, Math.max(margin, L)), Math.min(vh - bh - margin, Math.max(margin, T))]
    const intersects = (L, T) => !(L > cur.r || L + bw < cur.l || T > cur.b || T + bh < cur.t)
    const cands = [
      [cur.r + ox, cur.b + oy],
      [cur.r + ox, cur.t - bh - oy],
      [cur.l - bw - ox, cur.b + oy],
      [cur.l - bw - ox, cur.t - bh - oy]
    ]
    for (let i = 0; i < cands.length; i++) {
      const [L0, T0] = cands[i], [L, T] = clamp(L0, T0)
      if (!intersects(L, T)) {
        overlay.box.style.left = L + "px";
        overlay.box.style.top = T + "px";
        return
      }
    }
    let best = [margin, margin],
      bestd = -1
    for (let i = 0; i < cands.length; i++) {
      const [L, T] = clamp(cands[i][0], cands[i][1])
      const cx = Math.max(L, Math.min(x, L + bw))
      const cy = Math.max(T, Math.min(y, T + bh))
      const d = (cx - x) * (cx - x) + (cy - y) * (cy - y)
      if (d > bestd) {
        bestd = d;
        best = [L, T]
      }
    }
    overlay.box.style.left = best[0] + "px"
    overlay.box.style.top = best[1] + "px"
  },
  hide: () => {
    if (!overlay.box) return
    overlay.box.style.display = "none"
    overlay.box.innerHTML = ""
    overlay.last_html = ""
    overlay.last_bw = 0
    overlay.last_bh = 0
  }
}

const selector = {
  text_node_expr: 'descendant-or-self::text()[not(parent::rp) and not(ancestor::rt)]',
  start_elem_expr: 'boolean(parent::rp or ancestor::rt)',
  is_ignored: n => {
    if (!n) return true
    if (n.nodeType !== 3) return true
    const p = n.parentElement
    if (!p) return true
    if (p.closest("input, textarea, [contenteditable=''], [contenteditable='true']")) return true
    if (p.closest("select, option, script, style")) return true
    return false
  },
  is_inline: node => {
    if (!node || !node.parentElement) return false
    const n = node.nodeName
    if (n === "#text") return true
    const t = {
      FONT: 1,
      TT: 1,
      I: 1,
      B: 1,
      BIG: 1,
      SMALL: 1,
      STRIKE: 1,
      S: 1,
      U: 1,
      EM: 1,
      STRONG: 1,
      DFN: 1,
      CODE: 1,
      SAMP: 1,
      KBD: 1,
      VAR: 1,
      CITE: 1,
      ABBR: 1,
      ACRONYM: 1,
      A: 1,
      Q: 1,
      SUB: 1,
      SUP: 1,
      SPAN: 1,
      WBR: 1,
      RUBY: 1,
      RBC: 1,
      RTC: 1,
      RB: 1,
      RT: 1,
      RP: 1
    }
    return t[n] || getComputedStyle(node, null).getPropertyValue("display") === "inline"
  },
  get_range_at_point: (x, y) => {
    let r = null
    if (document.caretPositionFromPoint) {
      const p = document.caretPositionFromPoint(x, y)
      if (!p || !p.offsetNode) return null
      const node = p.offsetNode
      if (selector.is_ignored(node)) return null
      let offset = p.offset
      let max_len
      if (node.nodeType === 3) {
        max_len = node.data ? node.data.length : 0
      } else {
        max_len = node.childNodes ? node.childNodes.length : 0
      }
      if (max_len < 0) return null
      if (offset < 0) offset = 0
      if (offset > max_len) offset = max_len
      r = document.createRange()
      try {
        r.setStart(node, offset)
      } catch (e) {
        return null
      }
      r.collapse(true)
    } else if (document.caretRangeFromPoint) {
      r = document.caretRangeFromPoint(x, y)
    }
    if (!r || !r.startContainer || r.startContainer.nodeType !== 3) return null
    return r
  },
  get_next_inline: node => {
    let n = node
    if (n && n.nextSibling) return n.nextSibling
    n = node && node.parentNode
    if (n && selector.is_inline(n)) return selector.get_next_inline(n)
    return null
  },
  get_inline_text: (node, max_len, acc_nodes) => {
    let text = ""
    if (!node) return text
    if (node.nodeName === "#text") {
      const take = Math.min(max_len, node.data.length)
      if (acc_nodes) acc_nodes.push({
        node,
        offset: take
      })
      return node.data.slice(0, take)
    }
    const xp = node.ownerDocument.createExpression(selector.text_node_expr, null)
    const it = xp.evaluate(node, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null)
    let t
    while (text.length < max_len && (t = it.iterateNext())) {
      const take = Math.min(t.data.length, max_len - text.length)
      text += t.data.slice(0, take)
      if (acc_nodes) acc_nodes.push({
        node: t,
        offset: take
      })
    }
    return text
  },
  get_text_from_range: (range_parent, offset, max_len, acc_nodes) => {
    if (!range_parent || range_parent.nodeType !== 3) return ""
    const doc = range_parent.ownerDocument
    const deny = doc.evaluate(selector.start_elem_expr, range_parent, null, XPathResult.BOOLEAN_TYPE, null).booleanValue
    if (deny) return ""
    let text = ""
    const end0 = Math.min(range_parent.data.length, offset + max_len)
    text += range_parent.data.slice(offset, end0)
    if (acc_nodes) acc_nodes.push({
      node: range_parent,
      offset: end0
    })
    let n = range_parent
    while (text.length < max_len && (n = selector.get_next_inline(n)) && selector.is_inline(n)) {
      text += selector.get_inline_text(n, max_len - text.length, acc_nodes)
    }
    return text
  },
  find_match: (node, offset) => {
    if (!node || node.nodeType !== 3) return null
    let ro = offset
    const s = node.nodeValue || ""
    if (!s) return null
    if (ro >= s.length) ro = s.length - 1
    if (ro < 0) return null
    while (ro < s.length) {
      const u = s.codePointAt(ro)
      if (u === 0x20 || u === 0x09 || u === 0x0A) ro += 1
      else break
    }
    if (ro >= s.length) return null
    const u0 = s.codePointAt(ro)
    if (!helpers.in_lang_u(u0)) return null
    const buf = selector.get_text_from_range(node, ro, Math.max(13, dict.max_len), null)
    if (!buf) return null
    let res = dict.lookup_prefixes(helpers.normalize_traditional(buf))
    if (res) return res
    let left = ro - 1
    while (left >= 0 && helpers.is_hanzi(s[left])) {
      const alt = selector.get_text_from_range(node, left, Math.max(13, dict.max_len), null)
      res = dict.lookup_prefixes(helpers.normalize_traditional(alt))
      if (res) return res
      left -= 1
    }
    return null
  },
  caret_fixups: (ev, r) => {
    let rp = r.startContainer,
      ro = r.startOffset
    if (!rp || rp.nodeType !== 3) return null
    if (rp.data && ro === rp.data.length) {
      if (rp.nextSibling && rp.nextSibling.nodeName === "WBR") {
        rp = rp.nextSibling.nextSibling;
        ro = 0
      } else if (selector.is_inline(ev.target)) {
        rp = ev.target.firstChild;
        ro = 0
      } else {
        rp = rp.parentNode && rp.parentNode.nextSibling;
        ro = 0
      }
    }
    if (rp && rp.parentNode !== ev.target && ro === 1) {
      const it = document.evaluate(selector.text_node_expr, ev.target, null, XPathResult.ANY_TYPE, null)
      const first = it.iterateNext()
      if (first) {
        rp = first;
        ro = 0
      }
    }
    if (!rp || rp.parentNode !== ev.target) return null
    if (selector.is_ignored(rp)) return null
    return {
      node: rp,
      ofs: ro
    }
  }
}

const render = {
  entries: (primary, alts) => {
    const fmt = e => {
      const hanzi = e[0],
        pinyin = e[1],
        gloss = Array.isArray(e[2]) ? e[2].join("; ") : String(e[2] || "")
      return "<div><b>" + hanzi + "</b> " + pinyin + "</div><div>" + gloss + "</div>"
    }
    let html = fmt(primary)
    for (let i = 0; i < Math.min(3, alts.length); i++) html += "<hr>" + fmt(alts[i])
    return html
  }
}

const settings = {
  theme: "auto",
  font_size_px: null,
  enabled: true,
  apply: () => {
    overlay.set_style({
      mode: settings.theme === "auto" ? (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light") : settings.theme,
      fontSizePx: settings.font_size_px
    })
  },
  init: () => {
    browser.storage?.local.get({
      theme: "auto",
      font_size_px: null,
      enabled: true
    }).then(v => {
      settings.theme = v.theme
      settings.font_size_px = v.font_size_px
      settings.enabled = v.enabled
      settings.apply()
    })
    browser.storage?.onChanged.addListener(ch => {
      if (ch.theme) settings.theme = ch.theme.newValue
      if (ch.font_size_px) settings.font_size_px = ch.font_size_px.newValue
      if (ch.enabled) settings.enabled = ch.enabled.newValue
      settings.apply()
    })
    if (window.matchMedia) {
      const mq = window.matchMedia("(prefers-color-scheme: dark)")
      mq.addEventListener?.("change", () => {
        if (settings.theme === "auto") settings.apply()
      })
    }
  }
}

const control = {
  listeners_installed: false,
  raf_id: 0,
  last_time: 0,
  last_target: null,
  last_word: "",
  on_move: ev => {
    if (!settings.enabled) return
    overlay.ensure()
    const now = performance.now()
    if (now - control.last_time < 12) return
    control.last_time = now
    if (control.raf_id) cancelAnimationFrame(control.raf_id)
    const x = ev.clientX,
      y = ev.clientY
    control.raf_id = requestAnimationFrame(() => {
      if (window.getSelection && String(window.getSelection())) {
        overlay.hide();
        return
      }
      const r = selector.get_range_at_point(x, y)
      if (!r) {
        overlay.hide();
        return
      }
      const fix = selector.caret_fixups(ev, r)
      if (!fix) {
        overlay.hide();
        control.last_word = "";
        return
      }
      const rp = fix.node,
        ro = fix.ofs
      if (rp !== control.last_target) control.last_word = ""
      control.last_target = rp
      const found = selector.find_match(rp, ro)
      if (!found) {
        overlay.hide();
        control.last_word = "";
        return
      }
      if (found.primary === control.last_word) return
      control.last_word = found.primary
      const primary = dict.idx.get(found.primary)
      if (!primary) {
        overlay.hide();
        return
      }
      const alts = found.parts.map(w => dict.idx.get(w)).filter(Boolean)
      const html = render.entries(primary, alts)
      overlay.show(x, y, html)
    })
  },
  on_out: () => {
    overlay.hide()
    control.last_word = ""
    control.last_target = null
  },
  on_key: ev => {
    if (ev.key === "Escape") control.on_out()
  },
  install_listeners: () => {
    if (control.listeners_installed) return
    control.listeners_installed = true
    const root = document
    root.addEventListener("mousemove", control.on_move, {
      passive: true,
      capture: true
    })
    root.addEventListener("mouseleave", control.on_out, {
      passive: true,
      capture: true
    })
    root.addEventListener("scroll", control.on_out, {
      passive: true,
      capture: true
    })
    root.addEventListener("keydown", control.on_key, {
      passive: true,
      capture: true
    })
  },
  observers: () => {
    const mo = new MutationObserver(() => overlay.ensure())
    mo.observe(document.documentElement, {
      childList: true,
      subtree: true
    })
    window.addEventListener("pageshow", e => {
      if (e.persisted) {
        overlay.ensure();
        control.install_listeners()
      }
    })
    window.addEventListener("popstate", () => {
      overlay.ensure();
      control.install_listeners()
    })
    window.addEventListener("hashchange", () => {
      overlay.ensure();
      control.install_listeners()
    })
  },
  messages: () => {
    browser.runtime?.onMessage.addListener(m => {
      if (typeof m.enabled === "boolean") {
        settings.enabled = m.enabled
        if (!settings.enabled) overlay.hide()
      }
    })
  },
  init: () => {
    overlay.ensure()
    control.install_listeners()
    settings.init()
    control.messages()
    control.observers()
  }
}

control.init()
