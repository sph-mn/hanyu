coffee = require "coffeescript"
main = require "./main"
fs = require "fs"
normalize_deg = (deg) -> (((deg + 180) % 360 + 360) % 360) - 180

compute_position = (angle, radius, center_x, center_y) ->
  x = center_x + radius * Math.cos(angle)
  y = center_y + radius * Math.sin(angle)
  {x, y}

get_text_attrs = (angle, x, y, center_x, center_y) ->
  deg = normalize_deg angle * 180 / Math.PI
  anchor = "start"
  if x > center_x and y > center_y
    deg = normalize_deg deg - 360
    anchor = "start"
  else if deg > 90 or deg < -90
    deg = normalize_deg deg + 180
    anchor = "end"
  {rotate_deg: deg, anchor}

create_text = (x, y, font_size, text, angle, fill = "black", center_x, center_y) ->
  {rotate_deg, anchor} = get_text_attrs(angle, x, y, center_x, center_y)
  "<text x=\"#{x.toFixed(2)}\" y=\"#{y.toFixed(2)}\" font-size=\"#{font_size}\" text-anchor=\"#{anchor}\" dominant-baseline=\"middle\" transform=\"rotate(#{rotate_deg.toFixed(2)} #{x.toFixed(2)} #{y.toFixed(2)})\" fill=\"#{fill}\">#{text}</text>"

create_syllable_text = (x, y, font_size, syllable, angle, fill = "black", center_x, center_y) ->
  {rotate_deg, anchor} = get_text_attrs(angle, x, y, center_x, center_y)
  "<text x=\"#{x.toFixed(2)}\" y=\"#{y.toFixed(2)}\" font-size=\"#{font_size}\" text-anchor=\"#{anchor}\" dominant-baseline=\"middle\" transform=\"rotate(#{rotate_deg.toFixed(2)} #{x.toFixed(2)} #{y.toFixed(2)})\" fill=\"#{fill}\" data-syllable=\"#{syllable}\">#{syllable}</text>"

group_by_initial = (syllables) ->
  initial_map = {}
  for i in [0...syllables.length]
    initial = syllables[i][0]
    initial_map[initial] ?= []
    initial_map[initial].push i
  initial_map

syllable_circle_svg = (syllables) ->
  # the circle starts at 0 radians and goes counter-clockwise only for mathematical purity.
  svg_size = 1800
  center_x = svg_size / 2
  center_y = svg_size / 2
  outer_radius = 800
  inner_radius = 770
  font_size = 14
  n = syllables.length
  angle_step = -2 * Math.PI / n
  svg_parts = []
  svg_parts.push "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 #{svg_size} #{svg_size}\" preserveAspectRatio=\"xMidYMid meet\" id=\"syllable_circle_svg\" style=\"background-color: #000\">"
  svg_parts.push "<line id=\"center_line\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"0\" stroke=\"#aaa\" stroke-width=\"1.5\" style=\"display:none\"/>"
  for i in [0...n]
    angle = i * angle_step
    pos = compute_position(angle, outer_radius, center_x, center_y)
    svg_parts.push create_syllable_text(pos.x, pos.y, font_size, syllables[i], angle, "#fff", center_x, center_y)
  initial_map = group_by_initial syllables
  for initial, indexes of initial_map
    avg_index = indexes.reduce(((a, b) -> a + b), 0) / indexes.length
    angle = avg_index * angle_step
    pos = compute_position(angle, inner_radius, center_x, center_y)
    svg_parts.push create_text(pos.x, pos.y, font_size * 1.5, initial, angle, "#888", center_x, center_y)
  svg_parts.push "<g id=\"character_display\" style=\"background-color:#000\"/>"
  svg_parts.push "</svg>"
  svg_parts.join "\n"

get_characters_by_syllable_with_tone = ->
  b = {}
  chars = main.get_all_characters_with_pinyin().filter((a) -> !a[1].endsWith("5"))
  for [char, pinyin] in chars
    tone = parseInt pinyin.match(/\d$/)[0]
    syllable = pinyin.replace /\d$/, ""
    main.object_array_add b, syllable, [char, tone]
  b

update_syllable_circle = ->
  character_data = get_characters_by_syllable_with_tone()
  syllables = Object.keys(character_data).sort()
  svg = syllable_circle_svg syllables
  character_data = JSON.stringify character_data
  script = main.read_text_file "src/syllable-circle-script.coffee"
  script = coffee.compile(script, bare: true).trim()
  script = main.replace_placeholders script, {character_data}
  font = main.read_text_file "src/NotoSansSC-Light.ttf.base64"
  html = main.read_text_file "src/syllable-circle-template.html"
  html = main.replace_placeholders html, {font, script, svg}
  fs.writeFileSync "compiled/syllable-circle.html", html

update_syllable_circle()
