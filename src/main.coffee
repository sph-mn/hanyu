character_exclusions_gridlearner = "灬罒彳𠂉⺈辶卝埶冃丏卝宀冖亠䒑丅丷一亅⿻㇀乚丨丿⿰�丶㇒㇏⿹乛㇓㇈⿸乀㇍⿺㇋㇂㇊丆⺊ユ⿾⿶⿵⿴⿲コ凵⿳⿽㇌⿷囗㇎㇅㇄厸䶹乛㇓㇈㇅㇄㇈一亅㇀ 乚丨丿丶㇒㇏㇇乛㇓乀㇍㇂㇊丆二⺊卜十冂ユコ㇄㇅㇎㇌乜㇋厸丫䶹凵囗乁"
character_exclusions = "⿱丅丷一亅⿻㇀乚丨丿⿰�丶㇒㇏⿹乛㇓㇈⿸乀㇍⿺㇋㇂㇊丆⺊ユ⿾⿶⿵⿴⿲コ凵⿳⿽㇌⿷囗㇎㇅㇄厸䶹乛㇓㇈㇅㇄㇈一亅㇀ 乚丨丿丶㇒㇏㇇乛㇓乀㇍㇂㇊丆二⺊卜十冂ユコ㇄㇅㇎㇌乜㇋厸丫䶹凵囗乁"
h = require "./helper"
fs = require "fs"
node_path = require "path"
iconv = require "iconv-lite"
coffee = require "coffeescript"
lookup = require "./lookup"

update_all_characters_with_pinyin = ->
  primary_pinyin_f = lookup.make_primary_pinyin_f()
  order_f = lookup.make_char_freq_dep_index_from_file_f()
  if Object.keys(order_f.index_map).length is 0 then order_f = lookup.make_char_freq_dep_index_f()
  character_set = new Set()
  h.read_csv_file("data/table-of-general-standard-chinese-characters.csv").forEach (row) -> character_set.add row[0]
  h.read_csv_file("data/additional-characters.csv").forEach (row) -> unless character_exclusions.includes row[0] then character_set.add row[0]
  h.read_csv_file("data/characters-strokes-decomposition.csv").forEach (row) ->
    character_set.add row[0]
    return unless row.length >= 3
    h.split_chars(row[2]).forEach (c) -> if c.match h.hanzi_regexp then character_set.add c
  pairs = Array.from(character_set).map (c) -> [c, primary_pinyin_f c]
  pairs.sort (a, b) -> (order_f.index_map[a[0]] ? 9e15) - (order_f.index_map[b[0]] ? 9e15)
  h.write_csv_file "data/characters-pinyin-by-frequency-dependency.csv", pairs

get_all_characters_with_pinyin = -> h.read_csv_file("data/characters-pinyin-by-frequency-dependency.csv")

get_characters_by_pinyin_rows = ->
  primary_pinyin_f = lookup.make_primary_pinyin_f()
  groups = {}
  get_all_characters().forEach (c) ->
    p = primary_pinyin_f c
    return unless p? and not p.endsWith "5"
    (groups[p] ?= []).push c
  rows = Object.keys(groups).map (p) -> [p, groups[p]]
  rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length

get_char_decompositions = (c) ->
  f = lookup.make_char_decompositions_f lookup.make_primary_pinyin_f()
  f c

sort_by_frequency_and_dependency = (rows, char_key) ->
  order_f = lookup.make_char_freq_dep_index_from_file_f()
  if Object.keys(order_f.index_map).length is 0 then order_f = lookup.make_char_freq_dep_index_f()
  rows.sort (a, b) -> (order_f.index_map[a[char_key]] ? 9e15) - (order_f.index_map[b[char_key]] ? 9e15)

dictionary_cedict_to_json = (rows) ->
  JSON.stringify rows.map (r) ->
    r[2] = r[2].split "/"
    r.push r[1].replace /[0-4]/g, ""
    r

update_character_frequency = ->
  buf = fs.readFileSync "/tmp/subtlex-ch-chr"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  out = []
  for line in lines when line.trim() and not line.startsWith("Character") and not line.startsWith("Total")
    parts = line.trim().split /\s+/
    c = parts[0]
    if c.length is 1 then out.push c
  fs.writeFileSync "data/subtlex-characters-by-frequency.txt", out.join "\n"

update_characters_by_frequency_dependency = ->
  order_f = lookup.make_char_freq_dep_index_f()
  ordered = Object.keys(order_f.index_map).sort (a, b) -> order_f.index_map[a] - order_f.index_map[b]
  rows = ordered.map (c, i) -> [c]
  h.write_csv_file "data/characters-by-frequency-dependency.csv", rows

update_word_frequency_pinyin = ->
  char_freq_f = lookup.make_char_freq_index_f()
  dict_f = lookup.make_dictionary_index_word_f 0
  words = h.array_from_newline_file "data/subtlex-words-by-frequency.txt"
  add = (r[0] for r in h.read_csv_file "data/cedict.csv")
  seen = new Set words
  add = (w for w in add when not seen.has w)
  cap = Object.keys(char_freq_f.index_map).length
  add.sort (a, b) ->
    sa = 0
    sb = 0
    sa += (char_freq_f.index_map[c] or cap for c in h.split_chars a)
    sb += (char_freq_f.index_map[c] or cap for c in h.split_chars b)
    sa - sb
  words = words.concat add
  result = for w in words
    e = dict_f w
    continue unless e
    [w, e[0][1], e[0][2]]
  h.write_csv_file "data/words-by-frequency-with-pinyin-translation.csv", result
  h.write_csv_file "data/words-by-frequency-with-pinyin.csv", ([r[0], r[1]] for r in result)

update_characters_by_pinyin = ->
  rows = get_characters_by_pinyin_rows()
  joined = rows.map (r) -> [r[0], r[1].join ""]
  a = joined.sort (x, y) -> x[0].localeCompare(y[0]) || y[1].length - x[1].length
  h.write_csv_file "data/characters-by-pinyin.csv", a
  b = joined.slice().sort (x, y) -> y[1].length - x[1].length || x[0].localeCompare(y[0])
  h.write_csv_file "data/characters-by-pinyin-by-count.csv", b
  rare = []
  rows.forEach (r) -> if r[1].length < 3 then r[1].forEach (c) -> rare.push [c, r[0]]
  rare = rare.sort (x, y) -> x[1].localeCompare(y[1]) || x[0].localeCompare(y[0])
  h.write_csv_file "data/characters-pinyin-rare.csv", rare

update_characters_data = ->
  primary_pinyin_f = lookup.make_primary_pinyin_f()
  char_freq_f = lookup.make_char_freq_index_f()
  contained_by_f = lookup.make_contained_by_map_f()
  graphics = JSON.parse h.read_text_file "data/characters-svg-animcjk-simple.json"
  rows = h.read_csv_file "data/characters-strokes-decomposition.csv"
  contain_sorted = {}
  Object.keys(contained_by_f.index_map).forEach (k) ->
    v = contained_by_f.index_map[k]
    contain_sorted[k] = v.slice().sort (a, b) -> (char_freq_f.index_map[a] ? 9e15) - (char_freq_f.index_map[b] ? 9e15) or a.localeCompare b
  out = []
  for r in rows
    c = r[0]
    s = parseInt r[1],10
    d = r[2] or ""
    svg = graphics[c] or ""
    comps = contain_sorted[c] or []
    p = primary_pinyin_f c
    out.push [c, s, p, d, comps.join(""), svg]
  out = out.sort (x, y) -> (char_freq_f.index_map[x[0]] ? 9e15) - (char_freq_f.index_map[y[0]] ? 9e15)
  fs.writeFileSync "data/characters-svg.json", JSON.stringify out

characters_add_learning_data = (rows, allowed_chars=null) ->
  char_by_reading_f = lookup.make_char_by_reading_index_f()
  primary_pinyin_f = lookup.make_primary_pinyin_f()
  char_decompositions_f = lookup.make_char_decompositions_f primary_pinyin_f
  contained_by_f = lookup.make_contained_by_map_f()
  rows = h.array_deduplicate_key rows, (r) -> r[0]
  max_same = 16
  max_containing = 5
  in_scope = (c) -> (not allowed_chars?) or allowed_chars.has c
  add_same_reading = (rows) ->
    rows.map (r) ->
      cs = (char_by_reading_f.index_map[r[1]] or []).filter(in_scope).slice 0, max_same
      cs = cs.filter (c) -> c isnt r[0]
      r.push cs.join ""
      r
  add_contained = (rows) ->
    rows.map (r) ->
      comps = (char_decompositions_f r[0])
      formatted = comps.map (c) -> "#{c[0]} #{c[1]}"
      r.push formatted.join ", "
      r
  add_containing = (rows) ->
    rows.map (r) ->
      carriers = (contained_by_f r[0]).filter(in_scope).slice 0, max_containing
      formatted = carriers.map((c) -> p = primary_pinyin_f c; if p then "#{c} #{p}" else null).filter Boolean
      r.push formatted.join ", "
      r
  add_examples = (rows) ->
    top_examples_f = lookup.make_top_examples_f()
    rows.map (r) ->
      words = top_examples_f r[0], 4
      r.push words.map((w) -> w.join " ").join "\n"
      r
  add_reading_classification = (rows) ->
    rows.map (r) ->
      cs = (char_by_reading_f.index_map[r[1]] or []).filter(in_scope)
      label = if cs.length is 1 then "unique" else if cs.length <= 3 then "rare" else ""
      r.push label
      r
  add_sort_field = (rows) ->
    a.push i for a, i in rows
    rows
  rows = add_contained rows
  rows = add_containing rows
  rows = add_same_reading rows
  rows = add_sort_field rows
  rows = add_examples rows
  rows = add_reading_classification rows
  rows

update_characters_learning = ->
  all_rows = get_all_characters_with_pinyin()
  all_rows = sort_by_frequency_and_dependency all_rows, 0
  mid = Math.ceil all_rows.length / 2
  first = all_rows.slice 0, mid
  second = all_rows.slice mid
  first_set = new Set first.map (r) -> r[0]
  first_out = characters_add_learning_data first, first_set
  second_out = characters_add_learning_data second
  write_set = (rows, suffix) ->
    base = "data/characters-learning"
    h.write_csv_file "#{base}#{suffix}.csv", rows
    reduced = ([i + 1, r[0], r[1], r[5], r[3]] for r, i in rows)
    h.write_csv_file "#{base}-reduced#{suffix}.csv", reduced
  write_set first_out, ""
  write_set second_out, "-extended"

update_lists = (paths) ->
  nav_links = []
  paths = (p for p in paths when h.is_file p)
  content = for path, i in paths
    rows = h.read_csv_file path
    parts = for r in rows
      [head, tail...] = r
      tail = tail.join " "
      "<b><b>#{head}</b><b>#{tail}</b></b>"
    label = h.strip_extensions node_path.basename path
    nav_links.push "<a href=\"#\" data-target=\"#{i}\">#{label}</a>"
    "<div>" + parts.join("\n") + "</div>"
  content = content.join "\n"
  nav_links = nav_links.join "\n"
  font = h.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = h.read_text_file "src/lists-template.html"
  html = h.replace_placeholders html, {font, content, nav_links}
  fs.writeFileSync "tmp/lists.html", html

update_gridlearner_data = ->
  primary_pinyin_f = lookup.make_primary_pinyin_f()
  full_comps_map = lookup.make_full_compositions_index_f().index_map
  full_decomps_map = lookup.make_full_decompositions_index_f().index_map
  all_rows = sort_by_frequency_and_dependency get_all_characters_with_pinyin(), 0
  mid = Math.ceil all_rows.length / 2
  top4000 = new Set all_rows.slice(0, mid).map (r) -> r[0]
  top8000 = new Set all_rows.map (r) -> r[0]
  excluded = new Set h.split_chars character_exclusions_gridlearner
  ok = (c) -> typeof c is "string" and c.length is 1 and c.match(h.hanzi_regexp) and not excluded.has c
  pin = (c) -> primary_pinyin_f c
  dedup = (a) -> h.delete_duplicates_stable a
  contained_rows = (pool) ->
    out = []
    pool.forEach (parent) ->
      return unless ok parent
      comps = full_decomps_map[parent] or []
      for child in comps when ok child
        py = pin(child) ? "-"
        out.push [parent, child, py]
    dedup out
  containing_rows = (pool) ->
    out = []
    for comp, parents of full_comps_map when ok comp
      for parent in parents when pool.has(parent) and ok parent
        py = pin(parent) ? "-"
        out.push [comp, parent, py]
    dedup out
  by_pinyin_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok c
      py = pin c
      return unless py
      (groups[py] ?= []).push c
    order = Object.keys(groups).sort (a, b) -> groups[b].length - groups[a].length or a.localeCompare b
    rows = []
    order.forEach (py) -> groups[py].forEach (c) -> rows.push [py, c, py]
    rows
  by_syllable_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok c
      py = pin c
      return unless py
      syl = py.replace /[0-5]$/, ""
      (groups[syl] ?= []).push [c, py]
    order = Object.keys(groups).sort (a, b) -> groups[b].length - groups[a].length or a.localeCompare b
    rows = []
    order.forEach (syl) -> groups[syl].forEach ([c, py]) -> rows.push [syl, c, py]
    rows
  write = (tag, rows) -> h.write_csv_file "data/gridlearner/characters-#{tag}.csv", rows
  write "top4000-containing",  containing_rows top4000
  write "top4000-by_pinyin",   by_pinyin_rows  top4000
  write "top4000-by_syllable", by_syllable_rows top4000
  write "top8000-containing",  containing_rows top8000
  write "top8000-by_pinyin",   by_pinyin_rows  top8000
  write "top8000-by_syllable", by_syllable_rows top8000
  unique_rows = (pool) ->
    counts = {}
    pool.forEach (c) ->
      py = pin c
      return unless py?
      counts[py] = (counts[py] or 0) + 1
    rows = []
    pool.forEach (c) ->
      py = pin c
      return unless py?
      return unless counts[py] is 1
      rows.push [c, py]
    rows.sort (a, b) -> a[1].localeCompare(b[1]) or a[0].localeCompare(b[0])
  write "top4000-unique", unique_rows top4000
  write "top8000-unique", unique_rows top8000

update_dictionary = ->
  rows = h.read_csv_file "data/cedict.csv"
  word_data = dictionary_cedict_to_json rows
  character_data = h.read_text_file "data/characters-svg.json"
  src = h.read_text_file "src/dictionary.coffee"
  compiled = coffee.compile(src, bare: true).trim()
  script = h.replace_placeholders compiled, {word_data, character_data}
  font = h.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = h.read_text_file "src/hanyu-dictionary-template.html"
  html = h.replace_placeholders html, {font, script}
  fs.writeFileSync "compiled/hanyu-dictionary.html", html

add_missing_pinyin = ->
  rows = h.read_csv_file "data/characters-strokes-decomposition.csv"
  primary_pinyin = lookup.make_primary_pinyin_f()
  for a in rows
    console.log a

dsv_add_pinyin = (character_index) ->
  primary_pinyin = lookup.make_primary_pinyin_f()
  rows = h.read_csv_file(0).map (a) ->
    pinyin = primary_pinyin a[character_index]
    a[1] = pinyin
    a
  h.write_csv_file 1, rows

update_characters_traditional = ->
  chars = h.read_csv_file("data/characters-by-frequency-dependency.csv")
  traditional = for [a, ...b] in chars
    b = h.simplified_to_traditional a
    [b, a] unless b is a
  h.write_csv_file "data/characters-traditional.csv", h.compact traditional

debug_primary_pinyin = ->
  # 戌 - contains 5 and wrong pinyin
  # 丧 - sang1 but should be sang4
  primary_pinyin = lookup.make_primary_pinyin_f()
  pinyin = primary_pinyin "戌"
  console.log pinyin
  pinyin = primary_pinyin "宀"
  console.log pinyin
  pinyin = primary_pinyin "宴"
  console.log pinyin
  char_decompositions_f = lookup.make_char_decompositions_f primary_pinyin
  console.log char_decompositions_f "宴"

run = ->
  #update_all_characters_with_pinyin()
  #update_characters_by_frequency_dependency()
  update_characters_data()
  #add_missing_pinyin()
  #update_gridlearner_data()

module.exports = {
  run
  update_characters_learning
  update_dictionary
  update_gridlearner_data
  update_lists
  update_characters_by_pinyin
  update_characters_data
  update_word_frequency_pinyin
  update_character_frequency
  update_characters_by_frequency_dependency
}
