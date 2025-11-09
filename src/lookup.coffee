h = require "./helper"

load_words_with_pinyin_translation = -> h.read_csv_file "data/words-by-frequency-with-pinyin-translation.csv"
load_words_with_pinyin = -> h.read_csv_file "data/words-by-frequency-with-pinyin.csv"
load_standard_characters_with_pinyin = -> h.read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (row)->[row[0], row[1].split(",")[0]]
load_characters_strokes_decomposition = -> h.read_csv_file "data/characters-strokes-decomposition.csv"
load_cedict = -> h.read_csv_file "data/cedict.csv"

make_dictionary_index_word_f = (lookup_column_index) ->
  rows = load_cedict()
  dictionary_map = {}
  rows.forEach (row) -> h.object_array_add dictionary_map, row[lookup_column_index], row
  f = (key_string) -> dictionary_map[key_string]
  f.dictionary_map = dictionary_map
  f

make_dictionary_index_word_pinyin_f = ->
  rows = load_cedict()
  dictionary_map = {}
  word_column_index = 0
  pinyin_column_index = 1
  rows.forEach (row) ->
    word_text = row[word_column_index]
    key_string = row[word_column_index] + row[pinyin_column_index]
    h.object_array_add dictionary_map, key_string, row
    h.object_array_add dictionary_map, word_text, row
  f = (word_text, pinyin_text) -> dictionary_map[word_text + pinyin_text]
  f.dictionary_map = dictionary_map
  f

make_word_freq_index_f = (use_with_pinyin=false) ->
  rows = load_words_with_pinyin()
  index_map = {}
  rows.forEach (row, position_index) ->
    key_string = if use_with_pinyin then row[0] + row[1] else row[0]
    index_map[key_string] = position_index
  f = (key_string) -> index_map[key_string]
  f.index_map = index_map
  f

make_char_freq_index_f = ->
  character_lines = h.array_from_newline_file "data/subtlex-characters-by-frequency.txt"
  index_map = {}
  character_lines.forEach (character, position_index) -> index_map[character] = position_index
  f = (character) -> index_map[character]
  f.index_map = index_map
  f

make_stroke_count_index_f = ->
  character_rows = load_characters_strokes_decomposition()
  stroke_index_map = {}
  stroke_index_map[row[0]] = parseInt row[1],10 for row in character_rows
  f = (character) -> stroke_index_map[character]
  f.index_map = stroke_index_map
  f

make_full_decompositions_index_f = ->
  character_rows = load_characters_strokes_decomposition()
  immediate_decomposition_map = {}
  character_rows.forEach (row) -> immediate_decomposition_map[row[0]] = if row[2]? then row[2].split("") else []
  recursion_cache_map = {}
  expand_decomposition = (character) ->
    return recursion_cache_map[character] if recursion_cache_map[character]?
    component_list = immediate_decomposition_map[character] or []
    aggregate_list = []
    component_list.forEach (component_character) ->
      aggregate_list = aggregate_list.concat [component_character].concat expand_decomposition component_character
    recursion_cache_map[character] = h.delete_duplicates aggregate_list
    recursion_cache_map[character]
  full_decomposition_map = {}
  Object.keys(immediate_decomposition_map).forEach (character) -> full_decomposition_map[character] = expand_decomposition character
  f = (character) -> full_decomposition_map[character] or []
  f.index_map = full_decomposition_map
  f

make_full_compositions_index_f = ->
  full_decompositions_f = make_full_decompositions_index_f()
  full_decomposition_map = full_decompositions_f.index_map
  full_composition_map = {}
  Object.keys(full_decomposition_map).forEach (parent_character) ->
    full_decomposition_map[parent_character].forEach (child_character) ->
      (full_composition_map[child_character] ?= []).push parent_character
  Object.keys(full_composition_map).forEach (character) -> full_composition_map[character] = h.delete_duplicates_stable full_composition_map[character]
  f = (component_character) -> full_composition_map[component_character] or []
  f.index_map = full_composition_map
  f

make_char_freq_dep_index_f = ->
  char_freq_f = make_char_freq_index_f()
  characters_in_frequency_order = Object.keys(char_freq_f.index_map).sort (a, b) -> char_freq_f.index_map[a] - char_freq_f.index_map[b]
  full_decompositions_f = make_full_decompositions_index_f()
  position_map = {}
  characters_in_frequency_order.forEach (character, position_index) -> position_map[character] = position_index
  position_index = 0
  while position_index < characters_in_frequency_order.length
    current_character = characters_in_frequency_order[position_index]
    dependency_list = full_decompositions_f current_character
    moved_flag = false
    dependency_list.forEach (dependency_character) ->
      dependency_position_index = position_map[dependency_character]
      if dependency_position_index? and dependency_position_index > position_index
        removed_list = characters_in_frequency_order.splice dependency_position_index,1
        characters_in_frequency_order.splice position_index,0,removed_list[0]
        lower_index = Math.min position_index, dependency_position_index
        upper_index = Math.max position_index, dependency_position_index
        for range_index in [lower_index..upper_index] then position_map[characters_in_frequency_order[range_index]] = range_index
        moved_flag = true
    if moved_flag then position_index = Math.max 0, position_index - 1 else position_index += 1
  index_map = {}
  characters_in_frequency_order.forEach (character, position_index) -> index_map[character] = position_index
  f = (character) -> index_map[character]
  f.index_map = index_map
  f

make_char_freq_dep_index_from_file_f = ->
  file_path = "data/characters-by-frequency-dependency.csv"
  index_map = {}
  if h.is_file file_path
    rows = h.read_csv_file file_path
    rows.forEach (row, i) -> index_map[row[0]] = i
  f = (character) -> index_map[character]
  f.index_map = index_map
  f

make_primary_pinyin_f = ->
  build_wordlist_map = ->
    result = {}
    rows = load_words_with_pinyin()
    rows.forEach (row, frequency_index) ->
      word_text = row[0]
      pinyin_text = row[1]
      character_list = h.split_chars word_text
      pinyin_list = h.pinyin_split2 pinyin_text
      return unless character_list.length == pinyin_list.length
      for character, position_index in character_list
        pinyin = pinyin_list[position_index]
        continue if pinyin.endsWith "5"
        result[character] ?= {}
        h.object_array_add result[character], pinyin, frequency_index
    result
  build_wordlist_map2 = (wordlist_map) ->
    score = (indices) ->
      sorted = indices[..].sort((a,b) -> a - b)
      k = 3
      s = 0
      i = 0
      while i < k and i < sorted.length
        s = s + sorted[i]
        i = i + 1
      s / i
    result = {}
    for character, readings of wordlist_map
      best = null
      best_score = Infinity
      for pinyin, indices of readings
        r = score(indices)
        if r < best_score
          best_score = r
          best = pinyin
      result[character] = best
    result
  build_standard_map = ->
    result = {}
    rows = load_standard_characters_with_pinyin()
    rows.forEach (row) -> result[row[0]] = row[1]
    result
  build_additional_map = ->
    result = {}
    rows = h.read_csv_file "data/additional-characters.csv"
    rows.forEach (row) ->
      character = row[0]
      pinyin = row[1]
      return unless character? and pinyin?
      result[character] = pinyin
    result
  wordlist_map = build_wordlist_map2 build_wordlist_map()
  standard_map = build_standard_map()
  additional_map = build_additional_map()
  cache = {}
  f = (character) ->
    value = cache[character]
    return value if value
    if additional_map[character]
      value = additional_map[character]
    else
      value = wordlist_map[character]
      value = standard_map[character] unless value
    cache[character] = value
    value
  f

make_contains_map_f = ->
  full_decompositions_f = make_full_decompositions_index_f()
  stroke_count_f = make_stroke_count_index_f()
  contains_mapping = {}
  Object.keys(full_decompositions_f.index_map).forEach (parent_character) ->
    candidate_list = full_decompositions_f parent_character
    candidate_list = candidate_list.filter (component_character) -> component_character.length is 1
    candidate_list = candidate_list.filter (component_character) -> not stroke_count_f(component_character) or stroke_count_f(component_character) > 1
    contains_mapping[parent_character] = h.delete_duplicates_stable candidate_list
  f = (character) -> contains_mapping[character] or []
  f.index_map = contains_mapping
  f

make_contained_by_map_f = ->
  full_compositions_f = make_full_compositions_index_f()
  f = (component_character) -> full_compositions_f component_character
  f.index_map = full_compositions_f.index_map
  f

make_char_decompositions_f = (primary_pinyin_f=make_primary_pinyin_f()) ->
  full_decompositions_f = make_full_decompositions_index_f()
  stroke_count_f = make_stroke_count_index_f()
  cache = {}
  f = (character) ->
    v = cache[character]
    return v if v?
    parts = full_decompositions_f character
    parts = parts.filter (c) -> not stroke_count_f(c) or stroke_count_f(c) > 1
    out = parts.map((c) -> [c, primary_pinyin_f(c)]).filter (r) -> r[1]
    cache[character] = out
    out
  f

make_top_examples_f = ->
  single_position_begin = true
  rows = load_words_with_pinyin_translation()
  char_word_map = {}
  contains_map_local = {}
  rows.forEach (row) ->
    word_text = row[0]
    if word_text.length is 1 then char_word_map[word_text] = row
    else h.delete_duplicates(h.split_chars word_text).forEach (character) -> (contains_map_local[character] ?= []).push row
  cache = {}
  f = (character, max_list_len) ->
    v = cache[character]
    unless v?
      list = contains_map_local[character] or []
      cache[character] = list
      v = list
    result = if max_list_len? and max_list_len >= 0 then v.slice 0, max_list_len else v
    char_row = char_word_map[character]
    if char_row?
      if single_position_begin then result = [char_row].concat result
      else result = result.concat [char_row]
    result
  f

make_char_by_reading_index_f = ->
  pairs = load_standard_characters_with_pinyin()
  reading_index_map = {}
  pairs.forEach (pair) -> h.object_array_add reading_index_map, pair[1], pair[0]
  f = (reading) -> reading_index_map[reading] or []
  f.index_map = reading_index_map
  f

module.exports = {
  make_dictionary_index_word_f
  make_dictionary_index_word_pinyin_f
  make_word_freq_index_f
  make_char_freq_index_f
  make_stroke_count_index_f
  make_full_decompositions_index_f
  make_full_compositions_index_f
  make_char_freq_dep_index_f
  make_char_freq_dep_index_from_file_f
  make_primary_pinyin_f
  make_char_decompositions_f
  make_top_examples_f
  make_char_by_reading_index_f
  make_contains_map_f
  make_contained_by_map_f
}
