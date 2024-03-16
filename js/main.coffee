csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
html_parser = require "node-html-parser"
http =  require "https"
path = require "path"
pinyin_split = require "pinyin-split"
pinyin_utils = require "pinyin-utils"
#scraper = require "table-scraper"
read_csv_file = (path, delimiter) -> csv_parse.parse fs.readFileSync(path, "utf-8"), {delimiter: delimiter || " ", relax_column_count: true}
array_from_newline_file = (path) -> fs.readFileSync(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a
delete_duplicates = (a) -> [...new Set(a)]
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

array_shuffle = (a) ->
  i = a.length
  while 0 < i
    random_index = Math.floor(Math.random() * i)
    i -= 1
    temp = a[i]
    a[i] = a[random_index]
    a[random_index] = temp
  a

# https://en.wiktionary.org/wiki/Appendix:Unicode
hanzi_unicode_ranges = [
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
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency_array = array_from_newline_file "data/frequency.csv", "utf-8"
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
    pinyin = pinyin.split(" ").map (a) -> pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3")
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
  frequency = array_from_newline_file "data/frequency-pinyin.csv", "utf-8"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_all_characters = () -> read_csv_file("data/character-strokes-composition.csv").map (a) -> a[0]
display_all_characters = () -> console.log get_all_characters().join("")

get_character_frequency_index = () ->
  # -> {character: integer}
  chars = get_all_characters()
  frequency_index = {}
  chars.forEach (a, i) -> frequency_index[a] = i
  frequency_index

get_all_characters_and_pinyin = () ->
  # sorted by frequency
  result = []
  a = read_csv_file "data/frequency-pinyin.csv"
  a.forEach (a) ->
    chars = a[0].split ""
    pinyin = pinyin_split2 a[1]
    chars.forEach (a, i) -> result.push [a + pinyin[i], a, pinyin[i]]
  a = read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  a.forEach (a) -> a[1].split(", ").forEach (pinyin) -> result.push [a[0] + pinyin, a[0], pinyin]
  delete_duplicates_stable_with_key(result, 0).map (a) -> [a[1], a[2].replace("u:", "ü")]

get_frequency_characters_and_pinyin = () ->
  # with duplicates. use case: count character reading frequency
  result = []
  a = read_csv_file "data/frequency-pinyin.csv"
  a.forEach (a) ->
    chars = a[0].split ""
    pinyin = pinyin_split2 a[1]
    chars.forEach (a, i) -> result.push [a, pinyin[i]]
  result

get_character_pinyin_frequency_index = () ->
  # -> {character + pinyin: integer}
  chars = get_all_characters_and_pinyin()
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
  write_csv_file "data/character-reading-count.csv", rows

sort_by_frequency = (frequency_index, word_key, pinyin_key, data) ->
  data = data.sort (a, b) ->
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

sort_by_character_frequency = (frequency_index, character_key, data) ->
  data = data.sort (a, b) ->
    fa = frequency_index[a[character_key]]
    fb = frequency_index[b[character_key]]
    if fa is undefined and fb is undefined
      a[character_key].length - b[character_key].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb

update_cedict_csv = () ->
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency_index = get_frequency_index()
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) -> pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3")
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = cedict_additions data
  data = cedict_merge_definitions data
  data.forEach (a) -> a[2] = a[2].join "; "
  data = sort_by_frequency frequency_index, 0, 1, data
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
  words = read_csv_file "data/cedict.csv"
  words = dictionary_cedict_to_json words
  js = fs.readFileSync "js/dictionary.js", "utf8"
  js = js.replace "__word_data__", words
  html = fs.readFileSync "html/hanyu-dictionary-template.html", "utf8"
  html = html.replace "__script__", js.trim()
  fs.writeFile "html/hanyu-dictionary.html", html, on_error

clean_frequency_list = () ->
  frequency_array = array_from_newline_file "data/frequency.csv", "utf-8"
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
  frequency = array_from_newline_file "data/frequency.csv", "utf-8"
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
  write_csv_file "data/frequency-pinyin-translation.csv", rows
  rows = rows.map (a) -> [a[0], a[1]]
  write_csv_file "data/frequency-pinyin.csv", rows

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
  write_csv_file "data/hsk-pinyin-translation.csv", rows

pinyin_to_hanzi = (a) ->
  a = a.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches a, 1, 0, pinyin_split2

hanzi_to_pinyin = (a) ->
  a = a.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches a, 0, 1, (a) -> a.split ""

dsv_add_example_words = () ->
  dictionary = dictionary_index_word_pinyin_f 0, 1
  words = read_csv_file "data/frequency-pinyin-translation.csv"
  rows = read_csv_file(0).map (a) ->
    char_words = words.filter((b) -> b[0].includes a[0])
    unless char_words.length
      char_words = dictionary(a[0], a[1]) || []
    a.push char_words.slice(0, 5).map((b) -> b.join(" ")).join("\n")
    a
  write_csv_file 0, rows

update_characters_by_pinyin = () ->
  by_pinyin = {}
  chars = get_all_characters_and_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  write_csv_file "data/characters-by-pinyin.csv", rows
  # only common characters
  index = get_character_pinyin_frequency_index()
  char_count = chars.length
  rows = rows.map (a) ->
    pinyin = a[0]
    chars = a[1].split ""
    chars = chars.filter (b) ->
      frequency = index[b + pinyin] || char_count
      frequency < 4000
    [a[0], chars.join("")]
  rows = rows.filter (a) -> a[1].length
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
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

get_compositions_index = () -> index_key_value read_csv_file("data/character-strokes-composition.csv"), 0, 2

get_full_compositions = () ->
  # also include compositions of components per entry
  compositions_index = get_compositions_index()
  decompose = (a) ->
    parts = compositions_index[a]
    if parts
      parts = [...parts]
      [a].concat(parts, parts.map(decompose))
    else [a]
  Object.keys(compositions_index).map (a) ->
    parts = decompose(a).flat(Infinity)
    [parts[0], delete_duplicates(parts.slice(1))]
    #[parts[0], parts.slice(1)]

get_full_compositions_index = () -> index_key_value get_full_compositions(), 0, 1
get_stroke_count_index = (a) -> index_key_value read_csv_file("data/character-strokes-composition.csv"), 0, 1

update_character_overlap = () ->
  # 大犬太 草早旱
  config = {
    min_overlap: 0.7
    min_component_stroke_count: 0
    max_stroke_count_difference: 1
  }
  stroke_count_index = get_stroke_count_index()
  compositions = get_full_compositions()
  compositions = compositions.map (a) ->
    a1 = a[1].filter (a) -> (stroke_count_index[a] || 1) > config.min_component_stroke_count && a.match(hanzi_regexp)
    [a[0], a1]
  compositions = compositions.filter (a) -> a[1].length
  similarities = compositions.map (a) ->
    #return [] unless a[0] == "大"
    similarities = compositions.map (b) ->
      unless a[0] == b[0]
        b_compositions = b[1].filter (b) -> a[0] != b
        intersection = array_intersection a[1], b_compositions
        overlap = intersection.length / Math.max(a[1].length, b_compositions.length)
        a_strokes = stroke_count_index[a[0]]
        b_strokes = stroke_count_index[b[0]]
        stroke_difference = Math.abs(b_strokes - a_strokes) / Math.max(a_strokes, b_strokes)
        if overlap > config.min_overlap && stroke_difference < config.max_stroke_count_difference
          #console.log a[0], b[0], overlap, stroke_difference, a[1].join(""), b_compositions.join("")
          [a[0], b[0], overlap, stroke_difference]
    similarities = similarities.filter (a) -> a
    similarities.sort (a, b) -> b[2] - a[2] || a[3] - b[3]
  similarities = similarities.filter (a) -> a.length
  similarities = similarities.map (a) ->
    b = a.map (a) -> a[1]
    [a[0][0], b.join("")]
  similarities = similarities.sort (a, b) -> b[1].length - a[1].length
  write_csv_file "data/character-overlap.csv", similarities
  character_frequency_index = get_character_frequency_index()
  similarities_common = similarities.map (a) ->
    [a[0], a[1].split("").filter((a) -> (character_frequency_index[a] || 9000) < 4000).join("")]
  similarities_common = similarities_common.filter (a) -> a[1].length
  similarities_common = similarities_common.sort (a, b) -> b[1].length - a[1].length
  write_csv_file "data/character-overlap-common.csv", similarities_common

get_character_reading_count_index = () ->
  result = {}
  read_csv_file("data/character-reading-count.csv").forEach (a) -> result[a[0] + a[1]] = parseInt a[2]
  result

get_character_syllables_tones_count_index = () ->
  result = {}
  read_csv_file("data/syllables-tones-character-count.csv").forEach (a) -> result[a[0]] = parseInt a[1]
  result

get_character_example_words_f = () ->
  dictionary = dictionary_index_word_pinyin_f 0, 1
  words = read_csv_file "data/frequency-pinyin-translation.csv"
  (char, pinyin) ->
    char_word = words.find((b) -> b[0] is char)
    unless char_word
      char_word = dictionary(char, pinyin)
      char_word = char_word[0] if char_word
    char_words = if char_word then [char_word] else []
    char_words.concat words.filter (b) -> b[0].includes(char) && b[0] != char

sort_standard_character_readings = () ->
  reading_count_index = get_character_reading_count_index()
  path = "data/table-of-general-standard-chinese-characters.csv"
  rows = read_csv_file(path).map (a) ->
    char = a[0]
    pinyin = a[1].split ", "
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

update_character_learning = () ->
  character_frequency_index = get_character_frequency_index()
  reading_count_index = get_character_reading_count_index()
  character_by_reading_index = get_character_by_reading_index()
  dictionary = dictionary_index_word_pinyin_f 0, 1
  get_character_example_words = get_character_example_words_f()
  compositions_index = get_character_compositions_index()
  rows = read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (a) -> [a[0], a[1].split(", ")[0]]
  rows = sort_by_character_frequency character_frequency_index, 0, rows
  syllables = delete_duplicates rows.map((a) -> a[1].split(", ")).flat()
  add_example_words = (rows) ->
    rows.map (a) ->
      words = get_character_example_words(a[0], a[1])
      a.push words.slice(1, 5).map((b) -> b[0]).join " "
      a.push words.slice(0, 5).map((b) -> b.join(" ")).join "\n"
      a
  rows = add_example_words rows
  add_guess_pronunciations = (rows) ->
    syllable_count_index = get_character_syllables_tones_count_index()
    rows.map (a) ->
      # add for each guess reading the number of other characters with this reading
      alternatives = n_times 4, (n) -> random_element syllables
      alternatives = delete_duplicates array_shuffle [a[1]].concat alternatives
      alternatives = alternatives.map (b) -> b + " (" + (syllable_count_index[b] || 1) + ")"
      a.push alternatives.join " "
      a
  add_pronunciation_hint = (rows) ->
    rows.map (a) ->
      b = array_shuffle (character_by_reading_index[a[1]] || []).filter((b) -> a[0] != b)
      a.push b.slice(0, 5).join ""
      a
  rows = add_pronunciation_hint rows
  add_syllable_counts = (rows) ->
    rows.map (a) ->
      # must be run after add guess pronunciations.
      # add for each possible reading the number of words with this character and reading
      a[1] = a[1].split(", ").map((b) -> b + " (" + (reading_count_index[a[0] + b] || 1) + ")").join(", ")
      a
  # add compositions
  rows.map (a) ->
    b = compositions_index[a[0]]
    a.push b if b
    a
  # add sort index
  rows.map (a, i) ->
    a.push i
    a
  # write
  write_csv_file "data/character-learning.csv", rows

update_syllables_character_count = () ->
  # number of characters with the same reading
  chars = read_csv_file("data/characters-by-reading.csv").map (a) -> [a[0], a[1].length]
  chars_without_tones = chars.map (a) -> [a[0].replace(/[0-5]/g, ""), a[1]]
  get_data = (chars) ->
    counts = {}
    chars.forEach (a) ->
      if counts[a[0]] then counts[a[0]] += a[1]
      else counts[a[0]] = a[1]
    chars = chars.map (a) -> a[0]
    chars = delete_duplicates_stable chars
    chars.map((a) -> [a, counts[a]]).sort (a, b) -> b[1] - a[1]
  write_csv_file "data/syllables-tones-character-count.csv", get_data(chars)
  write_csv_file "data/syllables-character-count.csv", get_data(chars_without_tones)

grade_text_files = (paths) ->
  paths.forEach (a) -> console.log grade_text(fs.readFileSync(a, "utf-8")) + " " + path.basename(a)

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
    composition = a.querySelector "a[title=\"w:Chinese character description languages\"]"
    if composition
      composition = composition.parentNode.parentNode.textContent
      composition = composition.match(/composition (.*)\)/)[1]
      composition = (composition.split(" or ")[0].match(hanzi_and_idc_regexp) || []).join("")
    [char, strokes, composition]
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

update_compositions = (start_index, end_index) ->
  chars = read_csv_file "data/character-strokes-composition.csv"
  chars = chars.filter (a) -> "1" != a[1]
  result = []
  for a, i in chars.slice(start_index, end_index)
    data = await get_wiktionary_data a[0]
    unless data[1] is parseInt(a[1], 10) and data[2] is a[2]
      a[1] = data[1]
      a[2] = data[2]
      console.log a.join " "
    result.push a
  #write_csv_file "data/character-strokes-composition-updated.csv", result

add_new_data = () ->
  chars = read_csv_file("data/character-strokes-composition.csv")
  new_data = read_csv_file("new-data").filter (a) -> a[0].length
  all = chars.concat new_data
  all_index = {}
  all.forEach (a) -> all_index[a[0]] = a
  all = Object.values(all_index).sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/character-strokes-composition-new.csv", all

sort_data = () ->
  chars = read_csv_file("data/character-strokes-composition.csv")
  chars = chars.sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/character-strokes-composition-new.csv", chars

run = () ->
  #console.log non_hanzi_regexp
  sort_data()
  #add_new_data()
  #update_compositions 8000, 9000
  #write_csv_file()
  #find_missing_compositions()
  #get_full_compositions()
  #data = delete_duplicates(data).sort((a, b) -> a.localeCompare(b))
  #fs.writeFileSync("data/extra-components-new.csv", data.join("\n"))
  #filter_common_characters()
  #sort_standard_character_readings()
  #update_syllables_character_count()
  #update_character_reading_count()
  #update_character_learning()
  #update_syllables_with_tones_by_reading()
  #console.log "/" + hanzi_unicode_ranges_regexp + "/gu"
  #display_all_characters()
  #update_syllables_by_reading()
  #update_compositions()

module.exports = {
  update_character_overlap
  cedict_filter_only
  clean_frequency_list
  dsv_add_translations
  dsv_add_example_words
  dsv_mark_to_number
  update_cedict_csv
  update_dictionary
  update_frequency_pinyin
  update_hsk
  update_hsk_pinyin_translations
  traditional_to_simplified
  pinyin_to_hanzi
  hanzi_to_pinyin
  mark_to_number
  update_characters_by_pinyin
  update_character_learning
  grade_text
  grade_text_files
  run
}
