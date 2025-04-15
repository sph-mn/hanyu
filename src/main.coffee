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

get_frequency_index = () ->
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
  #a = read_csv_file "data/words-by-frequency-with-pinyin.csv"
  #a.forEach (a) ->
  #  chars = split_chars a[0]
  #  pinyin = pinyin_split2 a[1]
  #  chars.forEach (a, i) -> result.push [a + pinyin[i], a, pinyin[i]]
  a = read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  b = read_csv_file "data/additional-characters.csv"
  a = b.concat a
  a.forEach (b) ->
    pinyin = b[1].split(", ")[0]
    result.push [b[0] + pinyin, b[0], pinyin]
  delete_duplicates_stable_with_key(result, 0).map (a) -> [a[1], a[2].replace("u:", "ü")]

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

sort_by_word_frequency = (frequency_index, word_key, pinyin_key, data) ->
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
  frequency_array = array_from_newline_file "data/words-by-frequency.csv"
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

update_character_table_html = (pinyin, contained, pinyin_by_count) ->
  make_table = (rows, name) ->
    rows = rows.map (a) -> "<b><b>#{a[0]}</b><b>#{a[1]}</b></b>"
    "<div class=\"#{name}\">" + rows.join("\n") + "</div>"
  [
    make_table(pinyin, "pinyin")
    make_table(pinyin_by_count, "pinyin_by_count")
    make_table(contained, "contained")
  ].join "\n"

update_character_table = ->
  pinyin = get_characters_by_pinyin_rows()
  pinyin = ([a[0], a[1].join("")] for a in pinyin)
  pinyin_by_count = pinyin.slice().sort (a, b) -> a[1].length - b[1].length
  contained = get_characters_contained_rows()
  contained = ([a[0], a[1].join("")] for a in contained)
  content = update_character_table_html pinyin, contained, pinyin_by_count
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/character-table-template.html"
  html = replace_placeholders html, {font, content}
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
      b = array_shuffle(character_by_reading_index[a[1]] or [])
      b = b.filter((b) -> a[0] != b)
      a.push(b.slice(0, max_same_reading_characters).join(""))
      a
  rows = add_same_reading_characters(rows)
  add_contained_characters = (rows) ->
    rows.map (a) ->
      b = get_char_decompositions a[0]
      c = b.map((c) -> c.join(" ")).join(", ")
      a.push c
      a
  rows = add_contained_characters rows
  rows = add_sort_field rows
  add_example_words = (rows) ->
    rows.map (a) ->
      words = get_character_example_words(a[0], a[1])
      a.push(words.slice(1, 5).map((b) -> b[0]).join(" "))
      a.push(words.slice(0, 5).map((b) -> b.join(" ")).join("\n"))
      a
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

update_character_table_html = (pinyin, contained, pinyin_by_count) ->
  make_table = (rows, name) ->
    rows = rows.map (a) -> "<b><b>#{a[0]}</b><b>#{a[1]}</b></b>"
    "<div class=\"#{name}\">" + rows.join("\n") + "</div>"
  [
    make_table(pinyin, "pinyin")
    make_table(pinyin_by_count, "pinyin_by_count")
    make_table(contained, "contained")
  ].join "\n"

get_characters_contained_rows = ->
  compositions = get_compositions_index()
  rows = []
  for char of compositions when char.match(hanzi_regexp) and not character_exclusions.includes(char)
    rows.push [char, compositions[char]]
  rows.sort (a, b) -> a[1].length - b[1].length

update_character_table = ->
  pinyin = get_characters_by_pinyin_rows()
  pinyin = ([a[0], a[1].join("")] for a in pinyin)
  pinyin_by_count = pinyin.slice().sort (a, b) -> a[1].length - b[1].length
  contained = get_characters_contained_rows()
  contained = ([a[0], a[1].join("")] for a in contained)
  content = update_character_table_html pinyin, contained, pinyin_by_count
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/character-table-template.html"
  html = replace_placeholders html, {font, content}
  fs.writeFileSync "compiled/character-table.html", html

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

run = () ->
  update_lists()
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
