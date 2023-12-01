fs = require "fs"
#scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
pinyin_split = require "pinyin-split"
csv_parse = require "csv-parse/sync"
hanzi_tools = require "hanzi-tools"
pinyin_split = require "pinyin-split"

read_csv_file = (path, delimiter) -> csv_parse.parse fs.readFileSync(path, "utf-8"), {delimiter: delimiter, relax_column_count: true}
array_from_newline_file = (path) -> fs.readFileSync(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a

#character_list = () ->
#  url = "https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters"
#  scraper.get(url).then (tables) ->
#    hanzi = tables.flat().map (a) -> a.Hanzi
#    fs.writeFile "data/togscc.csv", hanzi.join("\n") + "\n", on_error

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
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word_traditional = parsed[1]
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) -> pinyin_utils.markToNumber(a)
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
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency = array_from_newline_file "data/frequency-pinyin.csv", "utf-8"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) -> pinyin_utils.markToNumber(a)
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = cedict_additions data
  data = cedict_merge_definitions data
  data.forEach (a) -> a[2] = a[2].join "; "
  data = data.sort (a, b) ->
    fa = frequency_index[a[0] + a[1]]
    fb = frequency_index[b[0] + b[1]]
    if fa is undefined and fb is undefined
      a[0].length - b[0].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb
  data = data.filter (a, index) -> index < 3000 || a[0].length < 3
  test = () ->
    example1 = data.findIndex((a) => a[0] is "猫")
    example2 = data.findIndex((a) => a[0] is "熊猫")
    throw "test failed" unless example1 < example2
  #test()
  fs.writeFile "data/cedict.csv", csv_stringify.stringify(data), on_error

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[2] = a[2].split "/"
    a

update_dictionary = () ->
  words = read_csv_file "data/cedict.csv", ","
  words = dictionary_cedict_to_json words
  js = fs.readFileSync "js/dictionary.js", "utf8"
  js = js.replace "__word_data__", words
  html = fs.readFileSync "html/hanyu-dictionary-template.html", "utf8"
  html = html.replace "__script__", js.trim()
  fs.writeFile "download/hanyu-dictionary.html", html, on_error

remove_non_chinese_characters = (a) -> a.replace /[^\p{Script=Han}]/ug, ""
traditional_to_simplified = (a) -> hanzi_tools.simplify a

clean_frequency_list = () ->
  frequency_array = array_from_newline_file "data/frequency.csv", "utf-8"
  frequency_array = frequency_array.filter (a) ->
    traditional_to_simplified remove_non_chinese_characters a
  frequency_array.forEach (a) -> console.log a

update_hsk = () ->
  files = fs.readdirSync "data/hsk"
  data = files.map (a) -> read_csv_file("data/hsk/#{a}", "\t")
  data = data.flat(1).map (a) ->
    pinyin = pinyin_split.split(a[2]).map(pinyin_utils.markToNumber).join("").toLowerCase()
    [a[1], pinyin]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/hsk.csv", data, on_error

update_frequency_pinyin = () ->
  frequency = array_from_newline_file "data/frequency.csv", "utf-8"
  hsk = read_csv_file "data/hsk.csv", " "
  hsk_index = {}
  hsk.forEach (a) ->
    return if hsk_index[a[0]]
    pinyin = a[1]
    pinyin += "5" unless /[0-5]$/.test pinyin
    hsk_index[a[0]] = pinyin
  data = frequency.map (a) -> [a, (hsk_index[a] || "")]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error)
  fs.writeFile "data/frequency-pinyin.csv", data, on_error

object_array_add = (object, key, value) ->
  if object[key] then object[key].push value else object[key] = [value]

dictionary_index_f = (key_index) ->
  dictionary = {}
  words = read_csv_file "data/cedict.csv", ","
  words.forEach (a) ->
    key = a[key_index]
    object_array_add dictionary, key, a
  (a) -> dictionary[a]

dictionary_index_word_pinyin_f = (word_index, pinyin_index) ->
  dictionary = {}
  words = read_csv_file "data/cedict.csv", ","
  words.forEach (a) ->
    word = a[word_index]
    key = a[word_index] + a[pinyin_index]
    object_array_add dictionary, key, a
    object_array_add dictionary, word, a
  (word, pinyin) -> dictionary[word + pinyin]

update_frequency_pinyin_translation = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  frequency_pinyin = read_csv_file "data/frequency-pinyin.csv", " "
  lines = frequency_pinyin.map (a) ->
    translation = dictionary_lookup a[0], a[1]
    return [] unless translation
    [a[0], translation[0][1], translation[0][2]]
  lines = lines.filter (a) -> 3 is a.length
  data = csv_stringify.stringify(lines, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/frequency-pinyin-translation.csv", data, on_error

mark_to_number = (a) ->
  a.split(" ").map((a) -> pinyin_split.split(a).map(pinyin_utils.markToNumber).join("")).join(" ")

non_hanzi_regexp = /[^\u4E00-\u9FA5]/g
non_pinyin_regexp = /[^a-z0-5]/g

find_multiple_word_matches = (a, lookup_index, translation_index, split_syllables) ->
  # for each space separated element, find all longest most frequent words with the pronunciation.
  dictionary_lookup = dictionary_index_f lookup_index
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

dsv_add_translations = (word_index, pinyin_index) ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  rows = read_csv_file(0, ",").map (a) ->
    translations = dictionary_lookup a[0], a[1]
    return a unless translations
    a.concat [translations[0][2]]
  console.log csv_stringify.stringify(rows, {delimiter: " "}, on_error).trim()

dsv_mark_to_number = (pinyin_index) ->
  rows = read_csv_file(0, " ").map (a) ->
    a[pinyin_index] = mark_to_number a[pinyin_index]
    a
  console.log csv_stringify.stringify(rows, {delimiter: " "}, on_error).trim()

update_hsk_pinyin_translations = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  hsk = read_csv_file("data/hsk.csv", " ").map (a) ->
    translations = dictionary_lookup a[0], a[1]
    return a unless translations
    a.concat [translations[0][2]]
  data = csv_stringify.stringify(hsk, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/hsk-pinyin-translation.csv", data, on_error

pinyin_to_hanzi = (a) ->
  a = a.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches a, 1, 0, pinyin_split.split

hanzi_to_pinyin = (a) ->
  a = a.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches a, 0, 1, (a) -> a.split ""

find_components = (a, decompositions) ->
  b = decompositions[a]
  c = []
  return c unless b
  return c if b[1] is b[2]
  c.push b[1] unless b[1] is "*" or a is b[1]
  c.push b[2] unless b[2] is "*" or a is b[2]
  c.concat(c.map (c) -> find_components(c, decompositions)).flat()

update_compositions = () ->
  chars = read_csv_file("data/table-of-general-standard-chinese-characters.csv", " ").map (a) -> a[0]
  decompositions_csv = read_csv_file("data/decompositions.csv", "\t").sort (a, b) -> a[1] - b[1]
  decompositions = {}
  decompositions_csv.forEach (a) -> decompositions[a[0]] = [a[1], a[3], a[5]]
  compositions = chars.map (a) -> [a].concat find_components(a, decompositions)
  data = csv_stringify.stringify(compositions, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/compositions.csv", data, on_error

dsv_process = (a, b) ->
  # add pinyin looked up from other file
  pronunciations = {}
  read_csv_file(a, " ").forEach (a) -> pronunciations[a[0]] = a[1]
  words = read_csv_file b, " "
  words = words.map (a) -> [a[0], pronunciations[a[0]]]
  console.log csv_stringify.stringify(words, {delimiter: " "}, on_error).trim()
  # filter characters
  #chars = read_csv_file("data/table-of-general-standard-chinese-characters.csv", " ").map (a) -> a[0]
  #rows = read_csv_file(0, " ").map (a) ->
  #  [a[0]].concat a.slice(1).filter (a) -> chars.includes a

module.exports = {
  update_compositions
  cedict_filter_only
  clean_frequency_list
  dsv_add_translations
  dsv_mark_to_number
  update_cedict_csv
  update_dictionary
  update_frequency_pinyin
  update_frequency_pinyin_translation
  update_hsk
  update_hsk_pinyin_translations
  traditional_to_simplified
  pinyin_to_hanzi
  hanzi_to_pinyin
  mark_to_number
  dsv_process
}
