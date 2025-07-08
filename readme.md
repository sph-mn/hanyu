# chinese language data and dictionary

# dictionary
dictionary that sorts results by word frequency and character count, with character stroke order lookup. the application is contained in a single file under compiled/ and also works offline. it is also hosted [here](https://sph.mn/other/chinese/tools/hanyu-dictionary.html).

# data files
see under data/
* words-by-frequency.csv
* words-by-frequency-with-pinyin.csv
* table-of-general-standard-chinese-characters.csv
* additional-characters.csv
* characters-strokes-decomposition.csv
* characters-pinyin-count.csv
* cedict.csv: filtered csv version of cedict with one translation per line
* hsk.csv: hsk 1-9
* words-by-frequency-with-pinyin-translation.csv
* hsk-pinyin-translation.csv
* characters-by-pinyin-learning.csv
* characters-by-pinyin-learning-rare.csv
* characters-by-pinyin.csv
* characters-by-pinyin-by-count.csv
* characters-by-pinyin-common.csv
* characters-overlap.csv
* characters-overlap-common.csv
* syllables-tones-character-counts.csv
* pinyin-learning.csv
* characters-learning.csv
* characters-learning-reduced.csv
* syllables-character-counts.csv
* syllables-tones-character-counts-common.csv
* extra-components.csv
* extra-stroke-counts.csv
* characters-strokes-decomposition-new.csv
* characters-composition.csv
* composition-hierarchy.txt
* words-by-type/
* characters-svg-animcjk-simple.json: contains svg for the individual strokes as simple lines and the directions of strokes
  * field 1: paths ordered by stroke order
  * field 2: direction vectors for each stroke
* anki decks
  * hanzi.apkg, character, words -> pinyin, example words with translation, components with pinyin
  * pinyin.apkg, pinyin -> word, translation
  * rares.apkg
* ... and [more](https://github.com/sph-mn/hanyu/tree/master/data)

# data sources
* [character decompositions](https://en.wiktionary.org)
* [character graphics](https://github.com/parsimonhi/animCJK)
* [chinese to english translations](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
* [hsk3 word list](https://github.com/krmanik/HSK-3.0-words-list/tree/main)
* [table of general standard chinese characters](https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters)
* [word frequency](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0010729#s2) SUBTLEX-CH

# license
creative commons share-alike

# development
* ./exe/update-dictionary to build html/hanyu-dictionary.html from html/hanyu-dictionary-template.html
  * update-characters-data collects the character data
  * update-svg-graphics regenerates the character svg graphics. it is usually with sub-commands "simplify_parallel" and then "merge" to merge result files from ./tmp to data/characters-svg-animcjk-simple.json.
* the main code file is js/main.coffee

# hanzi-convert
a command-line utility to convert text. at this point, some of the conversions might be quite slow.

convert from pinyin to hanzi:
~~~
echo fa1shao1 shi4 yin1 | ./exe/hanzi-convert --hanzi
发烧 是/事/试/市/式/室/世/仕/侍/势/嗜/噬/士/奭/弑/忕/恃/戺/拭/揓/柿/栻/氏/澨/示/筮/舐/莳/螫/视/誓/谥/贳/轼/逝/适/释/铈/饰/𬤊 因/阴/喑/垔/堙/姻/愔/慇/殷/氤/洇/瘖/禋/筃/茵/裀/铟/音/骃/𬘡/𬮱
~~~

alternatives are sorted by word frequency.

convert from hanzi to pinyin:
~~~
echo 发烧试音 | ./exe/hanzi-convert --pinyin
fa1shao1 shi4 yin1
~~~

convert traditional to simplified:
~~~
echo 發燒試音 | ./exe/hanzi-convert --simplify
发烧试音
~~~

convert marks to numbers:
~~~
echo fāshāo shì yīn | ./exe/hanzi-convert --numbers
fa1shao1 shi4 yin1
~~~
