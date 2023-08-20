# chinese language learning material

# dictionary
single page dictionary that sorts results by word frequency and length. see download/ for the html file (needs to be hosted on a server for the javascript to run). also hosted here [sph.mn/other/chinese/hanyu-dictionary.html](http://sph.mn/other/chinese/hanyu-dictionary.html).

data sources:
* [word frequency](https://github.com/ernop/anki-chinese-word-frequency/blob/master/internet-zh.num)
* [chinese to english translations](https://www.mdbg.net/chinese/dictionary?page=cc-cedict)
* [hsk3 word list](https://github.com/krmanik/HSK-3.0-words-list/tree/main)

license: creative commons share-alike

development:
* ./exe/update-dictionary to build download/hanyu-dictionary.html from html/hanyu-dictionary-template.html
* the main code file is js/main.coffee

# data files
see under data/
* frequency-pinyin-translation.csv: words with pinyin and translation sorted by frequency
* cedict.csv: filtered csv version of cedict with one translation per line
* characters-by-reading.txt, and more

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