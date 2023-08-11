fs = require "fs"
scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
pinyin_split = require "pinyin-split"
csv_parse = require "csv-parse/sync"
hanzi_tools = require "hanzi-tools"

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
    /[^()a-z0-9?': ,.-]/
    /^taiwan pr./
    /variant of /
    /^cl:/
    /^surname /
    /^abbr\. for /
    /^see [^a-zA-Z]/
    /^see also [^a-zA-Z]/
    /^used in [^a-zA-Z]/
    /^\(used in /
    /\(tw\)/
    /^also pr\. /
    /^taiwanese \. /
    /\(\d+/
    /\d+-\d+/
    /\(budd.+\)/
    /\(onom\.\)/
    /.buddhism/
    /buddhism./
    /buddhist./
    /.buddhist/
    /.sanskrit/
    /sanskrit./
    /.bird species./
  ]
  definitions = a.split "/"
  definitions = definitions.map (a) -> a.toLowerCase()
  definitions.filter (a) -> !filter_regexp.some((b) -> a.match b)

cedict_merge_definitions = (a) ->
  table = {}
  a.forEach (a, index) ->
    key = a[0] + "#" + a[1]
    if table[key]
      table[key][1][2] = table[key][1][2].concat a[2]
    else table[key] = [index, a]
  Object.values(table).sort((a, b) -> a[0] - b[0]).map((a) -> a[1])

data_additions = (a) ->
  a.push ["你", "nǐ", ["you"]]
  a

cedict_filter_only = () ->
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

cedict_extract = () ->
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency_array = array_from_newline_file "data/frequency.csv", "utf-8"
  frequency = {}
  frequency_array.forEach (a, i) -> frequency[a] = i
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
  data = data_additions data
  data = cedict_merge_definitions data
  data.forEach (a) -> a[2] = a[2].join "; "
  # sort by frequency
  data = data.sort (a, b) ->
    fa = frequency[a[0]]
    fb = frequency[b[0]]
    if fa is undefined and fb is undefined
      a[0].length - b[0].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb
  data = data.filter (a, index) ->
    index < 3000 || a[0].length < 3
  test_order = () ->
    example1 = data.findIndex((a) => a[0] is "猫")
    example2 = data.findIndex((a) => a[0] is "熊猫")
    if example1 < example2 then console.log "success"
    else console.log "failure"
  #test_order()
  fs.writeFile "data/cedict.csv", csv_stringify.stringify(data), on_error

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[2] = a[2].split "/"
    a

update_dictionary = () ->
  words = read_csv_file "data/cedict.csv", ","
  words = dictionary_cedict_to_json words
  html = fs.readFileSync "html/hanyu-dictionary-template.html", "utf8"
  html = html.replace("{word-data}", words)
  fs.writeFile "download/hanyu-dictionary.html", html, on_error

remove_non_chinese_characters = (a) -> a.replace /[^\p{Script=Han}]/ug, ""
traditional_to_simplified = (a) -> hanzi_tools.simplify a

clean_frequency_list = () ->
  frequency_array = array_from_newline_file "data/frequency.csv", "utf-8"
  frequency_array = frequency_array.filter (a) ->
    traditional_to_simplified remove_non_chinese_characters a
  frequency_array.forEach (a) -> console.log a

dictionary_lookup_f = () ->
  dictionary = {}
  words = read_csv_file "data/cedict.csv", ","
  words.forEach (a) ->
    unless dictionary[a[0]]
      if "打" is a[0]
        console.log a
      dictionary[a[0]] = a.slice 1
  (a) -> dictionary[a]

csv_add_translations = (word_column_index) ->
  dictionary_lookup = dictionary_lookup_f()
  lines = read_csv_file 0, ","
  lines = lines.map (a) -> a.concat dictionary_lookup(a[word_column_index]) || ""
  console.log csv_stringify.stringify(lines, {delimiter: " "}, on_error).trim()

update_hsk3 = () ->
  files = fs.readdirSync "data/hsk3"
  data = files.map (a) -> read_csv_file("data/hsk3/#{a}", "\t")
  data = data.flat(1).map (a) ->
    pinyin = pinyin_split.split(a[2]).map(pinyin_utils.markToNumber).join("")
    [a[1], pinyin]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/hsk3.csv", data, on_error

update_frequency_pinyin = () ->
  frequency = array_from_newline_file "data/frequency.csv", "utf-8"
  hsk = read_csv_file "data/hsk3.csv", " "
  hsk_index = {}
  hsk.forEach (a) -> hsk_index[a[0]] = a[1] unless hsk_index[a[0]]
  data = frequency.map (a) -> [a, (hsk_index[a] || "")]
  data = csv_stringify.stringify(data, {delimiter: " "}, on_error).trim()
  fs.writeFile "data/frequency-pinyin.csv", data, on_error

module.exports = {
  clean_frequency_list
  cedict_extract
  character_list
  update_dictionary
  csv_add_translations
  cedict_filter_only
  update_hsk3
  update_frequency_pinyin
}
