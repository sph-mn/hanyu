dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

class app_class
  character_data: __character_data__
  reset: ->
    dom.input.value = ""
    dom.result.innerHTML = ""
  make_svg: (svg_data) ->
    [paths, texts] = svg_data.split ";"
    result = '<svg viewbox="0 0 1024 1024">'
    for path_data in paths.split ","
      result += "<path d=\"#{path_data}\"/>"
    text_data = texts.split ","
    for i in [0...text_data.length] by 2
      x = text_data[i]
      y = text_data[i + 1]
      result += "<text x=\"#{x}\" y=\"#{y}\">#{i / 2}</text>"
    result + "</svg>"
  filter: =>
    dom.result.innerHTML = ""
    values = dom.input.value.split("").filter (a) -> a.length > 0
    return unless values.length
    html = ""
    for char in values
      data = @character_data[char]
      continue unless data
      [stroke_count, compositions, decompositions, svg] = data
      if svg
        entry = @make_svg svg
      else
        entry = "#{char} #{stroke_count}"
      html += "<div>#{entry}</div>"
    dom.result.innerHTML = html
  constructor: ->
    dom.input.addEventListener "keyup", @filter
    dom.input.addEventListener "change", @filter

new app_class()
