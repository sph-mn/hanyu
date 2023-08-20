fs = require "fs"
scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
pinyin_split = require "pinyin-split"
csv_parse = require "csv-parse/sync"
hanzi_tools = require "hanzi-tools"
pinyin_split = require "pinyin-split"

read_csv_file = (path, delimiter) -> csv_parse.parse fs.readFileSync(path, "utf-8"), {delimiter: delimiter}
array_from_newline_file = (path) -> fs.readFileSync(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a

character_list = () ->
  url = "https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters"
  scraper.get(url).then (tables) ->
    hanzi = tables.flat().map (a) -> a.Hanzi
    fs.writeFile "data/togscc.csv", hanzi.join("\n") + "\n", on_error

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

update_hsk3 = () ->
  files = fs.readdirSync "data/hsk3"
  data = files.map (a) -> read_csv_file("data/hsk3/#{a}", "\t")
  data = data.flat(1).map (a) ->
    pinyin = pinyin_split.split(a[2]).map(pinyin_utils.markToNumber).join("").toLowerCase()
    [a[1], pinyin]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/hsk3.csv", data, on_error

update_frequency_pinyin = () ->
  frequency = array_from_newline_file "data/frequency.csv", "utf-8"
  hsk = read_csv_file "data/hsk3.csv", " "
  hsk_index = {}
  hsk.forEach (a) ->
    return if hsk_index[a[0]]
    pinyin = a[1]
    pinyin += "5" unless /[0-5]$/.test pinyin
    hsk_index[a[0]] = pinyin
  data = frequency.map (a) -> [a, (hsk_index[a] || "")]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error)
  fs.writeFile "data/frequency-pinyin.csv", data, on_error

update_frequency_pinyin_translation = () ->
  dictionary_lookup_f = () ->
    dictionary = {}
    words = read_csv_file "data/cedict.csv", ","
    words.forEach (a) ->
      key = a[0] + a[1]
      dictionary[key] = a.slice(1) unless dictionary[key]
      dictionary[a[0]] = a.slice(1) unless dictionary[a[0]]
    (word, pinyin) -> dictionary[word + pinyin]
  dictionary_lookup = dictionary_lookup_f()
  frequency_pinyin = read_csv_file "data/frequency-pinyin.csv", " "
  lines = frequency_pinyin.map (a) ->
    translation = dictionary_lookup a[0], a[1]
    return [] unless translation
    [a[0], translation[0], translation[1]]
  lines = lines.filter (a) -> 3 is a.length
  data = csv_stringify.stringify(lines, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/frequency-pinyin-translation.csv", data, on_error

mark_to_number = (a) ->
  a.split(" ").map((a) -> pinyin_split.split(a).map(pinyin_utils.markToNumber).join("")).join(" ")

dictionary_index_f = (key_index) ->
  dictionary = {}
  words = read_csv_file "data/cedict.csv", ","
  words.forEach (a) ->
    key = a[key_index]
    if dictionary[key] then dictionary[key].push a
    else dictionary[key] = [a]
  (pinyin) -> dictionary[pinyin]

pinyin_to_hanzi = (a) ->
  # for each space separated element, find all longest most frequent words with the pronunciation.
  dictionary_lookup = dictionary_index_f 1
  results = []
  a.split(" ").forEach (a) ->
    syllables = pinyin_split.split a
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
      reversed_candidates = candidates[i].reverse()
      while j < reversed_candidates.length
        translations = dictionary_lookup reversed_candidates[j]
        if translations
          matches.push translations.map((a) -> a[0]).join "/"
          break
        j += 1
      results.push (if matches.length then matches[0] else candidates[i][0])
      i += reversed_candidates.length - j
  results.join " "

hanzi_to_pinyin = (a) ->
  # same algorithm as for pinyin_to_hanzi except for hanzi as input
  dictionary_lookup = dictionary_index_f 0
  results = []
  a.split(" ").forEach (a) ->
    syllables = a.trim().split ""
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
      reversed_candidates = candidates[i].reverse()
      while j < reversed_candidates.length
        translations = dictionary_lookup reversed_candidates[j]
        if translations
          matches.push translations.map((a) -> a[1]).join "/"
          break
        j += 1
      results.push (if matches.length then matches[0] else candidates[i][0])
      i += reversed_candidates.length - j
  results.join " "

module.exports = {
  cedict_filter_only
  character_list
  clean_frequency_list
  update_cedict_csv
  update_dictionary
  update_frequency_pinyin
  update_frequency_pinyin_translation
  update_hsk3
  traditional_to_simplified
  pinyin_to_hanzi
  hanzi_to_pinyin
  mark_to_number
}
