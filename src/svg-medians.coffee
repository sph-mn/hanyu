fs = require "fs"
canvas = require "canvas"
{ createCanvas } = canvas
SVGPathParser = require "svg-path-parser"
TraceSkeleton = require "skeleton-tracing-js"
read_text_file = (a) -> fs.readFileSync a, "utf8"
array_from_newline_file = (path) -> read_text_file(path).toString().trim().split("\n")
simplify_svg_path = null
load_simplify_svg_path = -> import("@luncheon/simplify-svg-path")

draw_path_from_commands = (ctx, commands) ->
  ctx.beginPath()
  for command in commands
    switch command.code
      when "M" then ctx.moveTo command.x, command.y
      when "L" then ctx.lineTo command.x, command.y
      when "Q" then ctx.quadraticCurveTo command.x1, command.y1, command.x, command.y
      when "Z" then ctx.closePath()
  ctx.fillStyle = "#fff"
  ctx.fill()

skeleton_to_svg_file = (skeleton, path) ->
  svg_string = TraceSkeleton.visualize skeleton, {scale: 1, strokeWidth: 1, rects: false, keypoints: false}
  fs.writeFileSync path, svg_string

canvas_to_png_file = (canvas, path) -> fs.writeFileSync path, canvas.toBuffer "image/png"

calculate_polyline_length = (polyline) ->
  length = 0
  for i in [0...polyline.length - 1]
    x1 = polyline[i][0]
    y1 = polyline[i][1]
    x2 = polyline[i + 1][0]
    y2 = polyline[i + 1][1]
    dx = x2 - x1
    dy = y2 - y1
    length += Math.sqrt dx * dx + dy * dy
  length

prune_short_branches = (polylines) ->
  length_threshold = 45
  filtered_polylines = []
  for polyline in polylines
    length = calculate_polyline_length polyline
    if length >= length_threshold
      filtered_polylines.push polyline
  filtered_polylines

contract_centerlines = (polylines) ->
  k = 0.1
  desired_spacing = 8
  max_iterations = 100
  tolerance = 0.01
  console.log polylines
  neighbors = []

update_medians = () ->
  characters = (JSON.parse a for a in array_from_newline_file("data/svg-graphics.txt"))
  canvas_width = canvas_height = 1024
  canvas = createCanvas canvas_width, canvas_height
  ctx = canvas.getContext "2d"
  for character in characters
    continue unless character.character == "鲍"
    result_canvas = createCanvas canvas_width, canvas_height
    result_ctx = result_canvas.getContext "2d"
    result_ctx.fillStyle = "#000"
    result_ctx.fillRect 0, 0, canvas_width, canvas_height
    character.medians = []
    for path, i in character.strokes
      ctx.fillStyle = "#000"
      ctx.fillRect 0, 0, canvas_width, canvas_height
      commands = SVGPathParser.parseSVG path
      draw_path_from_commands ctx, commands
      image_data = ctx.getImageData 0, 0, canvas_width, canvas_height
      canvas_to_png_file canvas, "#{character.character}-path.png"
      result_ctx.globalCompositeOperation = "lighten"
      result_ctx.drawImage canvas, 0, 0
      skeleton = TraceSkeleton.fromCanvas canvas
      polylines = prune_short_branches skeleton.polylines
      for polyline in polylines
        character.medians.push simplify_svg_path polyline
    canvas_to_png_file result_canvas, "#{character.character}.png"
    paths = ("<path d=\"#{a}\" fill=\"none\" stroke-width=\"12\" stroke=\"black\"/>" for a in character.medians).join "\n"
    svg_content = "<svg width=\"1024\" height=\"1024\">#{paths}</svg>"
    fs.writeFileSync "#{character.character}.svg", svg_content

load_simplify_svg_path().then (module) ->
  simplify_svg_path = module.default
  update_medians()
