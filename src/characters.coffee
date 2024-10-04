dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

class app_class
  character_data: __character_data__
  reset: ->
    dom.input.value = ""
    dom.result.innerHTML = ""
  make_svg: (svg_paths) ->
    result = '<svg viewbox="0 0 1024 1024">'
    for a in svg_paths
      result += "<path d=\"#{a}\"/>"
    for a, i in svg_paths
      match = /M(\d+),(\d+)/.exec a
      continue unless match
      x = parseInt match[1], 10
      y = parseInt match[2], 10
      x += 10
      y -= 10
      result += "<text x=\"#{x}\" y=\"#{y}\">#{i + 1}</text>"
    result + "</svg>"
  filter: =>
    console.log "filter"
    dom.result.innerHTML = ""
    values = dom.input.value.split("").filter (a) -> a.length > 0
    return unless values.length
    results = []
    for char in values
      data = @character_data[char]
      continue unless data
      [stroke_count, compositions, decompositions, svg] = data
      if dom.search_containing.checked
        for decomposition in Array.from decompositions
          data = @character_data[decomposition]
          results.push data if data
      if dom.search_contained.checked
        for composition in Array.from compositions
          data = @character_data[composition]
          results.push data if data
      unless dom.search_containing.checked || dom.search_contained.checked
        results.push data
    html = ""
    for data in results
      [stroke_count, compositions, decompositions, svg] = data
      graphic = if svg then @make_svg svg else "#{char} #{stroke_count}"
      html += "<div>#{graphic}</div>"
    dom.result.innerHTML = html || "no results"
  constructor: ->
    dom.input.addEventListener "keyup", @filter
    dom.input.addEventListener "change", @filter
    dom.search_contained.addEventListener "change", @filter
    dom.search_containing.addEventListener "change", @filter
    dom.about_link.addEventListener "click", -> dom.about.classList.toggle "hidden"
    params = new URLSearchParams window.location.search
    param_input = params.get "input"
    dom.input.value = param_input if param_input
    @filter()

new app_class()
