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
    const row = [data[0], data[1]]
    let glossary = data[2].join("; ")
    glossary = "\"" + glossary.replace(/\"/g, "'") + "\""
    row.push(glossary)
    return row.join(" ")
  }

  function on_filter() {
    dom.results.innerHTML = ""
    const value = dom.input.value.trim()
    if (!value.length) return
    const matches = []
    if (/[a-z]/.test(value)) {
      const length_limit = value.length * (value.length > 4 ? 3 : 2)
      const regexp = new RegExp(value.replace(/u/g, "(u|ü)"))
      const translation_regexp = new RegExp("\\b" + value)
      for (let i = 0;
        (i < word_data.length && matches.length < result_limit); i += 1) {
        const entry = word_data[i]
        if (dom.search_translations.checked) {
          if (value.length > 2 && entry[2].some(a => translation_regexp.test(a))) {
            matches.push(make_result_line(entry))
          }
        } else if (length_limit >= entry[1].length && (regexp.test(entry[1]) || regexp.test(entry[1].replace(/[0-4]/g, "")))) {
          matches.push(make_result_line(entry))
        }
      }
    } else {
      let regexp
      if (!dom.search_split.checked) regexp = new RegExp(value)
      else {
        const characters = value.replace(/[^\u4E00-\u9FA5]/ig, "").split("")
        const words = []
        for (let i = 0; i < characters.length; i += 1) {
          for (let j = i + 1; j < Math.min(i + 5, characters.length) + 1; j += 1) {
            words.push(characters.slice(i, j).join(""))
          }
        }
        regexp = new RegExp("(^" + words.join("$)|(^") + "$)")
      }
      for (let i = 0;
        (i < word_data.length && matches.length < result_limit); i += 1) {
        if (regexp.test(word_data[i][0])) matches.push(make_result_line(word_data[i]))
      }
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
