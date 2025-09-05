h = require "./helper"
fs = require "fs"

get_word_frequency_index_with_pinyin = () ->
  frequency = array_from_newline_file "data/words-by-frequency-with-pinyin.csv"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

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
    /\(arch\./
    /\(dialect/
    /\(vulgar/
    /\(tcm\)/
    / tcm\)/
    /\(brand\)/
    / brand\)/
    /hotel chain\)/
    /hotel company\)/
    /\(cantonese\)/
    /\(company\)/
    / islam\)/
    /\(hong kong/
    /\(chinese medicine\)/
    /\(shanghainese/
    / dialect\)/
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

cedict_overrides = (a) ->
  data = h.read_csv_file "data/additional-translations.csv"
  for b in data
    index = a.findIndex (c) -> c[0] == b[0]
    continue unless index >= 0
    a[index] = [b[0], b[1], b.slice(2)]
  a

cedict_filter_only = () ->
  cedict = h.read_text_file "data/foreign/cedict_ts.u8"
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
  cedict = h.read_text_file "data/cedict-filtered.u8"
  frequency_index = get_word_frequency_index_with_pinyin()
  lines = cedict.split "\n"
  data = lines.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    if word.match(/[a-zA-Z0-9]/) then return null
    pinyin = parsed[3]
    pinyin = h.pinyin_split2(pinyin).map (a) ->
      pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3").replace("45", "4").replace("25", "2")
    pinyin = pinyin.join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    unless glossary.length then return null
    [word, pinyin, glossary]
  data = data.filter (a) -> a
  data = cedict_merge_definitions data
  data = cedict_overrides data
  data.forEach (a) -> a[2] = a[2].join "; "
  data = sort_by_word_frequency_with_pinyin frequency_index, 0, 1, data
  data = data.filter (a, index) -> index < 3000 || a[0].length < 3
  h.write_csv_file "data/cedict.csv", data

module.exports = {
  cedict_glossary
  cedict_merge_definitions
  cedict_filter_only
  update_cedict_csv
}
