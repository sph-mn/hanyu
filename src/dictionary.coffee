dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

class app_class
  word_data: __word_data__
  result_limit: 150
  make_result_line: (data) ->
    glossary = '"' + data[2].join('; ').replace(/\"/g, '\'') + '"'
    "<span>#{data[0]}</span> #{data[1]} #{glossary}</br>"
  filter: =>
    dom.results.innerHTML = ""
    values = dom.input.value.split(",").map (a) -> a.trim()
    values = values.filter (a) -> a.length > 0
    return unless values.length
    matches = []
    regexps = values.map((value) ->
      if /[a-z0-9]/.test(value)
        if dom.search_translations.checked
          if value.length > 2
            regexp = new RegExp value.replace(/u/g, "(u|ü)")
            (entry) -> entry[2].some (a) -> regexp.test a
        else
          length_limit = value.length * (if value.length > 4 then 3 else 2)
          regexp = new RegExp("\\b" + value)
          return (entry) ->
            length_limit >= entry[1].length and (regexp.test(entry[1]) or regexp.test(entry[1].replace(/[0-4]/g, "")))
      else if !dom.search_translations.checked
        regexp = undefined
        if dom.search_split.checked
          characters = Array.from value.replace(/[^\u4E00-\u9FA5]/ig, "")
          words = []
          i = 0
          while i < characters.length
            j = i + 1
            while j < Math.min(i + 5, characters.length) + 1
              words.push characters.slice(i, j).join ""
              j += 1
            i += 1
          regexp = new RegExp("(^" + words.join("$)|(^") + "$)")
        else regexp = new RegExp value
        (entry) -> regexp.test entry[0]
    ).filter((a) -> a)
    for entry in @word_data
      break unless matches.length < @result_limit
      for matcher in regexps
        matches.push @make_result_line entry if matcher entry
    dom.results.innerHTML = if 0 == matches.length then "no word results" else matches.join ""
  reset: ->
    dom.input.value = ""
    dom.results.innerHTML = ""
  constructor: ->
    dom.reset.addEventListener "click", @reset
    dom.input.addEventListener "keyup", @filter
    dom.input.addEventListener "change", @filter
    dom.search_translations.addEventListener "change", @filter
    dom.search_split.addEventListener "change", @filter
    dom.about_link.addEventListener "click", -> dom.about.classList.toggle "hidden"

new app_class()
