csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
coffee = require "coffeescript"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
html_parser = require "node-html-parser"
http =  require "https"
path = require "path"
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
  frequency_array = array_from_newline_file "data/words-by-frequency.csv"
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
  b = read_csv_file("data/additional-characters.csv").map (a) -> [a[0], a[1].split(",")[0]]
  a.concat b
get_all_characters = () -> read_csv_file("data/characters-strokes-decomposition.csv").map (a) -> a[0]
display_all_characters = () -> console.log get_all_characters().join("")

get_all_characters_with_pinyin = () ->
  # sorted by frequency
  result = []
  a = read_csv_file "data/words-by-frequency-with-pinyin.csv"
  a.forEach (a) ->
    chars = split_chars a[0]
    pinyin = pinyin_split2 a[1]
    chars.forEach (a, i) -> result.push [a + pinyin[i], a, pinyin[i]]
  a = read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  b = read_csv_file("data/additional-characters.csv")
  a = b.concat a
  a.forEach (a) -> a[1].split(", ").forEach (pinyin) -> result.push [a[0] + pinyin, a[0], pinyin]
  delete_duplicates_stable_with_key(result, 0).map (a) -> [a[1], a[2].replace("u:", "ü")]

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
  (a, b) ->
    ca = a[character_key]
    cb = b[character_key]
    ia = index[ca]
    ib = index[cb]
    if ia is undefined and ib is undefined
      (ca.length - cb.length) || ca.localeCompare(cb) || cb.localeCompare(ca)
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

update_cedict_csv = () ->
  cedict = read_text_file "data/foreign/cedict_ts.u8"
  frequency_index = get_frequency_index()
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) ->
      pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3").replace("45", "4").replace("25", "2")
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = cedict_additions data
  data = cedict_merge_definitions data
  data.forEach (a) -> a[2] = a[2].join "; "
  data = sort_by_word_frequency frequency_index, 0, 1, data
  data = data.filter (a, index) -> index < 3000 || a[0].length < 3
  test = () ->
    example1 = data.findIndex((a) => a[0] is "猫")
    example2 = data.findIndex((a) => a[0] is "熊猫")
    throw "test failed" unless example1 < example2
  #test()
  write_csv_file "data/cedict.csv", data

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

update_hsk = () ->
  files = fs.readdirSync "data/hsk"
  data = files.map (a) -> read_csv_file("data/hsk/#{a}", "\t")
  data = data.flat(1).map (a) ->
    pinyin = pinyin_split2(a[2]).map(pinyin_utils.markToNumber).join("").toLowerCase()
    [a[1], pinyin]
  write_csv_file "data/hsk.csv", data

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

update_frequency_pinyin = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  frequency = array_from_newline_file "data/words-by-frequency.csv"
  hsk = read_csv_file "data/hsk.csv"
  hsk_index = {}
  hsk.forEach (a) ->
    return if hsk_index[a[0]]
    pinyin = a[1]
    pinyin += "5" unless /[0-5]$/.test pinyin
    hsk_index[a[0]] = pinyin
  frequency_pinyin = frequency.map (a) -> [a, (hsk_index[a] || "")]
  rows = frequency_pinyin.map (a) ->
    translation = dictionary_lookup a[0], a[1]
    return [] unless translation
    [a[0], translation[0][1], translation[0][2]]
  rows = rows.filter (a) -> 3 is a.length
  write_csv_file "data/words-by-frequency-with-pinyin-translation.csv", rows
  rows = rows.map (a) -> [a[0], a[1]]
  write_csv_file "data/words-by-frequency-with-pinyin.csv", rows

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

dsv_add_translations_with_pinyin = (word_index, pinyin_index) ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  rows = read_csv_file(0).map (a) ->
    translations = dictionary_lookup a[word_index], a[pinyin_index]
    return a unless translations
    a.concat [translations[0][2]]
  console.log csv_stringify.stringify(rows, {delimiter: " "}, on_error).trim()

dsv_add_translations = (word_index) ->
  dictionary_lookup = dictionary_index_word_f()
  rows = read_csv_file(0).map (a) ->
    translations = dictionary_lookup a[word_index]
    return a unless translations
    a.concat [translations[0][1], translations[0][2]]
  write_csv_file 0, rows

dsv_mark_to_number = (pinyin_index) ->
  rows = read_csv_file(0).map (a) ->
    a[pinyin_index] = mark_to_number a[pinyin_index]
    a
  write_csv_file 0, rows

update_hsk_pinyin_translations = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  rows = read_csv_file("data/hsk.csv").map (a) ->
    translations = dictionary_lookup a[0], a[1]
    return a unless translations
    a.concat [translations[0][2]]
  frequency_index = get_character_frequency_index()
  rows = rows.sort (a, b) ->
    chars_a = split_chars a[0]
    chars_b = split_chars b[0]
    max_a = Math.max.apply Math, chars_a.map (char) -> frequency_index[char]
    max_b = Math.max.apply Math, chars_b.map (char) -> frequency_index[char]
    max_a - max_b
  write_csv_file "data/hsk-pinyin-translation.csv", rows

pinyin_to_hanzi = (a) ->
  a = a.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches a, 1, 0, pinyin_split2

hanzi_to_pinyin = (a) ->
  a = a.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches a, 0, 1, split_chars

dsv_add_example_words = () ->
  dictionary = dictionary_index_word_pinyin_f 0, 1
  words = read_csv_file "data/words-by-frequency-with-pinyin-translation.csv"
  rows = read_csv_file(0).map (a) ->
    char_words = words.filter((b) -> b[0].includes a[0])
    unless char_words.length
      char_words = dictionary(a[0], a[1]) || []
    a.push char_words.slice(0, 5).map((b) -> b.join(" ")).join("\n")
    a
  write_csv_file 0, rows

update_characters_by_pinyin_learning = ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add(by_pinyin, a[1], a[0])
  rows = []
  for pinyin, chars_array of by_pinyin
    for character in chars_array
      rows.push [character, pinyin, chars_array.length]
  rows = rows.sort (a, b) -> (b[2] - a[2]) || a[1].localeCompare(b[1]) or a[0].localeCompare(b[0])
  rows = characters_add_learning_data rows
  write_csv_file("data/characters-by-pinyin-learning.csv", rows)
  rows = (a for a in rows.reverse() when a[2] < 3)
  write_csv_file("data/characters-by-pinyin-learning-rare.csv", rows)

update_characters_by_pinyin = () ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length
  write_csv_file "data/characters-by-pinyin.csv", rows
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  write_csv_file "data/characters-by-pinyin-by-count.csv", rows
  # only common characters
  common_limit = 2000
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars = chars.slice(0, common_limit)
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length
  write_csv_file "data/characters-by-pinyin-common.csv", rows

http_get = (url) ->
  new Promise (resolve, reject) ->
    http.get url, (response) ->
      data = []
      response.on "data", (a) -> data.push a
      response.on "end", () -> resolve Buffer.concat(data).toString()
      response.on "error", (error) -> reject error

sort_by_array_with_index = (a, sorting, index) ->
  a.sort (a, b) -> sorting.indexOf(a[index]) - sorting.indexOf(b[index])

index_key_value = (a, key_key, value_key) ->
  b = {}
  a.forEach (a) -> b[a[key_key]] = a[value_key]
  b

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

update_character_overlap = () ->
  # 大犬太 草早旱
  stroke_count_index = get_stroke_count_index()
  decompositions_index = get_decompositions_index()
  words = Object.keys(decompositions_index)
  character_frequency_index = get_character_frequency_index()
  similarities = words.map (a) ->
    #return [] unless a[0] == "大"
    #return [] unless a == "口"
    #return [] unless a[0] == "草"
    aa = decompositions_index[a]?.split("").filter((a) -> a.match hanzi_regexp)
    a_strokes = parseInt stroke_count_index[a]
    return unless aa
    similarities = words.map (b) ->
      #return [] unless b == "哩"
      return if a == b
      bb = decompositions_index[b]?.split("").filter (a) -> a.match hanzi_regexp
      return unless bb
      inclusion = bb.includes a
      if inclusion
        b_strokes = parseInt stroke_count_index[b]
        strokes = Math.abs a_strokes - b_strokes
        intersection = array_intersection aa, bb
        overlap = intersection.length / Math.max(aa.length, bb.length)
        frequency = character_frequency_index[b] || words.length
        [a, b, overlap, strokes, frequency]
    similarities = similarities.filter (a) -> a
    similarities.sort (a, b) -> a[4] - b[4] || b[2] - a[2] || a[3] - b[3]
  similarities = similarities.filter (a) -> a && a.length
  rows = similarities.map (a) ->
    b = a.map (a) -> a[1]
    [a[0][0], b.join("")]
  rows = rows.sort (a, b) -> b[1].length - a[1].length
  write_csv_file "data/characters-overlap.csv", rows
  rows = similarities.map (a) ->
    b = a.filter((a) -> a[4] < 4000).map (a) -> a[1]
    [a[0][0], b.join("")]
  write_csv_file "data/characters-overlap-common.csv", rows

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

get_character_by_reading_index = () ->
  result = {}
  read_csv_file("data/table-of-general-standard-chinese-characters.csv").forEach (a) ->
    pinyin = a[1].split(", ")[0]
    object_array_add result, pinyin, a[0]
  result

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
    max_same_reading_characters = 8
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
  # move contained characters before containing characters.
  di = get_full_decompositions_index()
  pm = {}
  for i, a of items
    pm[a[char_key]] = i
  changed = true
  while changed
    changed = false
    i = 0
    while i < items.length
      c = items[i][char_key]
      deps = di[c] or []
      for d in deps
        j = pm[d]
        if j? and j > i
          b = items.splice(j, 1)[0]
          items.splice(i, 0, b)
          for k in [Math.min(i, j)..Math.max(i, j)]
            pm[items[k][char_key]] = k
          changed = true
          break
      if changed then break
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
  rows = ([a[0], a[1], a[2], a[3]] for a in rows)
  write_csv_file "data/characters-learning-reduced.csv", rows

update_syllables_character_count = () ->
  # number of characters with the same reading
  chars = read_csv_file("data/characters-by-pinyin.csv").map (a) -> [a[0], a[1].length]
  chars_common = read_csv_file("data/characters-by-pinyin-common.csv").map (a) -> [a[0], a[1].length]
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
  write_csv_file "data/syllables-tones-character-counts-common.csv", get_data(chars_common)

grade_text_files = (paths) ->
  paths.forEach (a) -> console.log grade_text(read_text_file(a)) + " " + path.basename(a)

grade_text = (a) ->
  chars = delete_duplicates a.match hanzi_regexp
  frequency_index = get_character_frequency_index()
  all_chars_count = Object.keys(frequency_index).length
  frequencies = chars.map((a) -> frequency_index[a] || all_chars_count).sort((a, b) -> a - b)
  count_score = chars.length / all_chars_count
  rarity_score = median(frequencies.splice(-10)) / all_chars_count
  Math.max 1, Math.round(10 * (count_score + rarity_score))

get_wiktionary_data = (char) ->
  body = await http_get "https://en.wiktionary.org/wiki/#{char}"
  html = html_parser.parse body
  b = html.querySelectorAll "p"
  b = b.map (a) ->
    strokes = a.textContent.match /(\d+) stroke/
    strokes = strokes && parseInt(strokes[1], 10)
    decomposition = a.querySelector "a[title=\"w:Chinese character description languages\"]"
    if decomposition
      decomposition = decomposition.parentNode.parentNode.textContent
      decomposition = decomposition.match(/decomposition (.*)\)/)[1]
      decomposition = (decomposition.split(" or ")[0].match(hanzi_and_idc_regexp) || []).join("")
    [char, strokes, decomposition]
  b = b.filter (a) -> a[1] || a[2]
  b.flat()

update_extra_stroke_counts = () ->
  data = read_csv_file "data/extra-components.csv"
  data = data.sort (a, b) -> b.length - a.length
  data = delete_duplicates_stable_with_key data, 0
  data = data.filter (a) -> a.length > 1
  data = data.map (a) -> [a[0], parseInt(a[1], 10)]
  data = data.sort (a, b) -> a[1] - b[1]
  write_csv_file "data/extra-stroke-counts.csv", data

update_decompositions = (start_index, end_index) ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.filter (a) -> "1" != a[1]
  chars = chars.slice start_index, end_index
  batch_size = 10
  batches_count = Math.ceil chars.length / batch_size
  batches = []
  i = 0
  while i < batches_count
    batches.push chars.slice i * batch_size, (i + 1) * batch_size
    i += 1
  batches.forEach (a) ->
    requests = Promise.all a.map (b) -> get_wiktionary_data b[0]
    requests.then (b) ->
      b.forEach (b, i) ->
        c = a[i]
        if (b[1] && b[1] != parseInt(c[1], 10)) || (b[2] && b[2].length >= c[2].length && b[2] != c[2])
          c[1] = b[1]
          c[2] = b[2]
          console.log c.join " "

add_new_data = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  new_data = read_csv_file("new-data").filter (a) -> a[0].length
  all = chars.concat new_data
  all_index = {}
  all.forEach (a) -> all_index[a[0]] = a
  all = Object.values(all_index).sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/characters-strokes-decomposition-new.csv", all

sort_data = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/characters-strokes-decomposition-new.csv", chars

find_component_repetitions = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.forEach (a) ->
    if a[2]
      b = a[2].replace non_hanzi_regexp, ""
      if 1 == delete_duplicates(split_chars(b)).length
        console.log a[0], b

update_compositions = ->
  rows = ([a, b.join("")] for a, b of get_compositions_index())
  write_csv_file "data/characters-composition.csv", rows

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
  compositions

update_composition_hierarchy = ->
  compositions = get_compositions_index()
  build = (a) ->
    b = [a]
    for c in compositions[a] when compositions[a]
      b.push(if compositions[c] then build(c) else c)
    b
  build_string = (a, root = true) ->
    if root
      lines = for item in a
        line = build_string(item, false)
        if line.length > 1
          line = line[0] + ' ' + line.substring(1)
        line
      lines.join "\n"
    else
      ((if Array.isArray(c) then "(" + build_string(c, false) + ")" else c) for c in a).join ""
  string = build_string (build a for a of compositions when a.match(hanzi_regexp))
  fs.writeFileSync "data/composition-hierarchy.txt", string

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

update_gridlearner_data = ->
  words = get_common_words_per_character 5, 32000
  chars = words.filter((a) -> 1 == a[0].length)
  batch_size = 750
  get_batch_index = (i) -> (1 + i / batch_size).toString().padStart 2, "0"
  for i in [0...chars.length] by batch_size
    data = ([a[1], a[0]] for a in chars[i...i + batch_size])
    ii = get_batch_index i
    write_csv_file "data/gridlearner/characters-pinyin-#{ii}.dsv", data
  for i in [0...chars.length] by batch_size
    data = ([a[2], a[0]] for a in chars[i...i + batch_size])
    ii = get_batch_index i
    write_csv_file "data/gridlearner/characters-translation-#{ii}.dsv", data
  for i in [0...words.length] by batch_size
    data = ([a[1], a[0]] for a in words[i...i + batch_size])
    ii = get_batch_index i
    write_csv_file "data/gridlearner/word-pinyin-#{ii}.dsv", data
  for i in [0...words.length] by batch_size
    data = ([a[2], a[0]] for a in words[i...i + batch_size])
    ii = get_batch_index i
    write_csv_file "data/gridlearner/word-translation-#{ii}.dsv", data

run = () ->
  update_composition_hierarchy()
  #update_characters_by_pinyin_learning()
  #update_gridlearner_data()
  #console.log "コ刂".match hanzi_regexp
  #find_component_repetitions()
  #console.log non_hanzi_regexp
  #sort_data()
  #add_new_data()
  #write_csv_file()
  #find_missing_compositions()
  #get_full_compositions()
  #data = delete_duplicates(data).sort((a, b) -> a.localeCompare(b))
  #fs.writeFileSync("data/extra-components-new.csv", data.join("\n"))
  #filter_common_characters()
  #sort_standard_character_readings()
  #update_syllables_character_count()
  #update_character_reading_count()
  #update_characters_learning()
  #update_syllables_with_tones_by_reading()
  #console.log "/" + hanzi_unicode_ranges_regexp + "/gu"
  #display_all_characters()
  #update_syllables_by_reading()

module.exports = {
  update_characters_by_pinyin_learning
  update_character_overlap
  cedict_filter_only
  clean_frequency_list
  dsv_add_translations
  dsv_add_example_words
  dsv_mark_to_number
  update_cedict_csv
  update_dictionary
  update_characters_data
  update_frequency_pinyin
  update_hsk
  update_hsk_pinyin_translations
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
}
