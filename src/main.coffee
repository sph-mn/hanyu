csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
coffee = require "coffeescript"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
html_parser = require "node-html-parser"
http =  require "https"
node_path = require "path"
pinyin_split = require "pinyin-split"
pinyin_utils = require "pinyin-utils"
{DOMParser, XMLSerializer} = require "xmldom"
#scraper = require "table-scraper"
read_text_file = (a) -> fs.readFileSync a, "utf8"
read_csv_file = (path, delimiter) -> csv_parse.parse read_text_file(path), {delimiter: delimiter || " ", relax_column_count: true}
replace_placeholders = (text, mapping) -> text.replace /__(.*?)__/g, (_, k) -> mapping[k] or ""
array_from_newline_file = (path) -> read_text_file(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a
delete_duplicates = (a) -> [...new Set(a)]
split_chars = (a) -> [...a]
random_integer = (min, max) -> Math.floor(Math.random() * (max - min + 1)) + min
random_element = (a) -> a[random_integer 0, a.length - 1]
n_times = (n, f) -> [...Array(n).keys()].map f
remove_non_chinese_characters = (a) -> a.replace /[^\p{Script=Han}]/ug, ""
traditional_to_simplified = (a) -> hanzi_tools.simplify a
pinyin_split2 = (a) -> a.replace(/[0-5]/g, (a) -> a + " ").trim().split " "
median = (a) -> a.slice().sort((a, b) -> a - b)[Math.floor(a.length / 2)]
sum = (a) -> a.reduce ((a, b) -> a + b), 0
mean = (a) -> sum(a) / a.length
object_array_add = (object, key, value) -> if object[key] then object[key].push value else object[key] = [value]
object_array_add_unique = (object, key, value) ->
  if object[key] then object[key].push value unless object[key].includes value
  else object[key] = [value]
array_intersection = (a, b) -> a.filter (a) -> b.includes(a)

write_csv_file = (path, data) ->
  csv = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile path, csv, on_error

delete_duplicates_stable = (a) ->
  result = []
  existing = {}
  a.forEach (a) ->
    unless existing[a]
      existing[a] = true
      result.push a
  result

delete_duplicates_stable_with_key = (a, key) ->
  result = []
  existing = {}
  a.forEach (a) ->
    unless existing[a[key]]
      existing[a[key]] = true
      result.push a
  result

lcg = (seed) ->
  m = 2 ** 31
  a = 1103515245
  c = 12345
  state = seed
  ->
    state = (a * state + c) % m
    state / m

array_shuffle = (a) ->
  rand = lcg(23465700980)
  n = a.length
  while n > 0
    i = Math.floor rand() * n
    n -= 1
    [a[n], a[i]] = [a[i], a[n]]
  a

array_deduplicate_key = (a, get_key) ->
  existing = {}
  a.filter (a) ->
    key = get_key a
    if existing[key] then false
    else
      existing[key] = true
      true
# https://en.wiktionary.org/wiki/Appendix:Unicode
hanzi_unicode_ranges = [
  ["30A0", "30FF"]  # katakana used for some components
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

unicode_ranges_pattern = (a, is_reject) -> "[" + (if is_reject then "^" else "") + a.map((a) -> a.map((b) -> "\\u{#{b}}").join("-")).join("") + "]"
unicode_ranges_regexp = (a, is_reject) -> new RegExp unicode_ranges_pattern(a, is_reject), "gu"
hanzi_regexp = unicode_ranges_regexp hanzi_unicode_ranges
non_hanzi_regexp = unicode_ranges_regexp hanzi_unicode_ranges, true
hanzi_and_idc_regexp = unicode_ranges_regexp hanzi_unicode_ranges.concat([["2FF0", "2FFF"]])
non_pinyin_regexp = /[^a-z0-5]/g

get_word_frequency_index = () ->
  # -> {"#{word}#{pinyin}": integer}
  frequency = array_from_newline_file "data/words-by-frequency.txt"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_word_frequency_index_with_pinyin = () ->
  # -> {"#{word}#{pinyin}": integer}
  frequency = array_from_newline_file "data/words-by-frequency-with-pinyin.csv"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_all_standard_characters = () -> read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (a) -> a[0]
get_all_standard_characters_with_pinyin = () ->
  a = read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (a) -> [a[0], a[1].split(",")[0]]
  b = read_csv_file("data/additional-characters.csv").filter((a) -> !character_exclusions.includes(a[0])).map (a) -> [a[0], a[1].split(",")[0]]
  a.concat b
get_all_characters = () -> read_csv_file("data/characters-strokes-decomposition.csv").map (a) -> a[0]
display_all_characters = () -> console.log get_all_characters().join("")

get_all_characters_with_pinyin = () ->
  result = []
  a = read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  b = read_csv_file "data/additional-characters.csv"
  a = b.concat a
  a.forEach (b) ->
    pinyin = b[1].split(", ")[0]
    result.push [b[0] + pinyin, b[0], pinyin]
  data = delete_duplicates_stable_with_key(result, 0).map (a) -> [a[1], a[2].replace("u:", "ü")]
  char_index = split_chars read_text_file("data/characters-by-frequency.txt").trim()
  data.sort (a, b) ->
    ia = char_index.indexOf a[0]
    ib = char_index.indexOf b[0]
    (if ia is -1 then Infinity else ia) - (if ib is -1 then Infinity else ib)

get_character_by_reading_index = () ->
  chars = get_all_characters_with_pinyin()
  result = {}
  chars.forEach (a) -> object_array_add result, a[1], a[0]
  result

get_frequency_characters_and_pinyin = () ->
  # with duplicates. use case: count character reading frequency
  result = []
  a = read_csv_file "data/words-by-frequency-with-pinyin.csv"
  a.forEach (a) ->
    chars = split_chars a[0]
    pinyin = pinyin_split2 a[1]
    chars.forEach (a, i) -> result.push [a, pinyin[i]]
  result

get_all_characters_sorted_by_frequency = () ->
  delete_duplicates_stable get_all_characters_with_pinyin().map (a) -> split_chars(a[0])[0]

get_character_frequency_index = () ->
  # -> {character: integer}
  chars = get_all_characters_sorted_by_frequency()
  frequency_index = {}
  chars.forEach (a, i) -> frequency_index[a] = i
  frequency_index

get_character_pinyin_frequency_index = () ->
  # -> {character + pinyin: integer}
  chars = get_frequency_characters_and_pinyin()
  result = {}
  index = 0
  chars.forEach (a) ->
    key = a[0] + (a[1] || "")
    unless result[key]
      result[key] = index
      index += 1
  result

update_character_reading_count = () ->
  # counts how common different readings are for characters
  index = {}
  rows = []
  chars = get_all_characters()
  chars_and_pinyin = get_frequency_characters_and_pinyin()
  chars.forEach (a) ->
    chars_and_pinyin.forEach (b) ->
      if a[0] is b[0]
        key = a[0] + b[1]
        if index[key] != undefined then index[key] += 1
        else index[key] = 0
  Object.keys(index).forEach (a) ->
    count = index[a]
    if count then rows.push [a[0], a.slice(1), count]
  rows = rows.sort (a, b) -> b[2] - a[2]
  write_csv_file "data/characters-pinyin-count.csv", rows

sort_by_index_and_character_f = (index, character_key) ->
  # {character: integer, ...}, any -> function(a, b)
  f = sort_by_character_f index
  (a, b) -> f a[character_key], b[character_key]

sort_by_character_f = (index) ->
  (a, b) ->
    ia = index[a]
    ib = index[b]
    if ia is undefined and ib is undefined
      (a.length - b.length) || a.localeCompare(b) || b.localeCompare(a)
    else if ia is undefined then 1
    else if ib is undefined then -1
    else ia - ib

sort_by_character_frequency = (frequency_index, character_key, data) ->
  data.sort sort_by_index_and_character_f frequency_index, character_key

sort_by_stroke_count = (stroke_count_index, character_key, data) ->
  data.sort sort_by_index_and_character_f stroke_count_index, character_key

sort_by_word_frequency_with_pinyin = (frequency_index, word_key, pinyin_key, data) ->
  data.sort (a, b) ->
    fa = frequency_index[a[word_key] + a[pinyin_key]]
    fb = frequency_index[b[word_key] + b[pinyin_key]]
    if fa is undefined and fb is undefined
      a[word_key].length - b[word_key].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb

sort_by_word_frequency = (frequency_index, word_key, data) ->
  data.sort (a, b) ->
    fa = frequency_index[a[word_key]]
    fb = frequency_index[b[word_key]]
    if fa is undefined and fb is undefined
      a[word_key].length - b[word_key].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[2] = a[2].split "/"
    a

update_dictionary = () ->
  word_data = read_csv_file "data/cedict.csv"
  word_data = dictionary_cedict_to_json word_data
  character_data = read_text_file "data/characters-svg.json"
  script = read_text_file "src/dictionary.coffee"
  script = coffee.compile(script, bare: true).trim()
  script = replace_placeholders script, {word_data, character_data}
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/hanyu-dictionary-template.html"
  html = replace_placeholders html, {font, script}
  fs.writeFileSync "compiled/hanyu-dictionary.html", html

clean_frequency_list = () ->
  frequency_array = array_from_newline_file "data/words-by-frequency.txt"
  frequency_array = frequency_array.filter (a) ->
    traditional_to_simplified remove_non_chinese_characters a
  frequency_array.forEach (a) -> console.log a

dictionary_index_word_f = (lookup_index) ->
  dictionary = {}
  read_csv_file("data/cedict.csv").forEach (a) -> object_array_add dictionary, a[lookup_index], a
  (a) -> dictionary[a]

dictionary_index_word_pinyin_f = () ->
  dictionary = {}
  word_index = 0
  pinyin_index = 1
  words = read_csv_file "data/cedict.csv"
  words.forEach (a) ->
    word = a[word_index]
    key = a[word_index] + a[pinyin_index]
    object_array_add dictionary, key, a
    object_array_add dictionary, word, a
  (word, pinyin) -> dictionary[word + pinyin]

mark_to_number = (a) ->
  a.split(" ").map((a) -> pinyin_split2(a).map(pinyin_utils.markToNumber).join("")).join(" ")

find_multiple_word_matches = (a, lookup_index, translation_index, split_syllables) ->
  # for each space separated element, find all longest most frequent words with the pronunciation.
  dictionary_lookup = dictionary_index_word_f lookup_index
  results = []
  a.split(" ").forEach (a) ->
    syllables = split_syllables a
    max_word_length = 5
    per_length = (i, j) -> syllables.slice(i, j).join("")
    per_syllable = (i) ->
      end = Math.min(i + max_word_length, syllables.length) + 1
      per_length i, j for j in [(i + 1)...end]
    candidates = (per_syllable i for i in [0...syllables.length])
    i = 0
    while i < candidates.length
      matches = []
      j = 0
      reversed_candidates = candidates[i].toReversed()
      while j < reversed_candidates.length
        translations = dictionary_lookup reversed_candidates[j]
        if translations
          matches.push translations.map((a) -> a[translation_index]).join "/"
          break
        j += 1
      if matches.length
        results.push matches[0]
        i += reversed_candidates.length - j
      else
        results.push candidates[i][0]
        i += 1
  results.join " "

pinyin_to_hanzi = (a) ->
  a = a.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches a, 1, 0, pinyin_split2

hanzi_to_pinyin = (a) ->
  a = a.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches a, 0, 1, split_chars

get_characters_by_pinyin_rows = ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a]]
  rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length

update_character_table_html = (data) ->
  nav_links = []
  i = 0
  make_table = (rows, name) ->
    nav_links.push """
       <a href="#" data-target="#{i}">#{name}</a>
    """
    i += 1
    rows = rows.map (a) -> "<b><b>#{a[0]}</b><b>#{a[1]}</b></b>"
    "<div class=\"#{name}\">" + rows.join("\n") + "</div>"
  content = (make_table b, a for a, b of data).join "\n"
  nav_links = nav_links.join "\n"
  [content, nav_links]

arrow_for_angle = (angle) ->
  angle = (angle + Math.PI) % (2 * Math.PI) - Math.PI
  if -Math.PI/8 <= angle < Math.PI/8 then "→"
  else if Math.PI/8 <= angle < 3*Math.PI/8 then "↗"
  else if 3*Math.PI/8 <= angle < 5*Math.PI/8 then "↑"
  else if 5*Math.PI/8 <= angle < 7*Math.PI/8 then "↖"
  else if 7*Math.PI/8 <= angle or angle < -7*Math.PI/8 then "←"
  else if -7*Math.PI/8 <= angle < -5*Math.PI/8 then "↙"
  else if -5*Math.PI/8 <= angle < -3*Math.PI/8 then "↓"
  else if -3*Math.PI/8 <= angle < -Math.PI/8 then "↘"

get_syllable_circle_arrow = do ->
  syllables = read_text_file("data/syllables.txt").trim().split(" ")
  (syllable) ->
    syllable = syllable.replace(/[0-5]$/, "")
    i = syllables.indexOf syllable
    angle = 2 * Math.PI * i / syllables.length
    arrow_for_angle angle

update_character_table = ->
  prelearn = read_csv_file("/home/nonroot/chinese/1/lists/prelearn.csv").map (a) -> [a[0], a[1]]
  prelearn_groups = {}
  for a in prelearn
    object_array_add prelearn_groups, a[1], a[0]
  prelearn = []
  for a, b of prelearn_groups
    arrow = get_syllable_circle_arrow a
    prelearn.push [a + arrow, b.join("")]
  pinyin = get_characters_by_pinyin_rows()
  pinyin = ([a[0], a[1].join("")] for a in pinyin)
  pinyin_by_count = pinyin.slice().sort (a, b) -> a[1].length - b[1].length
  contained = get_characters_contained_rows()
  contained = ([a[0], a[1].join("")] for a in contained)
  character_data = {pinyin, contained, pinyin_by_count, prelearn}
  [content, nav_links] = update_character_table_html character_data
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/character-table-template.html"
  html = replace_placeholders html, {font, content, nav_links}
  fs.writeFileSync "compiled/character-table.html", html

update_characters_by_pinyin_vertical = (rows) ->
  vertical_rows = format_lines_vertically rows
  fs.writeFileSync "data/characters-by-pinyin-by-count-vertical.csv", vertical_rows.join "\n"

update_characters_by_pinyin = () ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length
  write_csv_file "data/characters-by-pinyin.csv", rows
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  write_csv_file "data/characters-by-pinyin-by-count.csv", rows
  rows = rows.filter (a) -> a[1].length < 4
  rows = rows.sort (b, a) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  write_csv_file "data/characters-by-pinyin-rare.csv", rows

sort_by_array_with_index = (a, sorting, index) ->
  a.sort (a, b) -> sorting.indexOf(a[index]) - sorting.indexOf(b[index])

index_key_value = (a, key_key, value_key) ->
  b = {}
  a.forEach (a) -> b[a[key_key]] = a[value_key]
  b

get_compositions_index = ->
  decompositions = read_csv_file "data/characters-strokes-decomposition.csv"
  decompositions = ([a, c?.split("") || []] for [a, b, c] in decompositions)
  compositions = {}
  for a in decompositions
    [char, a] = a
    for component in a
      c = compositions[component]
      if c
        unless c.includes char
          c.push char
          compositions[component] = c
      else compositions[component] = [char]
  frequency_sorter = sort_by_character_f get_character_frequency_index()
  for a, b of compositions
    compositions[a] = b.sort frequency_sorter
  compositions

get_decompositions_index = () -> index_key_value read_csv_file("data/characters-strokes-decomposition.csv"), 0, 2

get_full_decompositions = () ->
  # also include decompositions of components per entry
  decompositions_index = get_decompositions_index()
  decompose = (a) ->
    parts = decompositions_index[a]
    if parts
      parts = [...parts]
      [a].concat(parts, parts.map(decompose))
    else [a]
  Object.keys(decompositions_index).map (a) ->
    parts = decompose(a).flat(Infinity)
    [parts[0], delete_duplicates(parts.slice(1))]
    #[parts[0], parts.slice(1)]

get_full_decompositions_index = () -> index_key_value get_full_decompositions(), 0, 1

get_stroke_count_index = (a) ->
  data = read_csv_file("data/characters-strokes-decomposition.csv")
  result = {}
  result[a[0]] = parseInt a[1] for a in data
  result

get_character_reading_count_index = () ->
  result = {}
  read_csv_file("data/characters-pinyin-count.csv").forEach (a) -> result[a[0] + a[1]] = parseInt a[2]
  result

get_character_syllables_tones_count_index = () ->
  result = {}
  read_csv_file("data/syllables-tones-character-counts.csv").forEach (a) -> result[a[0]] = parseInt a[1]
  result

get_character_example_words_f = () ->
  dictionary = dictionary_index_word_pinyin_f 0, 1
  words = read_csv_file "data/words-by-frequency-with-pinyin-translation.csv"
  (char, pinyin, frequency_limit) ->
    char_word = words.find((b) -> b[0] is char)
    unless char_word
      char_word = dictionary char, pinyin
      char_word = char_word[0] if char_word
    char_words = if char_word then [char_word] else []
    char_words.concat words.filter (b, i) -> b[0].includes(char) && b[0] != char && (!frequency_limit || i < frequency_limit)

sort_standard_character_readings = () ->
  reading_count_index = get_character_reading_count_index()
  path = "data/table-of-general-standard-chinese-characters.csv"
  rows = read_csv_file(path).map (a) ->
    char = a[0]
    pinyin = a[1].split(", ").map (a) -> if a.match(/[0-5]$/) then a else a + "5"
    pinyin = pinyin.sort (a, b) -> (reading_count_index[char + b] || 0) - (reading_count_index[char + a] || 0)
    a[1] = pinyin.join ", "
    a
  write_csv_file path, rows

add_sort_field = (rows) ->
  a.push i for a, i in rows
  rows

update_pinyin_learning = () ->
  # pinyin, word_choices -> word, translation
  options =
    words_per_char: 3
    word_choices: 5
  character_frequency_index = get_character_frequency_index()
  get_character_example_words = get_character_example_words_f()
  standard_chars = read_csv_file("data/table-of-general-standard-chinese-characters.csv")
  chars = standard_chars.map (a) -> [a[0], a[1].split(", ")[0]]
  chars = sort_by_character_frequency character_frequency_index, 0, chars
  rows = for a in chars
    a = get_character_example_words(a[0], a[1])
    if 1 < a.length then a = a.slice 1, options.words_per_char + 1
    [b[1], b[0], b[2]] for b in a
  rows = rows.flat 1
  rows = array_deduplicate_key rows, (a) -> a[1]
  add_word_choices = (rows) ->
    rows.map (a) ->
      tries = 30
      alternatives = [a[1]]
      while tries && alternatives.length < options.word_choices
        alternative = random_element rows
        if a[1].length == alternative[1].length && a[0] != alternative[0] && !alternatives.includes(alternative[1])
          alternatives.push alternative[1]
        tries -= 1
      a.push array_shuffle(alternatives).join(" ")
      a
  rows = add_sort_field add_word_choices rows
  write_csv_file "data/pinyin-learning.csv", rows

get_char_pinyin = do ->
  all_chars_and_pinyin = get_all_characters_with_pinyin()
  char_pinyin_index = index_key_value all_chars_and_pinyin, 0, 1
  dictionary = dictionary_index_word_f 0
  (a) ->
    b = dictionary a
    return b[0][1] if b && b.length
    b = char_pinyin_index[a]
    return b if b

get_char_decompositions = do ->
  decompositions = get_full_decompositions_index()
  strokes = get_stroke_count_index()
  (a) ->
    b = decompositions[a]
    return [] unless b
    b = b.filter((a) -> !strokes[a] || strokes[a] > 1)
    b.map((a) -> [a, get_char_pinyin(a)]).filter (a) -> a[1]

characters_add_learning_data = (rows) -> # [[character, pinyin], ...] -> [array, ...]
  reading_count_index = get_character_reading_count_index()
  character_by_reading_index = get_character_by_reading_index()
  get_character_example_words = get_character_example_words_f()
  rows = array_deduplicate_key(rows, (a) -> a[0])
  syllables = delete_duplicates rows.map((a) -> a[1].split(", ")).flat()
  add_same_reading_characters = (rows) ->
    max_same_reading_characters = 24
    rows.map (a) ->
      b = (character_by_reading_index[a[1]] or []).slice(0, max_same_reading_characters)
      b = b.filter (b) -> a[0] != b
      a.push b.join ""
      a
  add_syllable_arrows = (rows) ->
    rows.map (a) ->
      arrow = get_syllable_circle_arrow a[1]
      a.push arrow
      a
  add_contained_characters = (rows) ->
    rows.map (a) ->
      b = get_char_decompositions a[0]
      c = b.map((c) -> c.join(" ")).join(", ")
      a.push c
      a
  add_example_words = (rows) ->
    rows.map (a) ->
      words = get_character_example_words(a[0], a[1])
      a.push(words.slice(1, 5).map((b) -> b[0]).join(" "))
      a.push(words.slice(0, 5).map((b) -> b.join(" ")).join("\n"))
      a
  rows = add_contained_characters rows
  rows = add_same_reading_characters(rows)
  rows = add_sort_field rows
  rows = add_syllable_arrows rows
  rows = add_example_words rows
  rows

fix_dependency_order = (items, char_key) ->
  di = get_full_decompositions_index()
  pm = {}
  for i, a of items
    pm[a[char_key]] = i
  i = 0
  while i < items.length
    c = items[i][char_key]
    deps = di[c] or []
    for d in deps
      j = pm[d]
      if j? and j > i
        dep = items.splice(j, 1)[0]
        items.splice(i, 0, dep)
        for k in [Math.min(i, j)..Math.max(i, j)]
          pm[items[k][char_key]] = k
        # stay at same i to recheck moved-in deps
        i -= 1
        break
    i += 1
  items

# test examples: 刀 < 那
sort_by_frequency_f = (char_key) ->
  fi = get_character_frequency_index()
  (a, b) -> fi[a[char_key]] - fi[b[char_key]]

sort_by_frequency = (data, char_key) -> data.sort sort_by_frequency_f char_key

sort_by_frequency_and_dependency = (data, char_key) ->
  data = data.sort sort_by_frequency_f char_key
  data = fix_dependency_order data, char_key
  data

update_characters_learning = ->
  rows = get_all_standard_characters_with_pinyin()
  rows = sort_by_frequency_and_dependency rows, 0
  rows = characters_add_learning_data rows
  write_csv_file "data/characters-learning.csv", rows
  rows = ([i + 1, a[0], a[1], a[5], a[3]] for a, i in rows)
  write_csv_file "data/characters-learning-reduced.csv", rows

update_syllables_character_count = () ->
  # number of characters with the same reading
  chars = read_csv_file("data/characters-by-pinyin.csv").map (a) -> [a[0], a[1].length]
  chars_without_tones = chars.map (a) -> [a[0].replace(/[0-5]/g, ""), a[1]]
  get_data = (chars) ->
    counts = {}
    chars.forEach (a) ->
      if counts[a[0]] then counts[a[0]] += a[1]
      else counts[a[0]] = a[1]
    chars = chars.map (a) -> a[0]
    chars = delete_duplicates_stable chars
    chars.map((a) -> [a, counts[a]]).sort (a, b) -> b[1] - a[1]
  write_csv_file "data/syllables-tones-character-counts.csv", get_data(chars)
  write_csv_file "data/syllables-character-counts.csv", get_data(chars_without_tones)

grade_text_files = (paths) ->
  paths.forEach (a) -> console.log grade_text(read_text_file(a)) + " " + node_path.basename(a)

grade_text = (a) ->
  chars = delete_duplicates a.match hanzi_regexp
  frequency_index = get_character_frequency_index()
  all_chars_count = Object.keys(frequency_index).length
  frequencies = chars.map((a) -> frequency_index[a] || all_chars_count).sort((a, b) -> a - b)
  count_score = chars.length / all_chars_count
  rarity_score = median(frequencies.splice(-10)) / all_chars_count
  Math.max 1, Math.round(10 * (count_score + rarity_score))

character_exclusions = "一亅㇀ 乚丨丿丶㇒㇏㇇乛㇓乀㇍㇂㇊丆二⺊卜十冂ユコ㇄㇅㇎㇌乜㇋厸丫䶹八凵儿囗丁乁"

get_characters_contained_rows = ->
  compositions = get_compositions_index()
  rows = []
  for char of compositions when char.match(hanzi_regexp) and not character_exclusions.includes(char)
    rows.push [char, compositions[char]]
  rows.sort (a, b) -> a[1].length - b[1].length

update_characters_contained = ->
  rows = get_characters_contained_rows()
  lines = (a[0] + " " + a[1] for a in rows).join "\n"
  #fs.writeFileSync "data/characters-contained.txt", lines
  rows = (a[0] + " " + get_char_decompositions(a[0]).join("") for a in rows)
  fs.writeFileSync "data/characters-containing.txt", rows.join "\n"

update_characters_data = ->
  graphics_data = JSON.parse read_text_file "data/characters-svg-animcjk-simple.json"
  character_data = read_csv_file "data/characters-strokes-decomposition.csv"
  compositions_index = get_compositions_index()
  dictionary_lookup = dictionary_index_word_f 0
  character_frequency_index = get_character_frequency_index()
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

get_common_words_per_character = (max_words_per_char, max_frequency) ->
  character_frequency_index = get_character_frequency_index()
  get_character_example_words = get_character_example_words_f()
  standard_chars = read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  chars = standard_chars.map (a) -> [a[0], a[1].split(", ")[0]]
  chars = sort_by_character_frequency character_frequency_index, 0, chars
  rows = for a in chars
    a = get_character_example_words a[0], a[1], max_frequency
    if 1 < a.length then a = a.slice 0, max_words_per_char
    a
  rows = rows.flat 1
  rows = array_deduplicate_key rows, (a) -> a[1]

get_characters_contained_rows = ->
  compositions = get_compositions_index()
  rows = []
  for char of compositions when char.match(hanzi_regexp) and not character_exclusions.includes(char)
    rows.push [char, compositions[char]]
  rows.sort (a, b) -> a[1].length - b[1].length


update_characters_contained = ->
  rows = get_characters_contained_rows()
  lines = (a[0] + " " + a[1] for a in rows).join "\n"
  fs.writeFileSync "data/characters-contained.txt", lines
  rows = (a[0] + " " + get_char_decompositions(a[0]).join("") for a in rows)
  fs.writeFileSync "data/characters-containing.txt", rows.join "\n"

is_file = (path) -> fs.statSync(path).isFile()
strip_extensions = (filename) -> filename.replace /\.[^.]+$/, ''

update_lists = (paths) ->
  nav_links = []
  paths = (a for a in paths when is_file a)
  content = for path, i in paths
    rows = read_csv_file path
    parts = for row in rows
      [head, tail...] = row
      tail = tail.join " "
      """
      <b><b>#{head}</b><b>#{tail}</b></b>
      """
    label = strip_extensions node_path.basename path
    nav_links.push """
       <a href="#" data-target="#{i}">#{label}</a>
    """
    "<div>" + parts.join("\n") + "</div>"
  content = content.join "\n"
  nav_links = nav_links.join "\n"
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/lists-template.html"
  html = replace_placeholders html, {font, content, nav_links}
  fs.writeFileSync "tmp/lists.html", html

iconv = require "iconv-lite"

update_character_frequency = ->
  buf = fs.readFileSync "/tmp/SUBTLEX-CH-CHR"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  chars = []
  for line in lines when line.trim() and not line.startsWith("Character") and not line.startsWith("Total")
    parts = line.trim().split /\s+/
    chr = parts[0]
    if chr.length is 1
      chars.push chr
  fs.writeFileSync "data/characters-by-frequency.txt", chars.join ""

update_word_frequency = ->
  buf = fs.readFileSync "/tmp/SUBTLEX-CH-WF"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  words = []
  for line in lines when line.trim() and not line.startsWith("Word")
    parts = line.trim().split /\s+/
    word = parts[0]
    continue unless word.match /[\u4e00-\u9fff]/  # skip PUA and non-CJK
    words.push word
  fs.writeFileSync "data/words-by-frequency.txt", words.join "\n"

cedict_glossary = (a) ->
  filter_regexp = [
    /^abbr\. for /
    /^also pr\. /
    /.ancient/
    /ancient./
    /[^()a-z0-9?':; ,.-]/
    /.bird species./
    /\(budd.+/
    /.buddhism/
    /buddhism./
    /.buddhist/
    /buddhist./
    /^cl:/
    /\(classical/
    /\(\d+/
    /\d+-\d+/
    /\(in classical/
    /.japan/
    /japan./
    /japanese/
    /.korea/
    /korea./
    /\(old\)/
    /\(onom/
    /.sanskrit/
    /sanskrit./
    /^see also [^a-zA-Z]/
    /^see [^a-zA-Z]/
    /^surname /
    /.taiwan/
    /taiwan./
    /^taiwanese \. /
    /^taiwan pr./
    /\(tw\)/
    /^\(used in /
    /^used in /
    /variant of /
    /\(loanword/
    /\(neologism/
    /\(archaic/
    /\(dialect/
    /\(vulgar/
  ]
  a = a.split("/").map (a) -> a.toLowerCase().split(";")
  a = a.flat().map (a) -> a.trim()
  a.filter (a) -> !filter_regexp.some((b) -> a.match b)

cedict_merge_definitions = (a) ->
  table = {}
  a.forEach (a, index) ->
    key = a[0] + "#" + a[1]
    if table[key]
      table[key][1][2] = table[key][1][2].concat a[2]
    else table[key] = [index, a]
  Object.values(table).sort((a, b) -> a[0] - b[0]).map((a) -> a[1])

cedict_additions = (a) ->
  # manual additions to the dictionary
  a.push ["你", "ni3", ["you"]]
  a

cedict_filter_only = () ->
  # retains the original cedict format.
  cedict = read_text_file "data/foreign/cedict_ts.u8"
  frequency_array = array_from_newline_file "data/words-by-frequency.txt"
  frequency = {}
  frequency_array.forEach (a, i) -> frequency[a] = i
  rows = cedict.split "\n"
  data = rows.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word_traditional = parsed[1]
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) ->
      pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3").replace("45", "4").replace("25", "2")
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary(parsed[4]).join("/")
    line = [word_traditional, word, "[#{pinyin}]", "/#{glossary}/"].join(" ")
    frequency = frequency[word] || (word.length + frequency_array.length)
    [frequency, line, word, word_traditional] if glossary.length
  data = data.filter (a) -> a
  data = data.sort (a, b) -> a[0] - b[0]
  cedict_filtered_lines = data.map (a) -> a[1]
  cedict_filtered = cedict_filtered_lines.join "\n"
  fs.writeFile "data/cedict-filtered.u8", cedict_filtered, on_error
  index_lines = []
  index_lines_traditional = []
  character_offset = 0
  data.forEach (a) ->
    word = a[2]
    word_traditional = a[3]
    character_offset = cedict_filtered.indexOf("#{word_traditional} #{word} ", character_offset)
    index_lines.push "#{word},#{character_offset}"
    index_lines_traditional.push "#{word_traditional},#{character_offset}"
  index_lines = index_lines.concat index_lines_traditional
  fs.writeFile "data/cedict-filtered.idx", index_lines.join("\n"), on_error

update_cedict_csv = () ->
  cedict = read_text_file "data/cedict-filtered.u8"
  frequency_index = get_word_frequency_index_with_pinyin()
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin_split2(pinyin).map (a) ->
      pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3").replace("45", "4").replace("25", "2")
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = cedict_additions data
  data = cedict_merge_definitions data
  data.forEach (a) -> a[2] = a[2].join "; "
  data = sort_by_word_frequency_with_pinyin frequency_index, 0, 1, data
  data = data.filter (a, index) -> index < 3000 || a[0].length < 3
  test = () ->
    example1 = data.findIndex((a) => a[0] is "猫")
    example2 = data.findIndex((a) => a[0] is "熊猫")
    throw "test failed" unless example1 < example2
  #test()
  write_csv_file "data/cedict.csv", data

update_word_frequency_pinyin = ->
  words = array_from_newline_file "data/words-by-frequency.txt"
  dict = dictionary_index_word_f 0
  result = for word in words
    entry = dict word
    continue unless entry
    pinyin = entry[0][1]
    [word, pinyin]
  write_csv_file "data/words-by-frequency-with-pinyin.csv", result

get_practice_words = (num_attempts, max_freq) ->
  # get a list of the most frequent words where each character ideally appears
  #   only once and no word appears twice.
  word_frequency_index = get_word_frequency_index()
  characters = get_all_standard_characters()
  rows = read_csv_file "data/words-by-frequency-with-pinyin.csv"
  rows = rows.filter (a)->
    chars = split_chars a[0]
    chars.length > 1 && chars[0] != chars[1]
  candidate_words = {}
  for [w, p] in rows
    freq = word_frequency_index[w] || max_freq + 1
    continue if freq > max_freq
    for ch in split_chars w
      continue unless ch in characters
      (candidate_words[ch] ?= []).push [w,p,freq]
  characters = characters.filter (ch)-> candidate_words[ch]?
  for ch in characters
    candidate_words[ch].sort (a,b)-> a[2] - b[2]
  best_total_cost = Infinity
  best_assign = null
  for attempt in [0...num_attempts]
    order = array_shuffle characters.slice()
    counts = {}
    used_words = {}
    assign = {}
    run_cost = 0
    for ch in order
      opts = candidate_words[ch]
      best_score = Infinity
      chosen = null
      for [w,p,freq] in opts when not used_words[w]
        score = sum(counts[c] || 0 for c in w) + freq
        if score < best_score or (score is best_score and Math.random() < 0.5)
          best_score = score
          chosen = [w,p,freq]
      continue unless chosen?
      assign[ch] = chosen
      used_words[chosen[0]] = true
      counts[c] = (counts[c] || 0) + 1 for c in chosen[0]
      run_cost += best_score
    if run_cost < best_total_cost
      best_total_cost = run_cost
      best_assign = assign
  words = ([x[0],x[1]] for ch,x of best_assign)
  sort_by_word_frequency word_frequency_index, 0, words

update_practice_words = ->
  rows = get_practice_words 1000, Infinity
  write_csv_file "data/practice-words.csv", rows

run = ->
  #update_word_frequency_pinyin()
  #console.log get_all_characters_with_pinyin()
  #update_lists()
  #update_character_frequency()
  #update_characters_by_pinyin()
  update_practice_words()
  #update_character_table()
  #update_cedict_csv()
  #cedict_filter_only()
  #add_translations_and_pinyin 0, 0, 1
  #update_character_reading_count()

module.exports = {
  read_text_file
  get_characters_by_pinyin_rows
  clean_frequency_list
  replace_placeholders
  object_array_add
  get_all_characters_with_pinyin
  update_dictionary
  update_characters_data
  traditional_to_simplified
  pinyin_to_hanzi
  hanzi_to_pinyin
  mark_to_number
  update_characters_by_pinyin
  update_characters_learning
  update_pinyin_learning
  grade_text
  grade_text_files
  run
  update_lists
}
