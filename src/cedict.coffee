h = require "./helper"
fs = require "fs"

on_error = (a) -> if a then console.error a

get_word_frequency_index_with_pinyin = () ->
  frequency = h.array_from_newline_file "data/words-by-frequency-with-pinyin.csv"
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
    else if fa is undefined then 1
    else if fb is undefined then -1
    else fa - fb

cedict_glossary = (a) ->
  filter_regexp = [
    /^abbr\. for /
    /^also pr\. /
    /.ancient/
    /ancient./
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
    /\(slang/
    / slang\)/
    / dialect\)/
    /masturbate/
    /masturbation/
    /clitoris/
    /penis/
    /\bfuck\b/
    /\(name\)/
    /\(chewing gum company\)/
    /allianz, german financial service company/
    /\bkodak\b/
    /\bbmw\b/
    /\bboeing\b/
    /\bkraft\b/
    /\bcisco systems\b/
    /\brenault\b/
    /\bmoody's\b/
    /\bgoogle\b/
    /\bavon\b/
    /\bmcdonnell douglas\b/
    /\bpaypal\b/
    /\bheineken\b/
    /\badvantech\b/
    /\bbosch\b/
    /\bpfizer\b/
    /\bsina\b/
    /\bbandai\b/
    /\bheinz\b/
    /\bjingdong\b/
    /bmorishita jintan company\b/
    /\bevian\b/
    /\buber\b/
    /\bpeak sport products\b/
    /\bdji\b/
    /\bnetflix\b/
    /\ballianz\b/
    /\bsohu\b/
    /\bsogou\b/
    /\bnec\b/
    /\beachnet\b/
    /\bparker pen company\b/
    /btaobao\b/
    /\bwrigley\b/
    /\bvanke\b/
    /\bchina mengniu dairy company limited\b/
    /\bcoolpad group ltd\b/
    /\bmaxsun\b/
    /\bshangke corporation\b/
    /\btianjin faw xiali motor company\b/
    /\bobsolete equivalent\b/
    /\bmandarin equivalent: /
    /\bequivalent to: /
    /\bsame as /
    /\bused only in /
    /\bcounty in /
    /\bcounty-level city in /
    /\bdistrict of /
  ]
  parentheses_filter_regexp = [
    /[^()a-z0-9?':; ,.-]/
  ]
  optional_filter_regexp = [
    /[^()a-z0-9?':; ,.-]/
  ]
  a = a.split("/").map (x) -> x.toLowerCase().split ";"
  a = a.flat().map (x) ->
    x = x.trim()
    for r in parentheses_filter_regexp
      re = new RegExp "\\([^)]*(?:" + r.source + ")[^)]*\\)", "g"
      x = x.replace re, ""
    x.trim().replace /\[[^\]]+\]/g, ""
  a = a.filter (x) ->
    x.length > 0 and !filter_regexp.some (r) -> x.match r
  non_optional = a.filter (x) ->
    !optional_filter_regexp.some (r) -> x.match r
  if non_optional.length > 0
    a = non_optional
  h.delete_duplicates a

cedict_merge_definitions = (rows) ->
  table = {}
  for [word, pinyin, glossary], i in rows
    key = word + "#" + pinyin
    if table[key]
      table[key][1][2] = h.delete_duplicates table[key][1][2].concat glossary
    else table[key] = [i, rows[i]]
  Object.values(table).sort((a, b) -> a[0] - b[0]).map((x) -> x[1])

cedict_overrides = (rows) ->
  overrides = h.read_csv_file "data/additional-translations.csv"
  overrides = overrides.map (r) -> [r[0], r[1], r.slice(2)]
  override_words = new Set overrides.map (r) -> r[0]
  base = rows.filter (r) -> not override_words.has r[0]
  base.concat overrides

filter_dictionary_data = (data, top_keep, short_word_length_limit, long_word_length_limit, cedict_excluded) ->
  piece_text_set = new Set (row[0] for row in data when row[0].length < short_word_length_limit)
  for row in data
    for ch in row[0]
      piece_text_set.add ch
  for piece_text in cedict_excluded
    if piece_text.length < short_word_length_limit
      piece_text_set.add piece_text
      for ch in piece_text
        piece_text_set.add ch
  piece_length_limit = short_word_length_limit - 1
  is_text_constructed = (text) ->
    text_length = text.length
    prefix_no_big = new Array(text_length + 1)
    prefix_has_big = new Array(text_length + 1)
    prefix_no_big[0] = true
    prefix_has_big[0] = false
    text_index = 1
    while text_index <= text_length
      prefix_no_big[text_index] = false
      prefix_has_big[text_index] = false
      piece_length = 1
      while piece_length <= piece_length_limit and piece_length <= text_index
        piece_text = text.slice text_index - piece_length, text_index
        if piece_text_set.has piece_text
          if piece_length >= 2
            prefix_has_big[text_index] = true if prefix_no_big[text_index - piece_length] or prefix_has_big[text_index - piece_length]
          else
            prefix_no_big[text_index] = true if prefix_no_big[text_index - piece_length]
            prefix_has_big[text_index] = true if prefix_has_big[text_index - piece_length]
        piece_length = piece_length + 1
      text_index = text_index + 1
    prefix_has_big[text_length]
  keep_row = (row, row_index) ->
    word_text = row[0]
    if word_text == "金融界"
      console.log row_index, row
    if row_index < top_keep then true else if word_text.length < short_word_length_limit then true else if word_text.length >= long_word_length_limit then false else not is_text_constructed word_text
  data.filter keep_row

update_cedict_filtered = () ->
  cedict = h.read_text_file "data/foreign/cedict_ts.u8"
  frequency_array = h.array_from_newline_file "data/subtlex-words-by-frequency.txt"
  frequency = {}
  frequency_array.forEach (a, i) -> frequency[a] = i
  short_word_length_limit = 4
  piece_keep = 20000
  rows = cedict.split "\n"
  raw_short_word_table = {}
  filtered_short_word_set = new Set
  data = rows.map (line) ->
    if "#" is line[0] then return null
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word_traditional = parsed[1]
    word = parsed[2]
    return null if word.match /[^\u4e00-\u9fff]/
    pinyin = parsed[3]
    pinyin = pinyin.split(" ").map (a) ->
      h.pinyin_utils.markToNumber(a).replace("u:", "ü").replace("35", "3").replace("45", "4").replace("25", "2")
    pinyin = pinyin.join("").toLowerCase()
    raw_frequency = frequency[word] || (word.length + frequency_array.length)
    if word.length < short_word_length_limit
      raw_short_word_table[word] = raw_frequency if raw_short_word_table[word] is undefined or raw_frequency < raw_short_word_table[word]
    glossary = cedict_glossary(parsed[4]).join("/")
    if glossary.length and word.length < short_word_length_limit
      filtered_short_word_set.add word
    line = [word_traditional, word, "[#{pinyin}]", "/#{glossary}/"].join(" ")
    filtered_frequency = raw_frequency
    [filtered_frequency, line, word, word_traditional] if glossary.length
  data = data.filter (a) -> a
  data = data.sort (a, b) -> a[0] - b[0]
  cedict_filtered_lines = data.map (a) -> a[1]
  cedict_filtered = cedict_filtered_lines.join "\n"
  fs.writeFile "data/cedict-filtered.u8", cedict_filtered, on_error
  cedict_excluded = Object.keys(raw_short_word_table).filter (word) -> not filtered_short_word_set.has word
  cedict_excluded = cedict_excluded.sort (a, b) -> raw_short_word_table[a] - raw_short_word_table[b]
  cedict_excluded = cedict_excluded.slice 0, piece_keep
  fs.writeFile "data/cedict-excluded.txt", cedict_excluded.join("\n"), on_error
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

update_cedict_csv = ->
  cedict = h.read_text_file "data/cedict-filtered.u8"
  frequency_index = get_word_frequency_index_with_pinyin()
  lines = cedict.split "\n"
  data = lines.map (line) ->
    return null if "#" is line[0]
    line = line.trim()
    parsed = line.match(/^([^ ]+) ([^ ]+) \[([^\]]+)\] \/(.*)\//)
    word = parsed[2]
    return null if word.match /[^\u4e00-\u9fff]/
    pinyin = parsed[3]
    pinyin = h.pinyin_split2(pinyin).map((s)-> h.pinyin_utils.markToNumber(s).replace("u:", "ü").replace("35","3").replace("45","4").replace("25","2")).join("").toLowerCase()
    glossary = cedict_glossary parsed[4]
    return null unless glossary.length
    [word, pinyin, glossary]
  data = data.filter (row) -> row
  data = cedict_merge_definitions data
  data = cedict_overrides data
  data = cedict_merge_definitions data
  data.forEach (row) -> row[2] = row[2].join "; "
  data = sort_by_word_frequency_with_pinyin frequency_index, 0, 1, data
  top_keep = 3000
  short_word_length_limit = 4
  long_word_length_limit = 999999
  cedict_excluded = h.array_from_newline_file "data/cedict-excluded.txt"
  data = filter_dictionary_data data, top_keep, short_word_length_limit, long_word_length_limit, cedict_excluded
  h.write_csv_file "data/cedict.csv", data

module.exports = {
  cedict_glossary
  cedict_merge_definitions
  update_cedict_filtered
  update_cedict_csv
}
