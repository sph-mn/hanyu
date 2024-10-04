dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

debounce = (func, wait, immediate = false) ->
  timeout = null
  ->
    context = this
    args = arguments
    later = ->
      timeout = null
      func.apply(context, args) unless immediate
    call_now = immediate and not timeout
    clearTimeout(timeout)
    timeout = setTimeout(later, wait)
    func.apply(context, args) if call_now

class app_class
  character_data: __character_data__
  reset: ->
    dom.input.value = ""
    dom.result.innerHTML = ""
  make_svg: (svg_paths) ->
    result = '<svg viewbox="0 0 1024 1024">'
    result += "<path d=\"#{a}\"/>" for a in svg_paths
    # create text elements while ensuring that they do not overlap with each other
    min_distance = 5
    placed_positions = []
    for path, index in svg_paths
      match = /M\s*(-?\d+\.?\d*),\s*(-?\d+\.?\d*)/.exec path
      continue unless match
      x = parseFloat match[1]
      y = parseFloat match[2]
      x += 3
      y -= 3
      is_overlapping = (current_x, current_y) ->
        for pos in placed_positions
          dx = current_x - pos[0]
          dy = current_y - pos[1]
          distance = Math.sqrt dx * dx + dy * dy
          return true if distance < min_distance
        false
      original_y = y
      offset_step = 10  # pixels to move vertically each attempt
      max_attempts = 10
      attempt = 0
      while is_overlapping(x, y) and attempt < max_attempts
        y += offset_step  # move the text down by offset_step pixels
        attempt += 1
      continue if is_overlapping x, y
      result += "<text x=\"#{x}\" y=\"#{y}\">#{index + 1}</text>"
      placed_positions.push [x, y]
    result + "</svg>"
  filter: =>
    dom.result.innerHTML = ""
    values = dom.input.value.split(",").map (a) -> a.trim()
    latin_values = []
    hanzi_values = []
    for a in values
      continue unless 0 < a.length
      if 2 < a.length && /[a-z0-9]/.test a
        latin_values.push a
      else
        if 1 < a.length then hanzi_values = hanzi_values.concat Array.from a
        else hanzi_values.push a
    return unless latin_values.length or hanzi_values.length
    matches = []
    for value in latin_values
      for data in @character_data
        matches.push data if data[2].startsWith value
    for value in hanzi_values
      data = @character_index[value]
      continue unless data
      [char, stroke_count, pinyin, compositions, decompositions, svg] = data
      unless dom.search_containing.checked || dom.search_contained.checked
        matches.push data
        continue
      if dom.search_containing.checked
        for decomposition in Array.from decompositions
          data = @character_index[decomposition]
          matches.push data if data
      if dom.search_contained.checked
        for composition in Array.from compositions
          data = @character_index[composition]
          matches.push data if data
    html = ""
    for data in matches
      [char, stroke_count, pinyin, compositions, decompositions, svg] = data
      if svg
        graphic = @make_svg svg
        html += "<div class=\"svg\">#{graphic}<div class=\"char\">#{char}</div><div class=\"pinyin\">#{pinyin}</div></div>"
      else
        html += "<div class=\"nosvg\"><div class=\"char\">#{char}</div><div class=\"stroke_count\">#{stroke_count}</div><div class=\"pinyin\">#{pinyin}</div></div>"
    dom.result.innerHTML = html || "no results"
  constructor: ->
    filter = debounce @filter, 250
    dom.input.addEventListener "keyup", filter
    dom.input.addEventListener "change", filter
    dom.search_contained.addEventListener "change", filter
    dom.search_containing.addEventListener "change", filter
    dom.about_link.addEventListener "click", -> dom.about.classList.toggle "hidden"
    dom.reset.addEventListener "click", @reset
    params = new URLSearchParams window.location.search
    param_input = params.get "input"
    dom.input.value = param_input if param_input
    @character_index = {}
    @character_index[data[0]] = data for data in @character_data
    @filter()

new app_class()
