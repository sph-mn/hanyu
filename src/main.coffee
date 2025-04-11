csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
coffee = require "coffeescript"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
html_parser = require "node-html-parser"
path = require "path"
pinyin_split = require "pinyin-split"
pinyin_utils = require "pinyin-utils"
read_text_file = (file) -> fs.readFileSync file, "utf8"
read_csv_file = (file, delimiter = " ") -> csv_parse.parse read_text_file(file), {delimiter: delimiter, relax_column_count: true}
array_from_newline_file = (file) -> read_text_file(file).trim().split "\n"
replace_placeholders = (txt, map) -> txt.replace /__(.*?)__/g, (_, k) -> map[k] or ""
on_error = (err) -> if err then console.error err
unique = (arr, key_fn = (x) -> x) -> seen = {} ; arr.filter (x) -> k = key_fn(x) ; if seen[k] then false else (seen[k] = true; true)
object_array_add = (obj, key, val, uniq = false) ->
  if obj[key]
    if uniq then obj[key].push val unless obj[key].includes val else obj[key].push val
  else obj[key] = [val]
n_times = (n, f) -> for i in [0...n] then f i
random_integer = (min, max) -> Math.floor(Math.random() * (max - min + 1)) + min
random_element = (arr) -> arr[random_integer(0, arr.length - 1)]
split_chars = (str) -> [...str]
median = (arr) -> sorted = arr.slice().sort((a, b) -> a - b); sorted[Math.floor(sorted.length / 2)]
sum = (arr) -> arr.reduce ((a, b) -> a + b), 0
mean = (arr) -> sum(arr) / arr.length
lcg = (seed) -> m = 2 ** 31; a = 1103515245; c = 12345; state = seed; -> state = (a * state + c) % m; state / m
array_shuffle = (arr) ->
  rand = lcg(23465700980)
  n = arr.length
  while n > 0
    i = Math.floor(rand() * n)
    n--
    [arr[n], arr[i]] = [arr[i], arr[n]]
  arr
hanzi_unicode_ranges = [
  ["30A0", "30FF"]
  ["2E80", "2EFF"]
  ["31C0", "31EF"]
  ["4E00", "9FFF"]
  ["3400", "4DBF"]
  ["20000", "2A6DF"]
  ["2A700", "2B73F"]
  ["2B740", "2B81F"]
  ["2B820", "2CEAF"]
  ["2CEB0", "2EBEF"]
  ["30000", "3134F"]
  ["31350", "323AF"]
  ["2EBF0", "2EE5F"]
]
unicode_ranges_pattern = (ranges, reject) ->
  "[" + (if reject then "^" else "") + ranges.map((r) -> r.map((b) -> "\\u{" + b + "}").join("-")).join("") + "]"
unicode_ranges_regexp = (ranges, reject) -> new RegExp(unicode_ranges_pattern(ranges, reject), "gu")
hanzi_regexp = unicode_ranges_regexp(hanzi_unicode_ranges)
non_hanzi_regexp = unicode_ranges_regexp(hanzi_unicode_ranges, true)
hanzi_and_idc_regexp = unicode_ranges_regexp(hanzi_unicode_ranges.concat([["2FF0", "2FFF"]]))
non_pinyin_regexp = /[^a-z0-5]/g
pinyin_split2 = (txt) -> txt.replace(/[0-5]/g, (d) -> d + " ").trim().split " "
get_frequency_index = () ->
  freq = array_from_newline_file("data/words-by-frequency-with-pinyin.csv")
  idx = {}
  for i, line in freq
    line = line.replace " ", ""
    if not idx[line] then idx[line] = i
  idx
get_all_standard_characters = () -> for row in read_csv_file("data/table-of-general-standard-chinese-characters.csv") then row[0]
get_all_standard_characters_with_pinyin = () ->
  a = for row in read_csv_file("data/table-of-general-standard-chinese-characters.csv") then [row[0], row[1].split(",")[0]]
  b = for row in read_csv_file("data/additional-characters.csv") when not character_exclusions.includes(row[0]) then [row[0], row[1].split(",")[0]]
  a.concat b
get_all_characters = () -> for row in read_csv_file("data/characters-strokes-decomposition.csv") then row[0]
display_all_characters = () -> console.log (get_all_characters()).join("")
get_all_characters_with_pinyin = () ->
  a = read_csv_file("data/table-of-general-standard-chinese-characters.csv")
  b = read_csv_file("data/additional-characters.csv")
  comb = b.concat a
  res = []
  for row in comb
    pin = row[1].split(", ")[0]
    res.push [row[0] + pin, row[0], pin]
  unique(res, (x) -> x[0]).map (r) -> [r[1], r[2].replace("u:", "ü")]
get_character_by_reading_index = () ->
  chars = get_all_characters_with_pinyin()
  res = {}
  for row in chars
    object_array_add(res, row[1], row[0])
  res
get_frequency_characters_and_pinyin = () ->
  res = []
  rows = read_csv_file("data/words-by-frequency-with-pinyin.csv")
  for row in rows
    chs = split_chars(row[0])
    pins = pinyin_split2(row[1])
    for i, ch of chs
      res.push [ch, pins[i]]
  res
get_all_characters_sorted_by_frequency = () ->
  unique(for row in get_all_characters_with_pinyin() then split_chars(row[0])[0])
get_character_frequency_index = () ->
  chars = get_all_characters_sorted_by_frequency()
  idx = {}
  for i, ch of chars
    idx[ch] = i
  idx
get_character_pinyin_frequency_index = () ->
  chars = get_frequency_characters_and_pinyin()
  res = {}
  idx = 0
  for row in chars
    key = row[0] + (row[1] or "")
    if not res[key]
      res[key] = idx
      idx++
  res
update_character_reading_count = () ->
  cnt = {}
  rows = []
  chars = get_all_characters()
  cp = get_frequency_characters_and_pinyin()
  for a in chars
    for b in cp when a[0] is b[0]
      key = a[0] + b[1]
      cnt[key] = if cnt[key]? then cnt[key] + 1 else 0
  for key of cnt when cnt[key]
    rows.push [key[0], key.slice(1), cnt[key]]
  rows.sort((a, b) -> b[2] - a[2])
  write_csv_file("data/characters-pinyin-count.csv", rows)
sort_by_character = (idx) ->
  (a, b) ->
    ia = idx[a]
    ib = idx[b]
    if ia == undefined and ib == undefined then (a.length - b.length) || a.localeCompare(b)
    else if ia == undefined then 1
    else if ib == undefined then -1
    else ia - ib
sort_by_index_key = (idx, key) ->
  (a, b) -> sort_by_character(idx)(a[key], b[key])
sort_by_character_frequency = (freq_idx, key, data) ->
  data.sort(sort_by_index_key(freq_idx, key))
write_csv_file = (file, data) ->
  csv = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile(file, csv, on_error)
traditional_to_simplified = (txt) -> hanzi_tools.simplify txt
mark_to_number = (txt) ->
  txt.split(" ").map((d) -> pinyin_split2(d).map(pinyin_utils.markToNumber).join("")).join(" ")
find_multiple_word_matches = (txt, lookup_idx, trans_idx, split_fn) ->
  dict_lookup = dictionary_index_word_f(lookup_idx)
  res = []
  for token in txt.split(" ")
    syls = split_fn(token)
    max_len = 5
    candidates = for i in [0...syls.length]
      for j in [(i + 1)...Math.min(i + max_len, syls.length) + 1]
        syls.slice(i, j).join("")
    i = 0
    while i < candidates.length
      found = false
      rev = candidates[i].slice().reverse()
      for candidate in rev when dict_lookup(candidate)
        res.push (dict_lookup(candidate).map((d) -> d[trans_idx]).join("/"))
        i += rev.indexOf(candidate) + 1
        found = true
        break
      unless found
        res.push candidates[i][0]
        i++
  res.join " "
dictionary_index_word_f = (lookup_idx) ->
  dict = {}
  for row in read_csv_file("data/cedict.csv")
    object_array_add(dict, row[lookup_idx], row)
  (word) -> dict[word]
pinyin_to_hanzi = (txt) ->
  txt = txt.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches(txt, 1, 0, pinyin_split2)
hanzi_to_pinyin = (txt) ->
  txt = txt.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches(txt, 0, 1, split_chars)
grade_text = (txt) ->
  chs = unique(txt.match(hanzi_regexp))
  freq_idx = get_character_frequency_index()
  total = Object.keys(freq_idx).length
  freqs = chs.map((ch) -> freq_idx[ch] or total).sort((a, b) -> a - b)
  score = chs.length / total + median(freqs.splice(-10)) / total
  Math.max 1, Math.round(10 * score)
grade_text_files = (paths) ->
  for file in paths
    console.log grade_text(read_text_file(file)) + " " + path.basename(file)

add_translations_and_pinyin = (input_file, lookup_index, output_file) ->
  dict_lookup = dictionary_index_word_f 0
  rows = read_csv_file(input_file)
  new_rows = rows.map (row) ->
    word = row[lookup_index]
    entries = dict_lookup(word)
    row.concat(if entries and entries.length > 0 then [entries[0][1], entries[0][2]] else ["", ""])
  write_csv_file(output_file, new_rows)

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[2] = a[2].split "/"
    a

run = () ->
  add_translations_and_pinyin 0, 0, 1
  #update_character_reading_count()
module.exports =
  read_text_file: read_text_file
  get_all_characters_with_pinyin: get_all_characters_with_pinyin
  replace_placeholders: replace_placeholders
  object_array_add: object_array_add
  update_dictionary: ->
    wd = read_csv_file("data/cedict.csv")
    wd = dictionary_cedict_to_json wd
    cd = read_text_file("data/characters-svg.json")
    sc = coffee.compile(read_text_file("src/dictionary.coffee"), {bare: true}).trim()
    sc = replace_placeholders(sc, {word_data: wd, character_data: cd})
    fnt = read_text_file("src/NotoSansSC-Light.ttf.base64")
    html = replace_placeholders(read_text_file("src/hanyu-dictionary-template.html"), {font: fnt, script: sc})
    fs.writeFileSync("compiled/hanyu-dictionary.html", html)
  traditional_to_simplified: traditional_to_simplified
  pinyin_to_hanzi: pinyin_to_hanzi
  hanzi_to_pinyin: hanzi_to_pinyin
  mark_to_number: mark_to_number
  grade_text: grade_text
  grade_text_files: grade_text_files
  run: run
