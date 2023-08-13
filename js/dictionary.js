function word_search_init() {
  const word_data = __word_data__;

  function make_search_regexp(word) {
    if ("\"" == word[0]) return RegExp(word.replace("\"", ""))
    return new RegExp(word.replace(/u/g, "(u|ü)"))
  }

  function make_result_line(data) {
    const row = [data[0], data[1]]
    let glossary = data[2].join("; ")
    glossary = "\"" + glossary.replace(/\"/g, "'") + "\""
    row.push(glossary)
    return row.join(" ")
  }

  const input = document.getElementById("word-input")
  const button = document.getElementById("word-reset")
  const checkbox_search_translations = document.getElementById("search-translations")
  const checkbox_search_split = document.getElementById("search-split")
  const results = document.getElementById("word-results")
  const result_limit = 150
  const abc_regexp = /[a-z]/

  function on_filter() {
    results.innerHTML = ""
    const value = input.value.trim()
    if (0 == value.length) return
    const search_translations = checkbox_search_translations.checked
    const matches = []
    if (abc_regexp.test(value)) {
      const translation_regexp = new RegExp("\\b" + value)
      var regexp = make_search_regexp(value)
      const length_limit = value.length * (value.length > 4 ? 3 : 2)
      for (let i = 0; (i < word_data.length && matches.length < result_limit); i += 1) {
        const entry = word_data[i]
        if (search_translations) {
          if (value.length > 2 && entry[2].some(a => translation_regexp.test(a))) {
            matches.push(make_result_line(entry))
          }
        }
        else if (length_limit >= entry[1].length && (regexp.test(entry[1]) || regexp.test(entry[1].replace(/[0-4]/g, "")))) {
          matches.push(make_result_line(entry))
        }
      }
    } else {
      if (search_translations) return
      const search_split = checkbox_search_split.checked
      if (search_split) {
        const characters = value.replace(/[^\u4E00-\u9FA5]/ig, "").split("")
        const words = []
        for (var i = 0; i < characters.length; i += 1) {
          for (let j = i + 1; j < Math.min(i + 5, characters.length) + 1; j += 1) {
            words.push(characters.slice(i, j).join(""))
          }
        }
        var regexp = new RegExp("(^" + words.join("$)|(^") + "$)")
      } else var regexp = new RegExp(value)
      for (var i = 0; (i < word_data.length && matches.length < result_limit); i += 1) {
        if (regexp.test(word_data[i][0])) matches.push(make_result_line(word_data[i]))
      }
    }
    results.innerHTML = matches.join("<br/>")
    if (0 == matches.length) results.innerHTML = "no word results"
  }

  function on_reset() {
    input.value = ""
    results.innerHTML = ""
  }
  input.addEventListener("keyup", on_filter)
  input.addEventListener("change", on_filter)
  button.addEventListener("click", on_reset)
  checkbox_search_translations.addEventListener("change", on_filter)
  checkbox_search_split.addEventListener("change", on_filter)
}

function about_init() {
  const about = document.getElementById("about")
  document.getElementById("about-link").addEventListener("click", () => about.classList.toggle("hidden"))
}
word_search_init()
about_init()
