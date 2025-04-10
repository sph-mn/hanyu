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

group_by_initial = (syllables) ->
  initial_map = {}
  for i in [0...syllables.length]
    initial = syllables[i][0]
    initial_map[initial] ?= []
    initial_map[initial].push i
  initial_map

update_syllable_circle = ->
  syllables = fs.readFileSync("data/syllables.txt", "utf8").trim().split /\s+/
  svg_size = 1800
  center_x = svg_size / 2
  center_y = svg_size / 2
  outer_radius = 800
  inner_radius = 770
  font_size = 14
  n = syllables.length
  angle_step = -2 * Math.PI / n
  svg_parts = []
  svg_parts.push "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{svg_size}\" height=\"#{svg_size}\" style=\"background-color: #000\">"
  for i in [0...n]
    angle = i * angle_step
    pos = compute_position(angle, outer_radius, center_x, center_y)
    svg_parts.push create_text(pos.x, pos.y, font_size, syllables[i], angle, "#fff", center_x, center_y)
  initial_map = group_by_initial syllables
  for initial, indexes of initial_map
    avg_index = indexes.reduce(((a, b) -> a + b), 0) / indexes.length
    angle = avg_index * angle_step
    pos = compute_position(angle, inner_radius, center_x, center_y)
    svg_parts.push create_text(pos.x, pos.y, font_size * 1.5, initial, angle, "#888", center_x, center_y)
  svg_parts.push "</svg>"
  fs.writeFileSync("compiled/syllable_circle.svg", svg_parts.join "\n")

update_syllable_circle()
