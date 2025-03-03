# chinese language data and dictionary

# dictionary
dictionary that sorts results by word frequency and character count, with character stroke order lookup. the application is contained in a single file under compiled/ and also works offline. it is also hosted [here](http://sph.mn/other/chinese/hanyu-dictionary.html).

# data files
see under data/
* frequency-pinyin-translation.csv: words with pinyin and translation sorted by frequency
* cedict.csv: filtered csv version of cedict with one translation per line
* characters-strokes-decomposition.csv: characters with stroke count and composition
* table-of-general-standard-chinese-characters.csv: the official character list including pronunciations
* characters-by-pinyin.csv
* words-by-type/: separated by verb, noun, adjective, and so on
* hsk.csv and hsk-pinyin-translations.csv
* characters-learning.csv: characters sorted by frequency, with readings and number of words with this reading, false pronunciations for guessing and syllable commonness among all characters, compositions, character meaning, and example words. suitable as the basis for an anki deck
* pinyin-learning.csv: a reverse version of characters-learning that maps word pinyin and choices to word and translation
* characters-repeated-components.csv: characters that consist of a repetition of another character
* hanzi.apkg, pinyin.apkg: anki decks based on characters-learning.csv and pinyin-learning.csv
* characters-svg-animcjk-simple.json: contains svg for the individual strokes as simple lines and the directions of strokes
  * field 1: paths ordered by stroke order
  * field 2: direction vectors for each stroke
* ... and more

# data sources
* [character decompositions](https://en.wiktionary.org)
* [character graphics](https://github.com/parsimonhi/animCJK)
* [chinese to english translations](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
* [hsk3 word list](https://github.com/krmanik/HSK-3.0-words-list/tree/main)
* [table of general standard chinese characters](https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters)
* [word frequency](https://github.com/ernop/anki-chinese-word-frequency/blob/master/internet-zh.num)

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
