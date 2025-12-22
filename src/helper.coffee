csv_parse = require "csv-parse/sync"
csv_stringify = require "csv-stringify/sync"
coffee = require "coffeescript"
fs = require "fs"
hanzi_tools = require "hanzi-tools"
pinyin_utils = require "pinyin-utils"
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
simplified_to_traditional = (a) -> hanzi_tools.traditionalize a
pinyin_split2 = (a) -> a.replace(/[0-5]/g, (a) -> a + " ").trim().split " "
median = (a) -> a.slice().sort((a, b) -> a - b)[Math.floor(a.length / 2)]
sum = (a) -> a.reduce ((a, b) -> a + b), 0
mean = (a) -> sum(a) / a.length
object_array_add = (object, key, value) -> if object[key] then object[key].push value else object[key] = [value]
object_array_add_unique = (object, key, value) ->
  if object[key] then object[key].push value unless object[key].includes value
  else object[key] = [value]
array_intersection = (a, b) -> a.filter (a) -> b.includes(a)
compact = (a) -> a.filter (b) -> b

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

hanzi_unicode_ranges = [
  # https://en.wiktionary.org/wiki/Appendix:Unicode
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

unicode_ranges_pattern = (a, is_reject) -> "[" + (if is_reject then "^" else "") + a.map((a) -> a.map((b) -> "\\u{#{b}}").join("-")).join("") + "]"
unicode_ranges_regexp = (a, is_reject) -> new RegExp unicode_ranges_pattern(a, is_reject), "gu"
hanzi_regexp = unicode_ranges_regexp hanzi_unicode_ranges
non_hanzi_regexp = unicode_ranges_regexp hanzi_unicode_ranges, true
hanzi_and_idc_regexp = unicode_ranges_regexp hanzi_unicode_ranges.concat([["2FF0", "2FFF"]])
non_pinyin_regexp = /[^a-z0-5]/g
is_file = (path) -> fs.statSync(path).isFile()
strip_extensions = (filename) -> filename.replace /\.[^.]+$/, ''

normalize_mapping = do ->
  mapping1 = read_csv_file "data/characters-traditional.csv"
  mapping2 = read_csv_file "data/characters-nonstandard.csv"
  mapping3 = {}
  mapping3[a] = b for [a, b] in mapping1.concat mapping2
  mapping = {}
  mapping[a] = mapping3[b] or b for a, b of mapping3
  mapping

normalize_character = (c) -> normalize_mapping[c] || c

normalize_text = (text) ->
  out = ""
  out += normalize_mapping[c] or c for i, c of text
  out

module.exports = {
  all_syllables
  read_text_file
  read_csv_file
  replace_placeholders
  array_from_newline_file
  delete_duplicates
  split_chars
  random_integer
  random_element
  normalize_character
  normalize_text
  n_times
  remove_non_chinese_characters
  traditional_to_simplified
  simplified_to_traditional
  pinyin_split2
  median
  sum
  mean
  compact
  object_array_add
  object_array_add_unique
  array_intersection
  write_csv_file
  delete_duplicates_stable
  delete_duplicates_stable_with_key
  lcg
  array_shuffle
  array_deduplicate_key
  unicode_ranges_regexp
  hanzi_regexp
  non_hanzi_regexp
  non_pinyin_regexp
  hanzi_and_idc_regexp
  pinyin_utils
  is_file
  strip_extensions
}
