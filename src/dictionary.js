function word_search_init() {
  const dom = {
    input: document.getElementById("input"),
    button: document.getElementById("input-clear"),
    search_translations: document.getElementById("search-translations"),
    search_split: document.getElementById("search-split"),
    results: document.getElementById("results")
  }

  const word_data = __word_data__;
  const result_limit = 150

  function make_result_line(data) {
    const row = ["<span>" + data[0] + "</span>", data[1]]
    let glossary = data[2].join("; ")
    glossary = "\"" + glossary.replace(/\"/g, "'") + "\""
    row.push(glossary)
    return row.join(" ")
  }

  function on_filter() {
    dom.results.innerHTML = ""
    const values = dom.input.value.split(",").map(a => a.trim()).filter(a => a.length > 0)
    if (!values.length) return
    const matches = []
    const regexps = values.map(value => {
      if (/[a-z]/.test(value)) {
        // translations
        if (dom.search_translations.checked) {
          if (value.length > 2) {
            const regexp = new RegExp(value.replace(/u/g, "(u|ü)"))
            return (entry) => {return entry[2].some(a => regexp.test(a))}
          }
        }
        // pinyin
        else {
          const length_limit = value.length * (value.length > 4 ? 3 : 2)
          const regexp = new RegExp("\\b" + value)
          return (entry) => {
            return length_limit >= entry[1].length && (regexp.test(entry[1]) || regexp.test(entry[1].replace(/[0-4]/g, "")))
          }
        }
      } else if (!dom.search_translations.checked) {
        let regexp
        // hanzi split
        if (dom.search_split.checked) {
          const characters = value.replace(/[^\u4E00-\u9FA5]/ig, "").split("")
          const words = []
          for (let i = 0; i < characters.length; i += 1) {
            for (let j = i + 1; j < Math.min(i + 5, characters.length) + 1; j += 1) {
              words.push(characters.slice(i, j).join(""))
            }
          }
          regexp = new RegExp("(^" + words.join("$)|(^") + "$)")
        }
        // hanzi full
        else regexp = new RegExp(value)
        return (entry) => {return regexp.test(entry[0])}
      }
    }).filter(a => a)
    for (let i = 0; (i < word_data.length && matches.length < result_limit); i += 1) {
      regexps.forEach(matcher => {
        if (matcher(word_data[i])) matches.push(make_result_line(word_data[i]))
      })
    }
    dom.results.innerHTML = matches.join("<br/>")
    if (0 == matches.length) dom.results.innerHTML = "no word results"
  }
  function on_reset() {
    dom.input.value = ""
    dom.results.innerHTML = ""
  }
  dom.button.addEventListener("click", on_reset)
  dom.input.addEventListener("keyup", on_filter)
  dom.input.addEventListener("change", on_filter)
  dom.search_translations.addEventListener("change", on_filter)
  dom.search_split.addEventListener("change", on_filter)
}

word_search_init()
document.getElementById("about-link").addEventListener("click", () => document.getElementById("about").classList.toggle("hidden"))
