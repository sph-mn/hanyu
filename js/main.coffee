fs = require "fs"
scraper = require "table-scraper"
csv_stringify = require "csv-stringify/sync"
pinyin_utils = require "pinyin-utils"
csv_parse = require "csv-parse/sync"

read_csv_file = (path, delimiter) -> csv_parse.parse fs.readFileSync(path, "utf-8"), {delimiter: delimiter}
array_from_newline_file = (path) -> fs.readFileSync(path).toString().trim().split("\n")
on_error = (a) -> if a then console.error a

character_list = () ->
  url = "https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters"
  scraper.get(url).then (tables) ->
    hanzi = tables.flat().map (a) -> a.Hanzi
    fs.writeFile "data/togscc.csv", hanzi.join("\n") + "\n", on_error

cedict_glossary = (a) ->
  definitions = a.split("/")
  definitions = definitions.filter (a) ->
    !a.match(/^Taiwan pr./) && !a.match(/variant of/) && !a.match(/^CL:/)
  definitions = definitions.map (a) -> a.toLowerCase()
  return definitions.join("/")

cedict_extract = () ->
  cedict = fs.readFileSync "data/cedict_ts.u8", "utf-8"
  frequency_array = array_from_newline_file("data/frequency.csv", "utf-8")
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
    pinyin = pinyin.join("")
    glossary = cedict_glossary parsed[4]
    unless glossary then return null
    pinyin_no_tone = pinyin_utils.removeTone pinyin
    [word, pinyin, glossary]
  data = data.filter((a) -> a)
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

update_dictionary = (config) ->
  words = read_csv_file "data/cedict.csv", ","
  words = dictionary_cedict_to_json words
  html = fs.readFileSync "html/dictionary-template.html", "utf8"
  html = html.replace("{word-data}", words)
  on_error = (a) -> if a then console.error a
  fs.writeFile "download/hanyu-dictionary.html", html, on_error

#cedict_extract()
#character_list()
update_dictionary()
