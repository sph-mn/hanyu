# chinese language learning material

# dictionary
dictionary that sorts results by word frequency and character count. it is a single file, html/hanyu-dictionary.html, and needs to be served via http for the javascript to run in the browser. also hosted [here](http://sph.mn/other/chinese/hanyu-dictionary.html).

# data files
see under data/
* frequency-pinyin-translation.csv: words with pinyin and translation sorted by frequency
* cedict.csv: filtered csv version of cedict with one translation per line
* character-compositions.csv: characters split into components
* table-of-general-standard-chinese-characters.csv: the official character list including pronunciations
* characters-by-reading.txt
* words-by-type/: separated by verb, noun, adjective, and so on
* hsk.csv and hsk-pinyin-translations.csv
* character-learning.csv: characters sorted by frequency, with readings and number of words with this reading, false pronunciations for guessing and syllable commonness among all characters, compositions, character meaning, and example words
* ... and more

# data sources
* [word frequency](https://github.com/ernop/anki-chinese-word-frequency/blob/master/internet-zh.num)
* [chinese to english translations](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
* [hsk3 word list](https://github.com/krmanik/HSK-3.0-words-list/tree/main)
* [table of general standard chinese characters](https://en.wiktionary.org/wiki/Appendix:Table_of_General_Standard_Chinese_Characters)
* [character decompositions](https://en.wiktionary.org)

# license
creative commons share-alike

# development
* ./exe/update-dictionary to build html/hanyu-dictionary.html from html/hanyu-dictionary-template.html
* the main code file is js/main.coffee

# hanzi-convert
a command-line utility to convert text.

convert marks to numbers:
~~~
echo fāshāo shì yīn | ./exe/hanzi-convert --numbers
fa1shao1 shi4 yin1
~~~

convert traditional to simplified:
~~~
echo 發燒試音 | ./exe/hanzi-convert --simplify
发烧试音
~~~

convert from hanzi to pinyin:
~~~
echo 发烧试音 | ./exe/hanzi-convert --pinyin
fa1shao1 shi4 yin1
~~~

convert from pinyin to hanzi:
~~~
echo fa1shao1 shi4 yin1 | ./exe/hanzi-convert --hanzi
发烧 是/事/试/市/式/室/世/仕/侍/势/嗜/噬/士/奭/弑/忕/恃/戺/拭/揓/柿/栻/氏/澨/示/筮/舐/莳/螫/视/誓/谥/贳/轼/逝/适/释/铈/饰/𬤊 因/阴/喑/垔/堙/姻/愔/慇/殷/氤/洇/瘖/禋/筃/茵/裀/铟/音/骃/𬘡/𬮱
~~~

alternatives, like basically every output of this project, sorted by frequency.