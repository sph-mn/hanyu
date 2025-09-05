h = require "./helper"
fs = require "fs"
node_path = require "path"
iconv = require "iconv-lite"
coffee = require "coffeescript"
lookup = require "./lookup"

get_all_standard_characters_with_pinyin = ->
  standard_rows = h.read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (row) -> [row[0], row[1].split(",")[0]]
  additional_rows = h.read_csv_file("data/additional-characters.csv").filter((row) -> !character_exclusions.includes(row[0])).map (row) -> [row[0], row[1].split(",")[0]]
  standard_rows.concat additional_rows

get_all_characters = ->
  Object.keys lookup.stroke_count_index()

get_all_characters_sorted_by_frequency = ->
  frequency_index_map = lookup.char_freq_index()
  Object.keys(frequency_index_map).sort (a, b) -> frequency_index_map[a] - frequency_index_map[b]

sort_by_index_and_character_f = (index_map, character_key) ->
  comparator = sort_by_character_f index_map
  (row_a, row_b) -> comparator row_a[character_key], row_b[character_key]

sort_by_character_f = (index_map) ->
  (char_a, char_b) ->
    index_a = index_map[char_a]
    index_b = index_map[char_b]
    if index_a is undefined and index_b is undefined
      (char_a.length - char_b.length) || char_a.localeCompare(char_b) || char_b.localeCompare(char_a)
    else if index_a is undefined then 1
    else if index_b is undefined then -1
    else index_a - index_b

sort_by_character_frequency = (frequency_index_map, character_key, rows) ->
  rows.sort sort_by_index_and_character_f frequency_index_map, character_key

dictionary_cedict_to_json = (rows) ->
  JSON.stringify rows.map (row) ->
    row[2] = row[2].split "/"
    row.push row[1].replace /[0-4]/g, ""
    row

get_character_pinyin_index = ->
  characters = get_all_characters()
  index_map = {}
  characters.forEach (ch) ->
    py = lookup.primary_pinyin ch
    if py? and not py.endsWith "5"
      index_map[ch] = py
  index_map

get_characters_by_pinyin_rows = ->
  groups = {}
  get_all_characters().forEach (ch) ->
    py = lookup.primary_pinyin ch
    return unless py? and not py.endsWith "5"
    h.object_array_add groups, py, ch
  rows = Object.keys(groups).map (py) -> [py, groups[py]]
  rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length

get_compositions_index = ->
  compositions_map = lookup.full_compositions_index()
  frequency_sorter = sort_by_character_f lookup.char_freq_index()
  for component, parents of compositions_map
    compositions_map[component] = parents.sort frequency_sorter
  compositions_map

get_full_decompositions_index = ->
  lookup.full_decompositions_index()

get_stroke_count_index = ->
  lookup.stroke_count_index()

get_char_pinyin = do ->
  dictionary_lookup = lookup.dictionary_index_word_f 0
  (ch) ->
    entries = dictionary_lookup ch
    return entries[0][1] if entries and entries.length
    lookup.primary_pinyin ch

get_char_decompositions = do ->
  decompositions_index = lookup.full_decompositions_index()
  stroke_index_map = lookup.stroke_count_index()
  (ch) ->
    parts = decompositions_index[ch]
    return [] unless parts
    parts = parts.filter (c) -> !stroke_index_map[c] or stroke_index_map[c] > 1
    parts.map((c) -> [c, get_char_pinyin(c)]).filter (p) -> p[1]

get_character_reading_count_index = ->
  result = {}
  h.read_csv_file("data/characters-pinyin-count.csv").forEach (row) -> result[row[0] + row[1]] = parseInt row[2],10
  result

get_character_example_words_f = ->
  (char, pinyin, frequency_limit) ->
    limit = if frequency_limit? then frequency_limit else Infinity
    lookup.top_examples char, limit

sort_by_frequency_and_dependency = (rows, char_key) ->
  dependency_frequency_index = lookup.char_freq_dep_index()
  rows.sort (a, b) ->
    ia = dependency_frequency_index[a[char_key]]
    ib = dependency_frequency_index[b[char_key]]
    (if ia? then ia else 9e15) - (if ib? then ib else 9e15)

update_character_frequency = ->
  buf = fs.readFileSync "/tmp/subtlex-ch-chr"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  chars = []
  for line in lines when line.trim() and not line.startsWith("Character") and not line.startsWith("Total")
    parts = line.trim().split /\s+/
    chr = parts[0]
    if chr.length is 1
      chars.push chr
  fs.writeFileSync "data/subtlex-characters-by-frequency.txt", chars.join "\n"

update_word_frequency_pinyin = ->
  words = h.array_from_newline_file "data/subtlex-words-by-frequency.txt"
  additional_words = (a[0] for a in h.read_csv_file("data/cedict.csv"))
  words_set = new Set words
  additional_words = (a for a in additional_words when not words_set.has a)
  cfi = lookup.char_freq_index()
  cfi_length = Object.keys(cfi).length
  additional_words.sort (a, b) ->
    a_score = 0
    b_score = 0
    a_score += (cfi[c] || cfi_length for c in h.split_chars(a))
    b_score += (cfi[c] || cfi_length for c in h.split_chars(b))
    a_score - b_score
  words = words.concat additional_words
  dict = dictionary_index_word_f 0
  result = for word in words
    entry = dict word
    continue unless entry
    pinyin = entry[0][1]
    translation = entry[0][2]
    [word, pinyin, translation]
  h.write_csv_file "data/words-by-frequency-with-pinyin-translation.csv", result
  result = ([a[0], a[1]] for a in result)
  h.write_csv_file "data/words-by-frequency-with-pinyin.csv", result

update_characters_by_pinyin = () ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> h.object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length
  h.write_csv_file "data/characters-by-pinyin.csv", rows
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  h.write_csv_file "data/characters-by-pinyin-by-count.csv", rows
  rare_rows = []
  for p in Object.keys(by_pinyin)
    if by_pinyin[p].length < 3
      for c in by_pinyin[p]
        rare_rows.push [c, p]
  rare_rows = rare_rows.sort (a, b) -> a[1].localeCompare(b[1]) || a[0].localeCompare(b[0])
  h.write_csv_file "data/characters-pinyin-rare.csv", rare_rows

update_characters_data = ->
  graphics_data = JSON.parse h.read_text_file "data/characters-svg-animcjk-simple.json"
  character_data = h.read_csv_file "data/characters-strokes-decomposition.csv"
  compositions_index = get_compositions_index()
  dictionary_lookup = dictionary_index_word_f 0
  character_frequency_index = lookup.char_freq_index()
  result = []
  for a, i in character_data
    [char, strokes, decomposition] = a
    strokes = parseInt strokes, 10
    svg_paths = graphics_data[char] || ""
    compositions = compositions_index[char] || []
    entries = dictionary_lookup char
    if entries and entries.length
      entry = entries[0]
      pinyin = entry[1]
    else pinyin = ""
    result.push [char, strokes, pinyin, decomposition || "", compositions.join(""), svg_paths]
  result = sort_by_character_frequency character_frequency_index, 0, result
  fs.writeFileSync "data/characters-svg.json", JSON.stringify result

characters_add_learning_data = (rows, allowed_chars = null) ->
  reading_count_index = get_character_reading_count_index()
  character_by_reading_index = get_character_by_reading_index()
  get_character_example_words = get_character_example_words_f()
  compositions_index = get_compositions_index()
  pinyin_index = get_character_pinyin_index()
  dictionary_lookup = dictionary_index_word_f 0
  primary_pinyin = (c) -> pinyin_index[c] ? (dictionary_lookup(c)?[0][1])
  rows = h.array_deduplicat_key rows, (r) -> r[0]
  max_same = 16
  max_containing = 5
  in_scope = (c) -> (not allowed_chars?) or allowed_chars.has c
  add_same_reading = (rows) ->
    rows.map (r) ->
      chars = (character_by_reading_index[r[1]] or []).filter(in_scope).slice 0, max_same
      chars = chars.filter (c) -> c isnt r[0]
      r.push chars.join ""
      r
  add_contained = (rows) ->
    rows.map (r) ->
      comps = get_char_decompositions(r[0]).map (x) -> x[0]
      comps = comps.filter(in_scope)
      formatted = comps
        .map (c) -> pp = primary_pinyin c; if pp then "#{c} #{pp}" else null
        .filter Boolean
      r.push formatted.join ", "
      r
  add_containing = (rows) ->
    rows.map (r) ->
      carriers = (compositions_index[r[0]] or []).filter(in_scope).slice 0, max_containing
      formatted = carriers
        .map (c) -> pp = primary_pinyin c; if pp then "#{c} #{pp}" else null
        .filter Boolean
      r.push formatted.join ", "
      r
  add_examples = (rows) ->
    rows.map (r) ->
      words = get_character_example_words r[0], r[1]
      if words.length && r[0] == words[0][0]
        char_word = words[0]
        words = words.slice(1, 5)
      else
        char_word = null
        words = words
      r.push words.map((w) -> w[0]).join " "
      r.push words.concat(if char_word then [char_word] else []).map((w) -> w.join " ").join "\n"
      r
  add_reading_classification = (rows) ->
    rows.map (r) ->
      reading = r[1]
      chars = (character_by_reading_index[reading] or []).filter(in_scope)
      if chars.length == 1 then label = "unique"
      else if chars.length <= 3 then label ="rare"
      else label = ""
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
  all_rows = get_all_standard_characters_with_pinyin()
  all_rows = sort_by_frequency_and_dependency all_rows, 0
  mid      = Math.ceil all_rows.length / 2
  first    = all_rows.slice 0, mid
  second   = all_rows.slice mid
  first_set = new Set first.map (r) -> r[0]
  first_out  = characters_add_learning_data first, first_set
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
  paths = (a for a in paths when h.is_file a)
  content = for path, i in paths
    rows = h.read_csv_file path
    parts = for row in rows
      [head, tail...] = row
      tail = tail.join " "
      """
      <b><b>#{head}</b><b>#{tail}</b></b>
      """
    label = h.strip_extensions node_path.basename path
    nav_links.push """
       <a href="#" data-target="#{i}">#{label}</a>
    """
    "<div>" + parts.join("\n") + "</div>"
  content = content.join "\n"
  nav_links = nav_links.join "\n"
  font = h.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = h.read_text_file "src/lists-template.html"
  html = h.replace_placeholders html, {font, content, nav_links}
  fs.writeFileSync "tmp/lists.html", html

update_gridlearner_data = ->
  all_rows = sort_by_frequency_and_dependency get_all_standard_characters_with_pinyin(), 0
  mid = Math.ceil all_rows.length / 2
  top4000 = new Set all_rows.slice(0, mid).map (r) -> r[0]
  top8000 = new Set all_rows.map (r) -> r[0]
  pin_idx = get_character_pinyin_index()
  full_comps = get_full_compositions_index()
  full_decomps = get_full_decompositions_index()
  dedup_stable = (a) -> h.delete_duplicates_stable a
  excluded = new Set h.split_chars character_exclusions_gridlearner
  ok_char = (c) -> typeof c is "string" and c.length is 1 and c.match(h.hanzi_regexp) and not excluded.has c
  contained_rows = (pool) ->
    out = []
    pool.forEach (parent) ->
      return unless ok_char parent
      comps = full_decomps[parent] or []
      for child in comps when ok_char child
        py = pin_idx[child] ? "-"
        out.push [parent, child, py]
    dedup_stable out
  containing_rows = (pool) ->
    out = []
    for comp, parents of full_comps when ok_char comp
      for parent in parents when pool.has(parent) and ok_char parent
        py = pin_idx[parent] ? "-"
        out.push [comp, parent, py]
    dedup_stable out
  by_pinyin_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok_char c
      py = pin_idx[c]
      return unless py
      (groups[py] ?= []).push c
    order = Object.keys(groups).sort (a, b) -> groups[b].length - groups[a].length or a.localeCompare b
    rows = []
    order.forEach (py) -> groups[py].forEach (c) -> rows.push [py, c, py]
    rows
  by_syllable_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok_char c
      py = pin_idx[c]
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
    pool.forEach (ch) ->
      py = pin_idx[ch]
      return unless py?
      counts[py] = (counts[py] or 0) + 1
    rows = []
    pool.forEach (ch) ->
      py = pin_idx[ch]
      return unless py?
      return unless counts[py] is 1
      rows.push [ch, py]
    rows.sort (a, b) -> a[1].localeCompare(b[1]) or a[0].localeCompare(b[0])
  write "top4000-unique", unique_rows top4000
  write "top8000-unique", unique_rows top8000

update_dictionary = ->
  word_rows = h.read_csv_file "data/cedict.csv"
  word_data = dictionary_cedict_to_json word_rows
  character_data = h.read_text_file "data/characters-svg.json"
  script_source = h.read_text_file "src/dictionary.coffee"
  script_compiled = coffee.compile(script_source, bare: true).trim()
  script_filled = h.replace_placeholders script_compiled, {word_data, character_data}
  font_base64 = h.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html_template = h.read_text_file "src/hanyu-dictionary-template.html"
  html_filled = h.replace_placeholders html_template, {font: font_base64, script: script_filled}
  fs.writeFileSync "compiled/hanyu-dictionary.html", html_filled

run = ->
  update_character_frequency()

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
}
