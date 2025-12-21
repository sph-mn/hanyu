http =  require "https"

http_get = (url) ->
  new Promise (resolve, reject) ->
    http.get url, (response) ->
      data = []
      response.on "data", (a) -> data.push a
      response.on "end", () -> resolve Buffer.concat(data).toString()
      response.on "error", (error) -> reject error


get_wiktionary_data = (char) ->
  body = await http_get "https://en.wiktionary.org/wiki/#{char}"
  html = html_parser.parse body
  b = html.querySelectorAll "p"
  b = b.map (a) ->
    strokes = a.textContent.match /(\d+) stroke/
    strokes = strokes && parseInt(strokes[1], 10)
    decomposition = a.querySelector "a[title=\"w:Chinese character description languages\"]"
    if decomposition
      decomposition = decomposition.parentNode.parentNode.textContent
      decomposition = decomposition.match(/decomposition (.*)\)/)[1]
      decomposition = (decomposition.split(" or ")[0].match(hanzi_and_idc_regexp) || []).join("")
    [char, strokes, decomposition]
  b = b.filter (a) -> a[1] || a[2]
  b.flat()

sort_data = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/characters-strokes-decomposition-new.csv", chars

update_extra_stroke_counts = () ->
  data = read_csv_file "data/extra-components.csv"
  data = data.sort (a, b) -> b.length - a.length
  data = delete_duplicates_stable_with_key data, 0
  data = data.filter (a) -> a.length > 1
  data = data.map (a) -> [a[0], parseInt(a[1], 10)]
  data = data.sort (a, b) -> a[1] - b[1]
  write_csv_file "data/extra-stroke-counts.csv", data

update_decompositions = (start_index, end_index) ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.filter (a) -> "1" != a[1]
  chars = chars.slice start_index, end_index
  batch_size = 10
  batches_count = Math.ceil chars.length / batch_size
  batches = []
  i = 0
  while i < batches_count
    batches.push chars.slice i * batch_size, (i + 1) * batch_size
    i += 1
  batches.forEach (a) ->
    requests = Promise.all a.map (b) -> get_wiktionary_data b[0]
    requests.then (b) ->
      b.forEach (b, i) ->
        c = a[i]
        if (b[1] && b[1] != parseInt(c[1], 10)) || (b[2] && b[2].length >= c[2].length && b[2] != c[2])
          c[1] = b[1]
          c[2] = b[2]
          console.log c.join " "

add_new_data = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  new_data = read_csv_file("new-data").filter (a) -> a[0].length
  all = chars.concat new_data
  all_index = {}
  all.forEach (a) -> all_index[a[0]] = a
  all = Object.values(all_index).sort (a, b) -> a[1] - b[1] || a[0].localeCompare(b[0])
  write_csv_file "data/characters-strokes-decomposition-new.csv", all

find_component_repetitions = () ->
  chars = read_csv_file "data/characters-strokes-decomposition.csv"
  chars = chars.forEach (a) ->
    if a[2]
      b = a[2].replace non_hanzi_regexp, ""
      if 1 == delete_duplicates(split_chars(b)).length
        console.log a[0], b

update_characters_by_pinyin_learning = ->
  by_pinyin = {}
  chars = get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  chars.forEach (a) -> object_array_add(by_pinyin, a[1], a[0])
  rows = []
  for pinyin, chars_array of by_pinyin
    for character in chars_array
      rows.push [character, pinyin, chars_array.length]
  rows = rows.sort (a, b) -> (b[2] - a[2]) || a[1].localeCompare(b[1]) or a[0].localeCompare(b[0])
  rows = characters_add_learning_data rows
  write_csv_file("data/characters-by-pinyin-learning.csv", rows)
  rows = (a for a in rows.reverse() when a[2] < 3)
  write_csv_file("data/characters-by-pinyin-learning-rare.csv", rows)

to_fullwidth = (str) ->
  str.replace /./g, (char) ->
    code = char.charCodeAt 0
    if char is " "
      "　"
    else if code >= 33 and code <= 126
      String.fromCharCode(code - 33 + 65281)
    else
      char

format_lines_vertically = (rows) ->
  columns = rows.map ([syllable, chars]) -> [split_chars(to_fullwidth(syllable)), split_chars(to_fullwidth(chars))]
  syllable_max_height = Math.max.apply(null, columns.map (a) -> a[0].length)
  chars_max_height = Math.max.apply(null, columns.map (a) -> a[1].length)
  delimiter = "　"
  csv_lines = []
  for i in [0...syllable_max_height]
    row = columns.map (a) -> if a[0][i]? then a[0][i] else ""
    csv_lines.push row.join delimiter
  for i in [0...chars_max_height]
    row = columns.map (a) -> if a[1][i]? then a[1][i] else ""
    csv_lines.push row.join delimiter
  csv_lines

update_hsk = () ->
  files = fs.readdirSync "data/hsk"
  data = files.map (a) -> read_csv_file("data/hsk/#{a}", "\t")
  data = data.flat(1).map (a) ->
    pinyin = pinyin_split2(a[2]).map(pinyin_utils.markToNumber).join("").toLowerCase()
    [a[1], pinyin]
  write_csv_file "data/hsk.csv", data

update_hsk_pinyin_translations = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  rows = read_csv_file("data/hsk.csv").map (a) ->
    translations = dictionary_lookup a[0], a[1]
    return a unless translations
    a.concat [translations[0][2]]
  frequency_index = get_character_frequency_index()
  rows = rows.sort (a, b) ->
    chars_a = split_chars a[0]
    chars_b = split_chars b[0]
    max_a = Math.max.apply Math, chars_a.map (char) -> frequency_index[char]
    max_b = Math.max.apply Math, chars_b.map (char) -> frequency_index[char]
    max_a - max_b
  write_csv_file "data/hsk-pinyin-translation.csv", rows

dsv_add_example_words = () ->
  dictionary = dictionary_index_word_pinyin_f 0, 1
  words = read_csv_file "data/words-by-frequency-with-pinyin-translation.csv"
  rows = read_csv_file(0).map (a) ->
    char_words = words.filter((b) -> b[0].includes a[0])
    unless char_words.length
      char_words = dictionary(a[0], a[1]) || []
    a.push char_words.slice(0, 5).map((b) -> b.join(" ")).join("\n")
    a
  write_csv_file 0, rows

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

update_frequency_pinyin = () ->
  dictionary_lookup = dictionary_index_word_pinyin_f 0, 1
  frequency = array_from_newline_file "data/words-by-frequency.csv"
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
  write_csv_file "data/words-by-frequency-with-pinyin-translation.csv", rows
  rows = rows.map (a) -> [a[0], a[1]]
  write_csv_file "data/words-by-frequency-with-pinyin.csv", rows
