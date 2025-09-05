h = require "./helper"

load_words_with_pinyin_translation = -> h.read_csv_file "data/words-by-frequency-with-pinyin-translation.csv"
load_words_with_pinyin = -> h.read_csv_file "data/words-by-frequency-with-pinyin.csv"
load_standard_characters_with_pinyin = -> h.read_csv_file("data/table-of-general-standard-chinese-characters.csv").map (row)->[row[0], row[1].split(",")[0]]
load_characters_strokes_decomposition = -> h.read_csv_file "data/characters-strokes-decomposition.csv"
load_cedict = -> h.read_csv_file "data/cedict.csv"

word_freq_index = (use_with_pinyin=false) ->
  word_rows = load_words_with_pinyin()
  index_map = {}
  word_rows.forEach (row, position_index) ->
    key_string = if use_with_pinyin then row[0] + row[1] else row[0]
    index_map[key_string] = position_index
  index_map

char_freq_index = ->
  character_lines = h.array_from_newline_file "data/subtlex-characters-by-frequency.txt"
  index_map = {}
  character_lines.forEach (character, position_index)-> index_map[character] = position_index
  index_map

stroke_count_index = ->
  character_rows = load_characters_strokes_decomposition()
  stroke_index_map = {}
  stroke_index_map[row[0]] = parseInt row[1],10 for row in character_rows
  stroke_index_map

full_decompositions_index = ->
  character_rows = load_characters_strokes_decomposition()
  immediate_decomposition_map = {}
  character_rows.forEach (row)-> immediate_decomposition_map[row[0]] = if row[2]? then row[2].split("") else []
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
  Object.keys(immediate_decomposition_map).forEach (character)-> full_decomposition_map[character] = expand_decomposition character
  full_decomposition_map

full_compositions_index = ->
  full_decomposition_map = full_decompositions_index()
  full_composition_map = {}
  Object.keys(full_decomposition_map).forEach (parent_character) ->
    full_decomposition_map[parent_character].forEach (child_character) ->
      (full_composition_map[child_character] ?= []).push parent_character
  Object.keys(full_composition_map).forEach (character)-> full_composition_map[character] = h.delete_duplicates_stable full_composition_map[character]
  full_composition_map

char_freq_dep_index = ->
  frequency_index_map = char_freq_index()
  characters_in_frequency_order = Object.keys(frequency_index_map).sort (a,b)-> frequency_index_map[a] - frequency_index_map[b]
  full_decomposition_map = full_decompositions_index()
  position_map = {}
  characters_in_frequency_order.forEach (character, position_index)-> position_map[character] = position_index
  position_index = 0
  while position_index < characters_in_frequency_order.length
    current_character = characters_in_frequency_order[position_index]
    dependency_list = full_decomposition_map[current_character] or []
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
  haracters_in_frequency_order.forEach (character, position_index)-> index_map[character] = position_index
  index_map

primary_pinyin = (character, word_limit=30000) ->
  word_rows_with_pinyin = load_words_with_pinyin().slice 0, word_limit
  pinyin_counts_map = {}
  word_rows_with_pinyin.forEach (row) ->
    word_text = row[0]
    return unless word_text.includes character
    character_list = h.split_chars word_text
    pinyin_syllable_list = h.pinyin_split2 row[1]
    return unless character_list.length == pinyin_syllable_list.length
    character_position_index = character_list.indexOf character
    return unless character_position_index >= 0
    pinyin_syllable = pinyin_syllable_list[character_position_index]
    pinyin_counts_map[pinyin_syllable] = (pinyin_counts_map[pinyin_syllable] or 0) + 1
  if Object.keys(pinyin_counts_map).length
    Object.keys(pinyin_counts_map).sort((a,b)-> pinyin_counts_map[b]-pinyin_counts_map[a] or a.localeCompare b)[0]
  else
    standard_row = load_standard_characters_with_pinyin().find (row)-> row[0] is character
    if standard_row then standard_row[1] else ""

top_examples = (target, limit_count) ->
  word_rows_with_translation = load_words_with_pinyin_translation()
  dictionary_map = {}
  word_rows_with_translation.forEach (row)-> dictionary_map[row[0]] = row
  if target.length > 1
    output_rows = []
    if dictionary_map[target]? then output_rows.push dictionary_map[target]
    word_rows_with_translation.forEach (row)-> if row[0].includes(target) and row[0] isnt target and output_rows.length < limit_count then output_rows.push row
    output_rows.slice 0,limit_count
  else
    output_rows = []
    if dictionary_map[target]? then output_rows.push dictionary_map[target]
    word_rows_with_translation.forEach (row)-> if row[0].includes(target) and row[0] isnt target and output_rows.length < limit_count then output_rows.push row
    output_rows.slice 0,limit_count

contains_map = ->
  full_decomposition_map = full_decompositions_index()
  stroke_index_map = stroke_count_index()
  contains_mapping = {}
  Object.keys(full_decomposition_map).forEach (parent_character) ->
    candidate_list = full_decomposition_map[parent_character].filter (component_character)-> component_character.length is 1
    candidate_list = candidate_list.filter (component_character)-> !stroke_index_map[component_character] or stroke_index_map[component_character] > 1
    contains_mapping[parent_character] = h.delete_duplicates_stable candidate_list
  contains_mapping

contained_by_map = ->
  full_composition_map = full_compositions_index()
  contained_by_mapping = {}
  Object.keys(full_composition_map).forEach (component_character)-> contained_by_mapping[component_character] = h.delete_duplicates_stable full_composition_map[component_character]
  contained_by_mapping

dictionary_index_word_f = (lookup_column_index) ->
  dictionary_map = {}
  load_cedict().forEach (row) -> h.object_array_add dictionary_map, row[lookup_column_index], row
  (key_string) -> dictionary_map[key_string]

dictionary_index_word_pinyin_f = ->
  dictionary_map = {}
  word_column_index = 0
  pinyin_column_index = 1
  rows = load_cedict()
  rows.forEach (row) ->
    word_text = row[word_column_index]
    key_string = row[word_column_index] + row[pinyin_column_index]
    h.object_array_add dictionary_map, key_string, row
    h.object_array_add dictionary_map, word_text, row
  (word_text, pinyin_text) -> dictionary_map[word_text + pinyin_text]

get_character_by_reading_index = ->
  character_pinyin_pairs = load_standard_characters_with_pinyin()
  reading_index_map = {}
  character_pinyin_pairs.forEach (pair) -> h.object_array_add reading_index_map, pair[1], pair[0]
  reading_index_map

module.exports =
  word_freq_index: word_freq_index
  char_freq_index: char_freq_index
  primary_pinyin: primary_pinyin
  char_freq_dep_index: char_freq_dep_index
  top_examples: top_examples
  contains_map: contains_map
  contained_by_map: contained_by_map
  stroke_count_index: stroke_count_index
  full_decompositions_index: full_decompositions_index
  full_compositions_index: full_compositions_index
  dictionary_index_word_f: dictionary_index_word_f
  dictionary_index_word_pinyin_f: dictionary_index_word_pinyin_f
  get_character_by_reading_index: get_character_by_reading_index
