fs = require "fs"
scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
csv_parse = require "csv-parse/sync"

read_csv_file = (path, delimiter) -> csv_parse.parse fs.readFileSync(path, "utf-8"), {delimiter: delimiter}
array_from_newline_file = (path) -> fs.readFileSync(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a

frequency_list = () ->
  url_prefix = "https://en.wiktionary.org/wiki/Appendix:Mandarin_Frequency_lists"
  url_suffixes = [
    "1-1000"
    "1001-2000"
    "2001-3000"
    "3001-4000"
    "4001-5000"
    "5001-6000"
    "6001-7000"
    "7001-8000"
    "8001-9000"
    "9001-10000"
  ]
  url_suffixes.forEach (url_suffix) ->
    url = "#{url_prefix}/#{url_suffix}"
    scraper.get(url).then (rows) ->
      rows = rows[0].map (row) ->
        console.log row.Simplified

character_list = () ->
  url = "https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters"
  scraper.get(url).then (tables) ->
    hanzi = tables.flat().map (a) -> a.Hanzi
    fs.writeFile "data/togscc.csv", hanzi.join("\n") + "\n", on_error

cedict_extract = () ->
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency = array_from_newline_file("data/frequency.csv", "utf-8")
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) ->
      pinyin_utils.numberToMark(a)
    pinyin = pinyin.join("")
    glossary = parsed[4].replace /\[([^\]]+)\]/g, ""
    glossary = glossary.replace /\s([^a-zA-Z0-9,. \|]+)\|([^a-zA-Z0-9,. ]+)(\W|$)/g, (a, b, c, d) ->
      " " + c + d
    pinyin_no_tone = pinyin_utils.removeTone pinyin
    [word, pinyin, pinyin_no_tone, glossary]
  data = data.filter((a) -> a)
  data.sort (a, b) ->
    frequency.indexOf(a) - frequency.indexOf(b)
  fs.writeFile "data/cedict.csv", csv_stringify.stringify(data), on_error

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[3] = a[3].split "/"
    a

update_dictionary = (config) ->
  words = read_csv_file "data/cedict.csv", ","
  words = dictionary_cedict_to_json words
  html = fs.readFileSync "html/dictionary-template.html", "utf8"
  html = html.replace("{word-data}", words)
  on_error = (a) -> if a then console.error a
  fs.writeFile "download/hanyu-dictionary.html", html, on_error

#cedict_extract()
#frequency_list()
#character_list()
update_dictionary()
