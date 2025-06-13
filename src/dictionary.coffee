dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

debounce = (func, wait, immediate = false) ->
  timeout = null
  ->
    context = @
    args = arguments
    later = ->
      timeout = null
      func.apply context, args unless immediate
    call_now = immediate and not timeout
    clearTimeout timeout
    timeout = setTimeout later, wait
    func.apply context, args if call_now

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
unicode_ranges_regexp = (a, is_reject, regexp_flags) -> new RegExp unicode_ranges_pattern(a, is_reject), "u" + (regexp_flags || "")
non_hanzi_regexp = unicode_ranges_regexp hanzi_unicode_ranges, true
latin_regexp = /([a-z]+)([0-5])?$/i
delete_duplicates = (a) -> [...new Set(a)]
split_chars = (a) -> [...a]

class trie_node_class
  constructor: ->
    @children = {}
    @is_end_of_word = false

class trie_class
  constructor: -> @root = new trie_node_class()
  insert: (word) ->
    node = @root
    for char in word
      node = node.children[char] ?= new trie_node_class()
    node.is_end_of_word = true
  search: (word) ->
    node = @root
    for char in word
      return false unless node.children[char]?
      node = node.children[char]
    node.is_end_of_word

class character_search_class
  character_data: __character_data__
  default_matches_limit: 20
  is_syllable: (a) -> @syllable_trie.search a
  reset: ->
    dom.character_input.value = ""
    dom.character_results.innerHTML = ""
  make_svg: (svg_paths) ->
    result = '<svg viewbox="0 0 1024 1024">'
    result += "<path d=\"#{a}\"/>" for a in svg_paths
    # create text elements while ensuring that they do not overlap with each other
    min_distance = 5
    placed_positions = []
    for path, index in svg_paths
      match = /M\s*(-?\d+\.?\d*),\s*(-?\d+\.?\d*)/.exec path
      continue unless match
      x = parseFloat match[1]
      y = parseFloat match[2]
      x += 3
      y -= 3
      is_overlapping = (current_x, current_y) ->
        for pos in placed_positions
          dx = current_x - pos[0]
          dy = current_y - pos[1]
          distance = Math.sqrt dx * dx + dy * dy
          return true if distance < min_distance
        false
      original_y = y
      offset_step = 10  # pixels to move vertically each attempt
      max_attempts = 10
      attempt = 0
      while is_overlapping(x, y) and attempt < max_attempts
        y += offset_step  # move the text down by offset_step pixels
        attempt += 1
      continue if is_overlapping x, y
      result += "<text x=\"#{x}\" y=\"#{y}\">#{index + 1}</text>"
      placed_positions.push [x, y]
    result + "</svg>"
  filter: =>
    # support pinyin and characters, split at non-hanzi, sort frequent first, only use pinyin prefix
    dom.character_results.innerHTML = ""
    values = dom.character_input.value.split(",").map (a) -> a.trim()
    latin_values = []
    hanzi_values = []
    for a in values
      continue unless 0 < a.length
      if non_hanzi_regexp.test a
        continue unless 1 < a.length
        syllable = a.match latin_regexp
        continue unless syllable
        [_, syllable, tone] = syllable
        if @is_syllable syllable
          latin_values.push new RegExp "^" + syllable + (tone || "[0-5]")
      else
        if 1 < a.length then hanzi_values = hanzi_values.concat split_chars a
        else hanzi_values.push a
    return unless latin_values.length or hanzi_values.length
    latin_values = delete_duplicates latin_values
    hanzi_values = delete_duplicates hanzi_values
    matches = []
    for value in latin_values
      for data in @character_data
        matches.push data if value.test data[2]
    for value in hanzi_values
      data = @character_index[value]
      continue unless data
      [char, stroke_count, latin, compositions, decompositions, svg] = data
      unless dom.search_containing.checked || dom.search_contained.checked
        matches.push data
        continue
      if dom.search_containing.checked
        for decomposition in Array.from decompositions
          data = @character_index[decomposition]
          matches.push data if data
      if dom.search_contained.checked
        for composition in Array.from compositions
          data = @character_index[composition]
          matches.push data if data
    html = ""
    if matches.length
      for data in matches.slice 0, @matches_limit
        [char, stroke_count, latin, compositions, decompositions, svg_paths] = data
        if svg_paths
          svg = @make_svg svg_paths
          html += "<div>"
          html += "#{svg}<div class=\"m\"><div class=\"text_char\">#{char}</div><div class=\"latin\">#{latin}</div></div>"
          html += "</div>"
        else
          html += "<div class=\"nosvg\">"
          html += "<div class=\"text_char\">#{char}</div>"
          html += "<div class=\"m\"><div class=\"stroke_count\">#{stroke_count}</div><div class=\"latin\">#{latin}</div></div>"
          html += "</div>"
      if @matches_limit < matches.length
        html += "<div id=\"character_show_remaining\" class=\"link\">show #{matches.length - @matches_limit} more</div>"
      @matches_limit = @default_matches_limit
    dom.character_results.innerHTML = html || "no character results"
  constructor: (app) ->
    @matches_limit = @default_matches_limit
    filter_debounced = debounce @filter, 250
    dom.character_reset.addEventListener "click", @reset
    dom.character_input.addEventListener "keyup", filter_debounced
    dom.character_input.addEventListener "change", @filter
    dom.search_contained.addEventListener "change", @filter
    dom.search_containing.addEventListener "change", @filter
    param_input = app.url_params.get "character_input"
    dom.character_input.value = param_input if param_input
    @character_index = {}
    @character_index[data[0]] = data for data in @character_data
    dom.character_results.addEventListener "click", (event) =>
      # make a word search when clicking on character
      target = event.target
      if "character_show_remaining" == target.id
        @matches_limit = 1024
        @filter()
        return
      if target.classList.contains("text_char") && !target.parentNode.classList.contains("nosvg")
        char = target.innerHTML
        return if dom.word_input.value.includes char
        dom.word_input.value = char
        app.word_search.filter()
    syllables = [
      "a","ai","an","ang","ao","ba","bai","ban","bang","bao","bei","ben","beng","bi","bian","biang","biao","bie","bin","bing","bo","bu",
      "ca","cai","can","cang","cao","ce","cei","cen","ceng","cha","chai","chan","chang","chao","che","chen","cheng","chi","chong",
      "chou","chu","chua","chuai","chuan","chuang","chui","chun","chuo","ci","cong","cou","cu","cuan","cui","cun","cuo","da","dai","dan",
      "dang","dao","de","dei","den","deng","di","dian","diao","die","ding","diu","dong","dou","du","duan","dui","dun","duo","e","ei","en","eng","er",
      "fa","fan","fang","fei","fen","feng","fo","fou","fu","ga","gai","gan","gang","gao","ge","gei","gen","geng","gong","gou","gu","gua","guai",
      "guan","guang","gui","gun","guo","ha","hai","han","hang","hao","he","hei","hen","heng","hong","hou","hu","hua","huai","huan","huang",
      "hui","hun","huo","ji","jia","jian","jiang","jiao","jie","jin","jing","jiong","jiu","ju","juan","jue","jun","ka","kai","kan","kang",
      "kao","ke","kei","ken","keng","kong","kou","ku","kua","kuai","kuan","kuang","kui","kun","kuo","la","lai","lan","lang","lao","le","lei","leng",
      "li","lia","lian","liang","liao","lie","lin","ling","liu","lo","long","lou","lu","luan","lun","luo","lü","lüe","ma","mai","man","mang","mao",
      "me","mei","men","meng","mi","mian","miao","mie","min","ming","miu","mo","mou","mu","na","nai","nan","nang","nao","ne","nei","nen","neng","ni",
      "nian","niang","niao","nie","nin","ning","niu","nong","nou","nu","nuan","nuo","nü","nüe","o","ou","pa","pai","pan","pang","pao","pei","pen","peng",
      "pi","pian","piao","pie","pin","ping","po","pou","pu","qi","qia","qian","qiang","qiao","qie","qin","qing","qiong","qiu","qu","quan","que","qun",
      "ran","rang","rao","re","ren","reng","ri","rong","rou","ru","rua","ruan","rui","run","ruo","sa","sai","san","sang","sao","se","sen","seng",
      "sha","shai","shan","shang","shao","she","shei","shen","sheng","shi","shou","shu","shua","shuai","shuan","shuang","shui","shun",
      "shuo","si","song","sou","su","suan","sui","sun","suo","ta","tai","tan","tang","tao","te","teng","ti","tian","tiao","tie","ting","tong","tou",
      "tu","tuan","tui","tun","tuo","wa","wai","wan","wang","wei","wen","weng","wo","wu","xi","xia","xian","xiang","xiao","xie","xin","xing","xiong",
      "xiu","xu","xuan","xue","xun","ya","yan","yang","yao","ye","yi","yin","ying","yong","you","yu","yuan","yue","yun","za","zai","zan","zang",
      "zao","ze","zei","zen","zeng","zha","zhai","zhan","zhang","zhao","zhe","zhei","zhen","zheng","zhi","zhong","zhou","zhu","zhua","zhuai",
      "zhuan","zhuang","zhui","zhun","zhuo","zi","zong","zou","zu","zuan","zui","zun","zuo"
    ]
    @syllable_trie = new trie_class()
    @syllable_trie.insert a for a in syllables
    @filter()

class word_search_class
  word_data: __word_data__
  result_limit: 150
  make_result_html: (data) ->
    glossary = data[2].join "; "
    glossary = glossary.replace /\"/g, "'"
    attr = if data[0].length == 1 then " class=\"single\"" else ""
    "<div><span#{attr}>#{data[0]}</span> #{data[1]} \"#{glossary}\"</div>"
  reset: ->
    dom.word_input.value = ""
    dom.word_results.innerHTML = ""
  filter: =>
    values = dom.word_input.value.split(",").map (v) -> v.trim().toLowerCase()
    values = values.filter (v) -> v.length > 0
    unless values.length
      dom.word_results.innerHTML = ""
      return
    regexps = values.map (value) =>
      if dom.search_split.checked and !dom.search_translations.checked
        chars = Array.from value.replace /[^\u4E00-\u9FA5]/ig, ""
        words = new Set()
        i = 0
        while i < chars.length
          j = i + 1
          while j <= Math.min i + 5, chars.length
            words.add chars.slice(i, j).join ""
            j += 1
          i += 1
        words = Array.from(words).sort (a, b) -> b.length - a.length
        regexp = new RegExp "(^" + words.join("$)|(^") + "$)"
        (a) -> regexp.test a[0]
      else if /^[a-z0-9]/i.test value
        pattern = value.replace /v/g, "ü"
        if dom.search_translations.checked && value.length > 2
          regexp = new RegExp pattern, "i"
          (a) -> a[2].some (g) -> regexp.test g
        else
          length_limit = value.length * 2.5
          regexp = new RegExp "\\b" + pattern, "i"
          if /\d/.test pattern then (a) -> length_limit >= a[1].length && regexp.test a[1]
          else (a) -> length_limit >= a[1].length && regexp.test a[3]
      else unless dom.search_translations.checked
        regexp = new RegExp value
        (a) -> regexp.test a[0]
    .filter (f) -> f?
    matches = []
    for entry in @word_data
      break if matches.length >= @result_limit
      for fn in regexps
        if fn entry
          matches.push entry
          break
    if dom.search_split.checked
      matches.sort (a, b) -> b[0].length - a[0].length
    html = matches.map(@make_result_html).join ""
    dom.word_results.innerHTML = html or "no word results"
  constructor: (app) ->
    param = app.url_params.get "word_input"
    dom.word_input.value = param if param?
    filter_debounced = debounce @filter, 150
    dom.word_reset.addEventListener "click", @reset
    dom.word_input.addEventListener "keyup", filter_debounced
    dom.word_input.addEventListener "change", @filter
    dom.search_translations.addEventListener "change", @filter
    dom.search_split.addEventListener "change", @filter
    dom.word_results.addEventListener "click", (e) =>
      t = e.target
      if t.classList.contains "single"
        c = t.innerHTML
        unless dom.character_input.value.includes c
          dom.character_input.value += ", " + c
          app.character_search.filter()
    @filter

class app_class
  constructor: ->
    dom.toggle_search_type.checked = false
    dom.about_link.addEventListener "click", -> dom.about.classList.toggle "hidden"
    dom.about_link_close.addEventListener "click", -> dom.about.classList.toggle "hidden"
    dom.toggle_search_type.addEventListener "change", (event) -> dom.filter.classList.toggle "search_character_active"
    @url_params = new URLSearchParams window.location.search
    @character_search = new character_search_class @
    @word_search = new word_search_class @

new app_class()
