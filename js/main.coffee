fs = require "fs"
scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
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
    /\(budd.+\)/
    /.buddhism/
    /buddhism./
    /buddhist./
    /.buddhist/
    /.sanskrit/
    /sanskrit./
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
    pinyin = pinyin.split(" ").map (a) -> pinyin_utils.numberToMark(a)
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = data_additions data
  console.log(data[data.length - 2])
  console.log(data[data.length - 1])
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
  on_error = (a) -> if a then console.error a
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
  words.forEach (a) -> unless dictionary[a[0]] then dictionary[a[0]] = a.slice 1
  (a) -> dictionary[a]

csv_add_translations = (word_column_index) ->
  dictionary_lookup = dictionary_lookup_f()
  lines = read_csv_file 0, ","
  lines = lines.map (a) ->
    a.concat dictionary_lookup(a[word_column_index]) || ""
  on_error = (a) -> if a then console.error a
  console.log csv_stringify.stringify(lines, {delimiter: " "}, on_error).trim()

module.exports = {
  clean_frequency_list
  cedict_extract
  character_list
  update_dictionary
  csv_add_translations
}
