csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
coffee = require "coffeescript"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
html_parser = require "node-html-parser"
http =  require "https"
node_path = require "path"
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

get_word_frequency_index = () ->
  # -> {"#{word}#{pinyin}": integer}
  frequency = array_from_newline_file "data/words-by-frequency.txt"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_word_frequency_index_with_pinyin = () ->
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
  b = read_csv_file("data/additional-characters.csv").filter((a) -> !character_exclusions.includes(a[0])).map (a) -> [a[0], a[1].split(",")[0]]
  a.concat b
get_all_characters = () -> read_csv_file("data/characters-strokes-decomposition.csv").map (a) -> a[0]
display_all_characters = () -> console.log get_all_characters().join("")

get_all_characters_with_pinyin = () ->
  dict = dictionary_index_word_f 0
  result = []
  chars = {}
  for a in read_csv_file "data/table-of-general-standard-chinese-characters.csv"
    pinyin = a[1].split(", ")[0]
    chars[a[0]] = pinyin
  for a in read_csv_file "data/additional-characters.csv"
    chars[a[0]] = a[1]
  for a in read_csv_file "data/characters-strokes-decomposition.csv"
    pinyin = dict(a[0])?[0][1]
    chars[a[0]] = pinyin if pinyin && !chars[a[0]]
    continue if a.length < 3
    for b in split_chars(a[2])
      continue unless b.match hanzi_regexp
      pinyin = dict(b)?[0][1]
      chars[b] = pinyin if pinyin && !chars[b]
  data = ([a, b] for a, b of chars)
  char_index = split_chars read_text_file("data/characters-by-frequency.txt").trim()
  data.sort (a, b) ->
    ia = char_index.indexOf a[0]
    ib = char_index.indexOf b[0]
    (if ia is -1 then Infinity else ia) - (if ib is -1 then Infinity else ib)
  data

get_character_by_reading_index = () ->
  chars = get_all_characters_with_pinyin()
  result = {}
  chars.forEach (a) -> object_array_add result, a[1], a[0]
  result

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
  f = sort_by_character_f index
  (a, b) -> f a[character_key], b[character_key]

sort_by_character_f = (index) ->
  (a, b) ->
    ia = index[a]
    ib = index[b]
    if ia is undefined and ib is undefined
      (a.length - b.length) || a.localeCompare(b) || b.localeCompare(a)
    else if ia is undefined then 1
    else if ib is undefined then -1
    else ia - ib

sort_by_character_frequency = (frequency_index, character_key, data) ->
  data.sort sort_by_index_and_character_f frequency_index, character_key

sort_by_stroke_count = (stroke_count_index, character_key, data) ->
  data.sort sort_by_index_and_character_f stroke_count_index, character_key

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

sort_by_word_frequency = (frequency_index, word_key, data) ->
  data.sort (a, b) ->
    fa = frequency_index[a[word_key]]
    fb = frequency_index[b[word_key]]
    if fa is undefined and fb is undefined
      a[word_key].length - b[word_key].length
    else if fa is undefined
      1
    else if fb is undefined
      -1
    else
      fa - fb

dictionary_cedict_to_json = (data) ->
  JSON.stringify data.map (a) ->
    a[2] = a[2].split "/"
    a.push a[1].replace /[0-4]/g, ""
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
  frequency_array = array_from_newline_file "data/words-by-frequency.txt"
  frequency_array = frequency_array.filter (a) ->
    traditional_to_simplified remove_non_chinese_characters a
  frequency_array.forEach (a) -> console.log a

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

pinyin_to_hanzi = (a) ->
  a = a.replace(non_pinyin_regexp, " ").trim()
  find_multiple_word_matches a, 1, 0, pinyin_split2

hanzi_to_pinyin = (a) ->
  a = a.replace(non_hanzi_regexp, " ").trim()
  find_multiple_word_matches a, 0, 1, split_chars

get_character_pinyin_index = ->
  index = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> index[a[0]] = a[1].split(",")[0]
  index

get_character_tone_index = ->
  index = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> index[a[0]] = parseInt a[1][a[1].length - 1]
  index

get_characters_by_pinyin_rows = ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a]]
  rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length

all_syllables = """
a ai an ang ao ba bai ban bang bao bei ben beng bi bian biang biao bie bin bing bo bu
ca cai can cang cao ce cei cen ceng cha chai chan chang chao che chen cheng chi chong
chou chu chua chuai chuan chuang chui chun chuo ci cong cou cu cuan cui cun cuo da dai
dan dang dao de dei den deng di dian diao die ding diu dong dou du duan dui dun duo e ei
en eng er fa fan fang fei fen feng fo fou fu ga gai gan gang gao ge gei gen geng gong gou
gu gua guai guan guang gui gun guo ha hai han hang hao he hei hen heng hong hou hu hua
huai huan huang hui hun huo ji jia jian jiang jiao jie jin jing jiong jiu ju juan jue jun
ka kai kan kang kao ke kei ken keng kong kou ku kua kuai kuan kuang kui kun kuo la lai
lan lang lao le lei leng li lia lian liang liao lie lin ling liu lo long lou lu luan lun
luo lü lüe ma mai man mang mao me mei men meng mi mian miao mie min ming miu mo mou mu
na nai nan nang nao ne nei nen neng ni nian niang niao nie nin ning niu nong nou nu nuan
nuo nü nüe o ou pa pai pan pang pao pei pen peng pi pian piao pie pin ping po pou pu qi
qia qian qiang qiao qie qin qing qiong qiu qu quan que qun ran rang rao re ren reng ri
rong rou ru rua ruan rui run ruo sa sai san sang sao se sen seng sha shai shan shang shao
she shei shen sheng shi shou shu shua shuai shuan shuang shui shun shuo si song sou su
suan sui sun suo ta tai tan tang tao te teng ti tian tiao tie ting tong tou tu tuan tui
tun tuo wa wai wan wang wei wen weng wo wu xi xia xian xiang xiao xie xin xing xiong xiu
xu xuan xue xun ya yan yang yao ye yi yin ying yong you yu yuan yue yun za zai zan zang
zao ze zei zen zeng zha zhai zhan zhang zhao zhe zhei zhen zheng zhi zhong zhou zhu zhua
zhuai zhuan zhuang zhui zhun zhuo zi zong zou zu zuan zui zun zuo
""".split " "

circle_arrows = ["→","↗","↑","↖","←","↙","↓","↘"]

get_syllable_circle_arrow = (s) ->
  s = s.replace(/[0-5]$/, "")
  i = all_syllables.indexOf s
  circle_arrows[(Math.round(8 * i / all_syllables.length)) % 8]

class_for_tone = (tone) -> "tone#{tone}"

build_prelearn = ->
  prelearn = read_csv_file("/home/nonroot/chinese/1/lists/prelearn.csv").map (a) -> [a[0], a[1]]
  groups = {}
  for a in prelearn
    object_array_add groups, a[1], a[0]
  result = []
  for k, v of groups
    arrow = get_syllable_circle_arrow k
    result.push [k + arrow, v.join("")]
  result

build_pinyin_sets = ->
  rows = get_characters_by_pinyin_rows()
  flat = ([a[0], a[1].join("")] for a in rows)
  by_count = flat.slice().sort (a, b) -> a[1].length - b[1].length
  [flat, by_count]

build_contained = (tone_index, pinyin_index) ->
  rows = get_characters_contained_rows()
  ([a[0], ([c, tone_index[c]] for c in a[1])] for a in rows)

render_row = ([label, data]) ->
  if typeof data is "string"
    "<b><b>#{label}</b><b>#{data}</b></b>"
  else
    "<b><b>#{label}</b><b>#{data}</b></b>"
    #chars = data.map ([c, t]) -> "<b class=\"#{class_for_tone t}\">#{c}</b>"
    #"<b><b>#{label}</b><b>#{chars.join("")}</b></b>"

update_character_tables_html = (tables) ->
  nav_links = []
  i = 0
  make_table = (rows, name) ->
    nav_links.push "<a href=\"#\" data-target=\"#{i}\">#{name}</a>"
    i += 1
    "<div class=\"#{name}\">" + (rows.map render_row).join("\n") + "</div>"
  content = (make_table v, k for k, v of tables).join "\n"
  [content, nav_links.join("\n")]

get_characters_by_pinyin_rows_flat = ->
  result = []
  for a in get_characters_by_pinyin_rows()
    for b in a[1]
      result.push [a[0], b]
  result

update_character_tables = ->
  tone_index = get_character_tone_index()
  pinyin_index = get_character_pinyin_index()
  [pinyin, pinyin_by_count] = build_pinyin_sets()
  prelearn = build_prelearn()
  contained = build_contained tone_index, pinyin_index
  tables =
    pinyin: pinyin
    contained: contained
    pinyin_by_count: pinyin_by_count
    prelearn: prelearn
  [content, nav_links] = update_character_tables_html tables
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/character-tables-template.html"
  html = replace_placeholders html, {font, content, nav_links}
  for key, value of tables
    tables[key] = (b.reverse() for b in value)
  prelearn2 = []
  for a in prelearn
    for b in split_chars a[0]
      prelearn2.push [b, a[1]]
  write_csv_file "tmp/prelearn.csv", prelearn2

update_characters_by_pinyin_vertical = (rows) ->
  vertical_rows = format_lines_vertically rows
  fs.writeFileSync "data/characters-by-pinyin-by-count-vertical.csv", vertical_rows.join "\n"

update_characters_by_pinyin = () ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add by_pinyin, a[1], a[0]
  rows = Object.keys(by_pinyin).map (a) -> [a, by_pinyin[a].join("")]
  rows = rows.sort (a, b) -> a[0].localeCompare(b[0]) || b[1].length - a[1].length
  write_csv_file "data/characters-by-pinyin.csv", rows
  rows = rows.sort (a, b) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  write_csv_file "data/characters-by-pinyin-by-count.csv", rows
  #rows = rows.filter (a) -> a[1].length < 4
  #rows = rows.sort (b, a) -> b[1].length - a[1].length || a[0].localeCompare(b[0])
  #write_csv_file "data/characters-by-pinyin-rare.csv", rows
  rare_rows = []
  for p in Object.keys(by_pinyin)
    if by_pinyin[p].length < 3
      for c in by_pinyin[p]
        rare_rows.push [c, p]
  rare_rows = rare_rows.sort (a, b) -> a[1].localeCompare(b[1]) || a[0].localeCompare(b[0])
  write_csv_file "data/characters-pinyin-rare.csv", rare_rows

sort_by_array_with_index = (a, sorting, index) ->
  a.sort (a, b) -> sorting.indexOf(a[index]) - sorting.indexOf(b[index])

index_key_value = (a, key_key, value_key) ->
  b = {}
  a.forEach (a) -> b[a[key_key]] = a[value_key]
  b

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
  frequency_sorter = sort_by_character_f get_character_frequency_index()
  for a, b of compositions
    compositions[a] = b.sort frequency_sorter
  compositions

get_full_compositions_index = ->
  full_decompositions = get_full_decompositions()
  compositions = {}
  for [char, components] in full_decompositions
    for component in components
      c = compositions[component]
      if c
        unless c.includes char
          c.push char
      else
        compositions[component] = [char]
  frequency_sorter = sort_by_character_f get_character_frequency_index()
  for component, chars of compositions
    compositions[component] = chars.sort frequency_sorter
  compositions

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

characters_add_learning_data = (rows, allowed_chars = null) ->
  reading_count_index        = get_character_reading_count_index()
  character_by_reading_index = get_character_by_reading_index()
  get_character_example_words = get_character_example_words_f()
  compositions_index = get_compositions_index()
  pinyin_index = get_character_pinyin_index()
  dictionary_lookup = dictionary_index_word_f 0
  primary_pinyin = (c) -> pinyin_index[c] ? (dictionary_lookup(c)?[0][1])
  rows = array_deduplicate_key rows, (r) -> r[0]
  max_same = 16
  max_containing = 5
  in_scope = (c) -> (not allowed_chars?) or allowed_chars.has c
  add_same_reading = (rows) ->
    rows.map (r) ->
      chars = (character_by_reading_index[r[1]] or []).filter(in_scope).slice 0, max_same
      chars = chars.filter (c) -> c isnt r[0]
      r.push chars.join ""
      r
  add_contained = (rows) ->
    rows.map (r) ->
      comps = get_char_decompositions(r[0]).map (x) -> x[0]
      comps = comps.filter(in_scope)
      formatted = comps
        .map (c) -> pp = primary_pinyin c; if pp then "#{c} #{pp}" else null
        .filter Boolean
      r.push formatted.join ", "
      r
  add_containing = (rows) ->
    rows.map (r) ->
      carriers = (compositions_index[r[0]] or []).filter(in_scope).slice 0, max_containing
      formatted = carriers
        .map (c) -> pp = primary_pinyin c; if pp then "#{c} #{pp}" else null
        .filter Boolean
      r.push formatted.join ", "
      r
  add_examples = (rows) ->
    rows.map (r) ->
      words = get_character_example_words r[0], r[1]
      if words.length && r[0] == words[0][0]
        char_word = words[0]
        words = words.slice(1, 5)
      else
        char_word = null
        words = words
      r.push words.map((w) -> w[0]).join " "
      r.push words.concat(if char_word then [char_word] else []).map((w) -> w.join " ").join "\n"
      r
  add_reading_classification = (rows) ->
    rows.map (r) ->
      reading = r[1]
      chars = (character_by_reading_index[reading] or []).filter(in_scope)
      if chars.length == 1 then label = "unique"
      else if chars.length <= 3 then label ="rare"
      else label = ""
      r.push label
      r
  rows = add_contained rows
  rows = add_containing rows
  rows = add_same_reading rows
  rows = add_sort_field rows
  rows = add_examples rows
  rows = add_reading_classification rows
  rows

fix_dependency_order = (items, char_key) ->
  di = get_full_decompositions_index()
  pm = {}
  for i, a of items
    pm[a[char_key]] = i
  i = 0
  while i < items.length
    c = items[i][char_key]
    deps = di[c] or []
    for d in deps
      j = pm[d]
      if j? and j > i
        dep = items.splice(j, 1)[0]
        items.splice(i, 0, dep)
        for k in [Math.min(i, j)..Math.max(i, j)]
          pm[items[k][char_key]] = k
        # stay at same i to recheck moved-in deps
        i -= 1
        break
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
  data

update_characters_learning = ->
  all_rows = get_all_standard_characters_with_pinyin()
  all_rows = sort_by_frequency_and_dependency all_rows, 0
  mid      = Math.ceil all_rows.length / 2
  first    = all_rows.slice 0, mid
  second   = all_rows.slice mid
  first_set = new Set first.map (r) -> r[0]
  first_out  = characters_add_learning_data first, first_set
  second_out = characters_add_learning_data second
  write_set = (rows, suffix) ->
    base = "data/characters-learning"
    write_csv_file "#{base}#{suffix}.csv", rows
    reduced = ([i + 1, r[0], r[1], r[5], r[3]] for r, i in rows)
    write_csv_file "#{base}-reduced#{suffix}.csv", reduced
  write_set first_out, ""
  write_set second_out, "-extended"

update_syllables_character_count = () ->
  # number of characters with the same reading
  chars = read_csv_file("data/characters-by-pinyin.csv").map (a) -> [a[0], a[1].length]
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

grade_text_files = (paths) ->
  paths.forEach (a) -> console.log grade_text(read_text_file(a)) + " " + node_path.basename(a)

grade_text = (a) ->
  chars = delete_duplicates a.match hanzi_regexp
  frequency_index = get_character_frequency_index()
  all_chars_count = Object.keys(frequency_index).length
  frequencies = chars.map((a) -> frequency_index[a] || all_chars_count).sort((a, b) -> a - b)
  count_score = chars.length / all_chars_count
  rarity_score = median(frequencies.splice(-10)) / all_chars_count
  Math.max 1, Math.round(10 * (count_score + rarity_score))

character_exclusions_gridlearner = "灬罒彳𠂉⺈辶卝埶冃丏卝宀冖亠䒑丅丷一亅⿻㇀乚丨丿⿰�丶㇒㇏⿹乛㇓㇈⿸乀㇍⿺㇋㇂㇊丆⺊ユ⿾⿶⿵⿴⿲コ凵⿳⿽㇌⿷囗㇎㇅㇄厸䶹乛㇓㇈㇅㇄㇈一亅㇀ 乚丨丿丶㇒㇏㇇乛㇓乀㇍㇂㇊丆二⺊卜十冂ユコ㇄㇅㇎㇌乜㇋厸丫䶹凵囗乁"
character_exclusions = "⿱丅丷一亅⿻㇀乚丨丿⿰�丶㇒㇏⿹乛㇓㇈⿸乀㇍⿺㇋㇂㇊丆⺊ユ⿾⿶⿵⿴⿲コ凵⿳⿽㇌⿷囗㇎㇅㇄厸䶹乛㇓㇈㇅㇄㇈一亅㇀ 乚丨丿丶㇒㇏㇇乛㇓乀㇍㇂㇊丆二⺊卜十冂ユコ㇄㇅㇎㇌乜㇋厸丫䶹凵囗乁"

get_characters_contained_pinyin_rows = (exclusions = []) ->
  pinyin_index = get_character_pinyin_index()
  compositions_index = get_full_compositions_index()
  edges = []
  has_parent = new Set()
  for parent_char of compositions_index
    continue unless parent_char.match hanzi_regexp
    continue if exclusions.includes parent_char
    continue unless pinyin_index[parent_char]
    for child_char in compositions_index[parent_char] when child_char.match hanzi_regexp
      continue unless pinyin_index[child_char]
      edges.push [parent_char, child_char, pinyin_index[child_char]]
      has_parent.add child_char
  for parent_char of compositions_index when not has_parent.has parent_char
    continue unless parent_char.match hanzi_regexp
    continue if exclusions.includes parent_char
    continue unless pinyin_index[parent_char]
    edges.push [null, parent_char, pinyin_index[parent_char]]
  edges

get_characters_contained_rows = (exclusions = character_exclusions) ->
  compositions = get_compositions_index()
  rows = []
  for char of compositions when char.match(hanzi_regexp) and not exclusions.includes(char)
    rows.push [char, compositions[char]]
  rows.sort (a, b) -> a[1].length - b[1].length

update_characters_contained = ->
  rows = get_characters_contained_pinyin_rows()
  rows_gridlearner = get_characters_contained_pinyin_rows character_exclusions_gridlearner
  write_csv_file "data/gridlearner/characters-by-component.csv", rows_gridlearner
  rows = get_characters_contained_rows character_exclusions
  lines = (a[0] + " " + a[1].join("") for a in rows).join "\n"
  fs.writeFileSync "data/characters-contained.txt", lines
  rows = (a[0] + " " + get_char_decompositions(a[0]).join("") for a in rows)
  fs.writeFileSync "data/characters-containing.txt", rows.join "\n"

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

is_file = (path) -> fs.statSync(path).isFile()
strip_extensions = (filename) -> filename.replace /\.[^.]+$/, ''

update_lists = (paths) ->
  nav_links = []
  paths = (a for a in paths when is_file a)
  content = for path, i in paths
    rows = read_csv_file path
    parts = for row in rows
      [head, tail...] = row
      tail = tail.join " "
      """
      <b><b>#{head}</b><b>#{tail}</b></b>
      """
    label = strip_extensions node_path.basename path
    nav_links.push """
       <a href="#" data-target="#{i}">#{label}</a>
    """
    "<div>" + parts.join("\n") + "</div>"
  content = content.join "\n"
  nav_links = nav_links.join "\n"
  font = read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = read_text_file "src/lists-template.html"
  html = replace_placeholders html, {font, content, nav_links}
  fs.writeFileSync "tmp/lists.html", html

iconv = require "iconv-lite"

update_character_frequency = ->
  buf = fs.readFileSync "/tmp/SUBTLEX-CH-CHR"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  chars = []
  for line in lines when line.trim() and not line.startsWith("Character") and not line.startsWith("Total")
    parts = line.trim().split /\s+/
    chr = parts[0]
    if chr.length is 1
      chars.push chr
  fs.writeFileSync "data/characters-by-frequency.txt", chars.join ""

update_word_frequency = ->
  buf = fs.readFileSync "/tmp/SUBTLEX-CH-WF"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  words = []
  for line in lines when line.trim() and not line.startsWith("Word")
    parts = line.trim().split /\s+/
    word = parts[0]
    continue unless word.match /[\u4e00-\u9fff]/  # skip PUA and non-CJK
    words.push word
  fs.writeFileSync "data/words-by-frequency.txt", words.join "\n"

update_word_frequency_pinyin = ->
  words = array_from_newline_file "data/words-by-frequency.txt"
  dict = dictionary_index_word_f 0
  result = for word in words
    entry = dict word
    continue unless entry
    pinyin = entry[0][1]
    [word, pinyin]
  write_csv_file "data/words-by-frequency-with-pinyin.csv", result

get_practice_words = (num_attempts, max_freq) ->
  # get a list of the most frequent words where each character ideally appears
  #   only once and no word appears twice.
  word_frequency_index = get_word_frequency_index()
  characters = get_all_standard_characters()
  rows = read_csv_file "data/words-by-frequency-with-pinyin.csv"
  rows = rows.filter (a)->
    chars = split_chars a[0]
    chars.length > 1 && chars[0] != chars[1]
  candidate_words = {}
  for [w, p] in rows
    freq = word_frequency_index[w] || max_freq + 1
    continue if freq > max_freq
    for ch in split_chars w
      continue unless ch in characters
      (candidate_words[ch] ?= []).push [w,p,freq]
  characters = characters.filter (ch)-> candidate_words[ch]?
  for ch in characters
    candidate_words[ch].sort (a,b)-> a[2] - b[2]
  best_total_cost = Infinity
  best_assign = null
  for attempt in [0...num_attempts]
    order = array_shuffle characters.slice()
    counts = {}
    used_words = {}
    assign = {}
    run_cost = 0
    for ch in order
      opts = candidate_words[ch]
      best_score = Infinity
      chosen = null
      for [w,p,freq] in opts when not used_words[w]
        score = sum(counts[c] || 0 for c in w) + freq
        if score < best_score or (score is best_score and Math.random() < 0.5)
          best_score = score
          chosen = [w,p,freq]
      continue unless chosen?
      assign[ch] = chosen
      used_words[chosen[0]] = true
      counts[c] = (counts[c] || 0) + 1 for c in chosen[0]
      run_cost += best_score
    if run_cost < best_total_cost
      best_total_cost = run_cost
      best_assign = assign
  words = ([x[0],x[1]] for ch,x of best_assign)
  sort_by_word_frequency word_frequency_index, 0, words

update_practice_words = ->
  rows = get_practice_words 1000, Infinity
  write_csv_file "data/practice-words.csv", rows

update_gridlearner_characters_by_pinyin = ->
  chars = get_all_characters_with_pinyin()
  batch_size = 300
  get_batch_index = (i) -> (1 + i / batch_size).toString().padStart 2, "0"
  for i in [0...chars.length] by batch_size
    data = ([a[0], a[1]] for a in chars[i...i + batch_size])
    ii = get_batch_index i
    write_csv_file "data/gridlearner/characters-pinyin-#{ii}.dsv", data

update_gridlearner_data = ->
  all_rows = sort_by_frequency_and_dependency get_all_standard_characters_with_pinyin(), 0
  mid = Math.ceil all_rows.length / 2
  top4000 = new Set all_rows.slice(0, mid).map (r) -> r[0]
  top8000 = new Set all_rows.map (r) -> r[0]
  pin_idx = get_character_pinyin_index()
  full_comps = get_full_compositions_index()
  full_decomps = get_full_decompositions_index()
  dedup_stable = (a) -> delete_duplicates_stable a
  excluded = new Set split_chars character_exclusions_gridlearner
  ok_char = (c) -> typeof c is "string" and c.length is 1 and c.match(hanzi_regexp) and not excluded.has c
  contained_rows = (pool) ->
    out = []
    pool.forEach (parent) ->
      return unless ok_char parent
      comps = full_decomps[parent] or []
      for child in comps when ok_char child
        py = pin_idx[child] ? "-"
        out.push [parent, child, py]
    dedup_stable out
  containing_rows = (pool) ->
    out = []
    for comp, parents of full_comps when ok_char comp
      for parent in parents when pool.has(parent) and ok_char parent
        py = pin_idx[parent] ? "-"
        out.push [comp, parent, py]
    dedup_stable out
  by_pinyin_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok_char c
      py = pin_idx[c]
      return unless py
      (groups[py] ?= []).push c
    order = Object.keys(groups).sort (a, b) -> groups[b].length - groups[a].length or a.localeCompare b
    rows = []
    order.forEach (py) -> groups[py].forEach (c) -> rows.push [py, c, py]
    rows
  by_syllable_rows = (pool) ->
    groups = {}
    pool.forEach (c) ->
      return unless ok_char c
      py = pin_idx[c]
      return unless py
      syl = py.replace /[0-5]$/, ""
      (groups[syl] ?= []).push [c, py]
    order = Object.keys(groups).sort (a, b) -> groups[b].length - groups[a].length or a.localeCompare b
    rows = []
    order.forEach (syl) -> groups[syl].forEach ([c, py]) -> rows.push [syl, c, py]
    rows
  write = (tag, rows) -> write_csv_file "data/gridlearner/characters-#{tag}.csv", rows
  #write "top4000-contained",   contained_rows  top4000
  write "top4000-containing",  containing_rows top4000
  write "top4000-by-pinyin",   by_pinyin_rows  top4000
  write "top4000-by-syllable", by_syllable_rows top4000
  #write "top8000-contained",   contained_rows  top8000
  write "top8000-containing",  containing_rows top8000
  write "top8000-by-pinyin",   by_pinyin_rows  top8000
  write "top8000-by-syllable", by_syllable_rows top8000
  unique_rows = (pool) ->
    counts = {}
    pool.forEach (ch) ->
      py = pin_idx[ch]
      return unless py?
      counts[py] = (counts[py] or 0) + 1
    rows = []
    pool.forEach (ch) ->
      py = pin_idx[ch]
      return unless py?
      return unless counts[py] is 1
      rows.push [ch, py]
    rows.sort (a, b) -> a[1].localeCompare(b[1]) or a[0].localeCompare(b[0])
  write "top4000-unique", unique_rows top4000
  write "top8000-unique", unique_rows top8000

update_characters_series = ->
  rows = read_csv_file "data/gridlearner/characters-by-component.csv"
  graph = {}
  for [p,c] in rows
    object_array_add graph, p, c
  max_start_degree = 30
  memo = {}
  longest = (n) ->
    return memo[n] if memo[n]?
    kids = graph[n] or []
    return memo[n] = [[n]] unless kids.length
    memo[n] = ( [n].concat longest(k).reduce ((a,b)-> if b.length>a.length then b else a) ) for k in kids
  nodes = delete_duplicates_stable (rows.map((r)->r[0]).concat rows.map((r)->r[1]))
  chains = []
  for n in nodes when (graph[n]?.length||0) and graph[n].length <= max_start_degree
    chains = chains.concat longest n
  seen = new Set()
  uniq = []
  for ch in chains when ch.length > 2
    id = ch.join ""
    continue if seen.has id
    uniq.push ch
    seen.add id
  sub = (a,b)-> b.join("").includes a.join("")
  uniq = uniq.filter (c)-> not uniq.some (d)-> d isnt c and d.length>c.length and sub c,d
  uniq = uniq.sort (a,b)-> b.length - a.length
  fs.writeFileSync "data/characters-series.txt", uniq.map((c)->c.join "").join "\n"

similar_initial = (s1, s2) ->
  pairs =
    c: "z", z: "c",
    j: "q", q: "j",
    k: "g", g: "k"
  # quick-n-dirty initial extractor good enough for the pairs above
  initial = (s) ->
    if s.startsWith("zh") or s.startsWith("ch") or s.startsWith("sh")
      s.slice 0, 2
    else s[0]
  i1 = initial s1
  i2 = initial s2
  r1 = s1.slice i1.length
  r2 = s2.slice i2.length
  (pairs[i1] is i2) and (r1 is r2)

update_characters_links = ->
  pinyin_index = get_character_pinyin_index()   # {char → "xx4"}
  tone_index   = get_character_tone_index()     # {char → 4}
  rows         = read_csv_file "data/gridlearner/characters-by-component.csv"
  by_component = {}
  rows.forEach ([component, carrier]) ->
    return unless component and carrier
    object_array_add by_component, component, carrier
  output_rows  = []
  for comp_char, carriers of by_component
    base_py = pinyin_index[comp_char]
    continue unless base_py          # skip if the component itself lacks a reading
    base_py      = base_py.split(",")[0]
    base_syl     = base_py.replace /[0-5]$/, ""
    base_tone    = parseInt base_py.slice(-1), 10
    tone_syll    = []
    tone_only    = []
    syl_only     = []
    init_links   = []
    carriers.forEach (c) ->
      return if c is comp_char
      cp = pinyin_index[c]
      return unless cp
      cp     = cp.split(",")[0]
      c_syl  = cp.replace /[0-5]$/, ""
      c_tone = parseInt cp.slice(-1), 10
      if cp is base_py then tone_syll.push c
      else if c_tone is base_tone then tone_only.push c
      else if c_syl is base_syl then syl_only.push c
      else if similar_initial base_syl, c_syl then init_links.push c
    dedup = delete_duplicates_stable
    [tone_syll, tone_only, syl_only, init_links] =
      (dedup lst for lst in [tone_syll, tone_only, syl_only, init_links])
    if tone_syll.length or tone_only.length or syl_only.length or init_links.length
      output_rows.push [
        comp_char,
        tone_syll.join(""),
        syl_only.join(""),
        tone_only.join(""),
        init_links.join("")
      ]
  write_csv_file "data/character-links.csv", output_rows


dsv_characters_add_pinyin = (character_index) ->
  pinyin_index = get_character_pinyin_index() # {char → "xx4"}
  rows = read_csv_file(0).map (a) ->
    pinyin = pinyin_index[a[character_index]]
    return a unless pinyin
    a.concat [pinyin]
  write_csv_file 1, rows

run = ->
  dsv_characters_add_pinyin 0
  #update_gridlearner_data()
  #update_characters_links()
  #find_longest_containment_chains()
  #collect_characters_by_syllable_containment()

module.exports = {
  read_text_file
  get_characters_by_pinyin_rows
  clean_frequency_list
  replace_placeholders
  object_array_add
  get_all_characters_with_pinyin
  update_dictionary
  update_characters_data
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
  update_lists
}
