# main.coffee
get_word_frequency_index = () ->
  frequency = h.array_from_newline_file "data/words-by-frequency.txt"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_word_frequency_index_with_pinyin = () ->
  frequency = h.array_from_newline_file "data/words-by-frequency-with-pinyin.csv"
  frequency_index = {}
  frequency.forEach (a, i) ->
    a = a.replace " ", ""
    frequency_index[a] = i unless frequency_index[a]
  frequency_index

get_all_standard_characters = () -> h.read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (a) -> a[0]

get_all_characters = () -> h.read_csv_file("data/characters-strokes-decomposition.csv").map (a) -> a[0]

display_all_characters = () -> console.log get_all_characters().join("")

get_character_pinyin_frequency_index = () ->
  result = {}
  index = 0
  chars = get_frequency_characters_and_pinyin()
  chars.forEach (a) ->
    key = a[0] + (a[1] || "")
    unless result[key]
      result[key] = index
      index += 1
  result

update_character_reading_count = () ->
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
  h.write_csv_file "data/characters-pinyin-count.csv", rows

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

class_for_tone = (tone) -> "tone#{tone}"

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
  font = h.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = h.read_text_file "src/character-tables-template.html"
  html = h.replace_placeholders html, {font, content, nav_links}
  for key, value of tables
    tables[key] = (b.reverse() for b in value)
  prelearn2 = []
  for a in prelearn
    for b in h.split_chars a[0]
      prelearn2.push [b, a[1]]
  h.write_csv_file "tmp/prelearn.csv", prelearn2

update_characters_by_pinyin_vertical = (rows) ->
  vertical_rows = format_lines_vertically rows
  fs.writeFileSync "data/characters-by-pinyin-by-count-vertical.csv", vertical_rows.join "\n"

sort_by_array_with_index = (a, sorting, index) ->
  a.sort (a, b) -> sorting.indexOf(a[index]) - sorting.indexOf(b[index])

get_character_syllables_tones_count_index = () ->
  result = {}
  h.read_csv_file("data/syllables-tones-character-counts.csv").forEach (a) -> result[a[0]] = parseInt a[1]
  result

sort_standard_character_readings = () ->
  reading_count_index = get_character_reading_count_index()
  path = "data/table-of-general-standard-chinese-characters.csv"
  rows = h.read_csv_file(path).map (a) ->
    char = a[0]
    pinyin = a[1].split(", ").map (a) -> if a.match(/[0-5]$/) then a else a + "5"
    pinyin = pinyin.sort (a, b) -> (reading_countindex[char + b] || 0) - (reading_count_index[char + a] || 0)
    a[1] = pinyin.join ", "
    a
  h.write_csv_file path, rows

sort_by_frequency = (data, char_key) -> data.sort sort_by_frequency_f char_key

update_syllables_character_count = () ->
  chars = h.read_csv_file("data/characters-by-pinyin.csv").map (a) -> [a[0], a[1].length]
  chars_without_tones = chars.map (a) -> [a[0].replace(/[0-5]/g, ""), a[1]]
  get_data = (chars) ->
    counts = {}
    chars.forEach (a) ->
      if counts[a[0]] then counts[a[0]] += a[1]
      else counts[a[0]] = a[1]
    chars = chars.map (a) -> a[0]
    chars = h.delete_duplicates_stable chars
    chars.map((a) -> [a, counts[a]]).sort (a, b) -> b[1] - a[1]
  h.write_csv_file "data/syllables-tones-character-counts.csv", get_data(chars)
  h.write_csv_file "data/syllables-character-counts.csv", get_data(chars_without_tones)

get_characters_contained_pinyin_rows = (exclusions = []) ->
  pinyin_index = get_character_pinyin_index()
  compositions_index = get_full_compositions_index()
  edges = []
  has_parent = new Set()
  for parent_char of compositions_index
    continue unless parent_char.match h.hanzi_regexp
    continue if exclusions.includes parent_char
    continue unless pinyin_index[parent_char]
    for child_char in compositions_index[parent_char] when child_char.match h.hanzi_regexp
      continue unless pinyin_index[child_char]
      edges.push [parent_char, child_char, pinyin_index[child_char]]
      has_parent.add child_char
  for parent_char of compositions_index when not has_parent.has parent_char
    continue unless parent_char.match h.hanzi_regexp
    continue if exclusions.includes parent_char
    continue unless pinyin_index[parent_char]
    edges.push [null, parent_char, pinyin_index[parent_char]]
  edges

get_characters_contained_rows = (exclusions = character_exclusions) ->
  compositions = get_compositions_index()
  rows = []
  for char of compositions when char.match(h.hanzi_regexp) and not exclusions.includes(char)
    rows.push [char, compositions[char]]
  rows.sort (a, b) -> a[1].length - b[1].length

update_characters_contained = ->
  rows = get_characters_contained_pinyin_rows()
  rows_gridlearner = get_characters_contained_pinyin_rows character_exclusions_gridlearner
  h.write_csv_file "data/gridlearner/characters-by-component.csv", rows_gridlearner
  rows = get_characters_contained_rows character_exclusions
  lines = (a[0] + " " + a[1].join("") for a in rows).join "\n"
  fs.writeFileSync "data/characters-contained.txt", lines
  rows = (a[0] + " " + get_char_decompositions(a[0]).join("") for a in rows)
  fs.writeFileSync "data/characters-containing.txt", rows.join "\n"

get_common_words_per_character = (max_words_per_char, max_frequency) ->
  character_frequency_index = get_character_frequency_index()
  get_character_example_words = get_character_example_words_f()
  standard_chars = h.read_csv_file "data/table-of-general-standard-chinese-characters.csv"
  chars = standard_chars.map (a) -> [a[0], a[1].split(", ")[0]]
  chars = sort_by_character_frequency character_frequency_index, 0, chars
  rows = for a in chars
    a = get_character_example_words a[0], a[1], max_frequency
    if 1 < a.length then a = a.slice 0, max_words_per_char
    a
  rows = rows.flat 1
  rows = h.array_deduplicate_key rows, (a) -> a[1]

update_word_frequency = ->
  buf = fs.readFileSync "/tmp/SUBTLEX-CH-WF"
  text = iconv.decode buf, "gb2312"
  lines = text.split "\n"
  words = []
  for line in lines when line.trim() and not line.startsWith("Word")
    parts = line.trim().split /\s+/
    word = parts[0]
    continue unless word.match /[\u4e00-\u9fff]/
    words.push word
  fs.writeFileSync "data/subtlex-words-by-frequency.txt", words.join "\n"

get_practice_words = (num_attempts, max_freq) ->
  word_frequency_index = get_word_frequency_index()
  characters = get_all_standard_characters()
  rows = h.read_csv_file "data/words-by-frequency-with-pinyin.csv"
  rows = rows.filter (a)->
    chars = h.split_chars a[0]
    chars.length > 1 && chars[0] != chars[1]
  candidate_words = {}
  for [w, p] in rows
    freq = word_frequency_index[w] || max_freq + 1
    continue if freq > max_freq
    for ch in h.split_chars w
      continue unless ch in characters
      (candidate_words[ch] ?= []).push [w,p,freq]
  characters = characters.filter (ch)-> candidate_words[ch]?
  for ch in characters
    candidate_words[ch].sort (a,b)-> a[2] - b[2]
  best_total_cost = Infinity
  best_assign = null
  for attempt in [0...num_attempts]
    order = h.array_shuffle characters.slice()
    counts = {}
    used_words = {}
    assign = {}
    run_cost = 0
    for ch in order
      opts = candidate_words[ch]
      best_score = Infinity
      chosen = null
      for [w,p,freq] in opts when not used_words[w]
        score = h.sum(counts[c] || 0 for c in w) + freq
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
  h.write_csv_file "data/practice-words.csv", rows

update_gridlearner_characters_by_pinyin = ->
  chars = get_all_characters_with_pinyin()
  batch_size = 300
  get_batch_index = (i) -> (1 + i / batch_size).toString().padStart 2, "0"
  for i in [0...chars.length] by batch_size
    data = ([a[0], a[1]] for a in chars[i...i + batch_size])
    ii = get_batch_index i
    h.write_csv_file "data/gridlearner/characters-pinyin-#{ii}.dsv", data

similar_initial = (s1, s2) ->
  pairs =
    c: "z", z: "c",
    j: "q", q: "j",
    k: "g", g: "k"
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
  pinyin_index = get_character_pinyin_index()
  tone_index   = get_character_tone_index()
  rows         = h.read_csv_file "data/gridlearner/characters-by-component.csv"
  by_component = {}
  rows.forEach ([component, carrier]) ->
    return unless component and carrier
    h.object_array_add by_component, component, carrier
  output_rows  = []
  for comp_char, carriers of by_component
    base_py = pinyin_index[comp_char]
    continue unless base_py
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
    dedup = h.delete_duplicates_stable
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
  h.write_csv_file "data/character-links.csv", output_rows

dsv_characters_add_pinyin = (character_index) ->
  pinyin_index = get_character_pinyin_index()
  rows = h.read_csv_file(0).map (a) ->
    pinyin = pinyin_index[a[character_index]]
    return a unless pinyin
    a.concat [pinyin]
  h.write_csv_file 1, rows

update_characters_series = ->
  rows = h.read_csv_file "data/gridlearner/characters-by-component.csv"
  graph = {}
  for [p,c] in rows
    h.object_array_add graph, p, c
  max_start_degree = 30
  memo = {}
  longest = (n) ->
    return memo[n] if memo[n]?
    kids = graph[n] or []
    return memo[n] = [[n]] unless kids.length
    memo[n] = ( [n].concat longest(k).reduce ((a,b)-> if b.length>a.length then b else a) ) for k in kids
  nodes = h.delete_duplicates_stable (rows.map((r)->r[0]).concat rows.map((r)->r[1]))
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

pinyin_to_hanzi = (text) ->
  cleaned = text.replace(h.non_pinyin_regexp, " ").trim()
  find_multiple_word_matches cleaned, 1, 0, h.pinyin_split2

hanzi_to_pinyin = (text) ->
  cleaned = text.replace(h.non_hanzi_regexp, " ").trim()
  find_multiple_word_matches cleaned, 0, 1, h.split_chars

find_multiple_word_matches = (text, lookup_index, translation_index, split_syllables_f) ->
  dictionary_lookup = dictionary_index_word_f lookup_index
  result_tokens = []
  text.split(" ").forEach (segment) ->
    syllables = split_syllables_f segment
    max_word_length = 5
    slice_join = (start_index, end_index) -> syllables.slice(start_index, end_index).join("")
    buld_spans_from = (start_index) ->
      end_limit = Math.min(start_index + max_word_length, syllables.length) + 1
      slice_join start_index, end_index for end_index in [(start_index + 1)...end_limit]
    candidate_spans_per_start = (build_spans_from start_index for start_index in [0...syllables.length])
    candidate_index = 0
    while candidate_index < candidate_spans_per_start.length
      matched_translations = []
      reversed_spans = candidate_spans_per_start[candidate_index].toReversed()
      reversed_index = 0
      while reversed_index < reversed_spans.length
        translations = dictionary_lookup reversed_spans[reversed_index]
        if translations
          matched_translations.push translations.map((row) -> row[translation_index]).join "/"
          break
        reversed_index += 1
      if matched_translations.length
        result_tokens.push matched_translations[0]
        candidate_index += reversed_spans.length - reversed_index
      else
        result_tokens.push candidate_spans_per_start[candidate_index][0]
        candidate_index += 1
  result_tokens.join " "

mark_to_number = (text) ->
  text.split(" ").map((token) -> h.pinyin_split2(token).map(pinyin_utils.markToNumber).join("")).join(" ")

update_pinyin_learning = () ->
  options =
    words_per_char: 3
    word_choices: 5
  character_frequency_index = lookup.char_freq_index()
  get_character_example_words = get_character_example_words_f()
  standard_chars = h.read_csv_file("data/table-of-general-standard-chinese-characters.csv")
  chars = standard_chars.map (a) -> [a[0], a[1].split(", ")[0]]
  chars = sort_by_character_frequency character_frequency_index, 0, chars
  rows = for a in chars
    a = get_character_example_words(a[0], a[1])
    if 1 < a.length then a = a.slice 1, options.words_per_char + 1
    [b[1], b[0], b[2]] for b in a
  rows = rows.flat 1
  rows = h.array_deduplicate_key rows,(a) -> a[1]
  add_word_choices = (rows) ->
    rows.map (a) ->
      tries = 30
      alternatives = [a[1]]
      while tries && alternatives.length < options.word_choices
        alternative = h.random_element rows
        if a[1].length == alternative[1].length && a[0] != alternative[0] && !alternatives.includes(alternative[1])
          alternatives.push alternative[1]
        tries -= 1
      a.push h.array_shuffle(alternatives).join(" ")
      a
  rows = add_sort_field add_word_choices rows
  h.write_csv_file "data/pinyin-learning.csv", rows

grade_text = (a) ->
  chars = h.delete_duplicates a.match h.hanzi_regexp
  frequency_index = lookup.char_freq_index()
  all_chars_count = Object.keys(frequency_index).length
  frequencies = chars.map((a) -> frequency_index[a] || all_chars_count).sort((a, b) -> a - b)
  count_score = chars.length / all_chars_count
  rarity_score = h.median(frequencies.splice(-10)) / all_chars_count
  Math.max 1, Math.round(10 * (count_score + rarity_score))

grade_text_files = (paths) ->
  paths.forEach (a) -> console.log grade_text(h.read_text_file(a)) + " " + node_path.basename(a)

clean_frequency_list = () ->
  frequency_array = h.array_from_newline_file "data/words-by-frequency.txt"
  frequency_array = frequency_array.filter (a) ->
    h.traditional_to_simplified h.remove_non_chinese_characters a
  frequency_array.forEach (a) -> console.log a
