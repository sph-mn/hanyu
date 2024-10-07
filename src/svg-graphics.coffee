# this file contains code for converting the brushstroke outlines of makemeahanzi
# svg graphics and convert them to simpler open paths.

fs = require "fs"
createCanvas = require("canvas").createCanvas
SVGPathParser = require "svg-path-parser"
TraceSkeleton = require "skeleton-tracing-js"
fit_curve = require "fit-curve"
cheerio = require "cheerio"
{spawn} = require "child_process"

read_text_file = (a) -> fs.readFileSync a, "utf8"
canvas_to_png_file = (canvas, path) -> fs.writeFileSync path, canvas.toBuffer "image/png"
canvas_context_draw_svg_path = (ctx, path) -> canvas_context_draw_svg_commands ctx, SVGPathParser.parseSVG(path)
centerline_from_canvas = (canvas) -> extract_longest_path remove_short_paths(TraceSkeleton.fromCanvas(canvas).polylines, 40)
flip_vertical = (polyline, height) -> [x, height - y] for [x, y] in polyline

canvas_context_draw_svg_commands = (ctx, commands) ->
  ctx.beginPath()
  for command in commands
    switch command.code
      when "M" then ctx.moveTo command.x, command.y
      when "L" then ctx.lineTo command.x, command.y
      when "Q" then ctx.quadraticCurveTo command.x1, command.y1, command.x, command.y
      when "Z" then ctx.closePath()
  ctx.fillStyle = "#fff"
  ctx.fill()

make_path_start_markers = (paths) ->
  for path in paths
    match = path.match /M\s*([\d.]+)[,\s]+([\d.]+)/i
    [x, y] = match[1..2]
    "<circle cx=\"#{x}\" cy=\"#{y}\" r=\"5\" fill=\"red\"/>"

paths_to_svg = (paths, stroke_width, width, height) ->
  start_markers = make_path_start_markers paths
  paths = ("<path d=\"#{a}\" fill=\"none\" stroke=\"#fff\" stroke-linecap=\"round\" stroke-width=\"#{stroke_width}\"/>" for a in paths).join "\n"
  "<svg width=\"#{width}\" height=\"#{height}\">\n<rect width=\"100%\" height=\"100%\" fill=\"#000\"/>\n#{paths}\n#{start_markers}</svg>"

paths_to_svg_file = (path, paths, stroke_width, width, height) -> fs.writeFileSync path, paths_to_svg(paths, stroke_width, width, height)

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

remove_short_paths = (polylines, limit) ->
  for a in polylines
    continue if limit > calculate_polyline_length a
    a

extract_longest_path = (polylines) ->
  return polylines[0] if 1 == polylines.length
  # Step 1: Build the graph
  nodeMap = new Map() # Map from point string to node ID
  nodeId = 0
  adj = {} # Adjacency list
  pointKey = (pt) ->
    # Round coordinates to 6 decimal places
    x = pt[0].toFixed 6
    y = pt[1].toFixed 6
    "#{x},#{y}"
  getNodeId = (pt) ->
    key = pointKey pt
    unless nodeMap.has key
      nodeMap.set key, nodeId++
    nodeMap.get key
  for polyline in polylines
    for i in [0...polyline.length - 1]
      pt1 = polyline[i]
      pt2 = polyline[i + 1]
      id1 = getNodeId pt1
      id2 = getNodeId pt2
      adj[id1] ?= []
      adj[id2] ?= []
      adj[id1].push id2
      adj[id2].push id1 # Since it's undirected
  # Map from node ID to point coordinates
  idToPoint = {}
  nodeMap.forEach (id, key) ->
    [x, y] = key.split(',').map Number
    idToPoint[id] = [x, y]
  # Step 2: Find the longest path
  bfs = (start) ->
    visited = new Set()
    queue = [[start, 0]]
    farthestNode = start
    maxDistance = 0
    while queue.length > 0
      [node, dist] = queue.shift()
      visited.add node
      if dist > maxDistance
        maxDistance = dist
        farthestNode = node
      for neighbor in adj[node]
        unless visited.has neighbor
          queue.push [neighbor, dist + 1]
          visited.add neighbor
    {node: farthestNode, distance: maxDistance}
  # First BFS to find one end of the longest path
  firstBfs = bfs 0 # Start from any node, say node 0
  # Second BFS from the farthest node found in the first BFS
  secondBfs = bfs firstBfs.node
  # Reconstruct the path from firstBfs.node to secondBfs.node
  bfsWithParents = (start, target) ->
    visited = new Set()
    queue = [start]
    parent = {}
    visited.add start
    while queue.length > 0
      node = queue.shift()
      break if node == target
      for neighbor in adj[node]
        unless visited.has neighbor
          visited.add neighbor
          parent[neighbor] = node
          queue.push neighbor
    # Reconstruct path from target to start
    path = []
    currentNode = target
    while currentNode?
      path.push currentNode
      currentNode = parent[currentNode]
    path.reverse() # From start to target
  longestPathNodeIds = bfsWithParents firstBfs.node, secondBfs.node
  idToPoint[a] for a in longestPathNodeIds

polyline_centroid = (polyline) ->
  n = polyline.length
  x_sum = 0
  y_sum = 0
  for [x, y] in polyline
    x_sum += x
    y_sum += y
  [x_sum / n, y_sum / n]

scale_by_centroids = (polylines, factor) ->
  centroids = (polyline_centroid a for a in polylines)
  scaled_centroids = ([x * factor, y * factor] for [x, y] in centroids)
  for polyline, i in polylines
    centroid = centroids[i]
    scaled_centroid = scaled_centroids[i]
    dx = scaled_centroid[0] - centroid[0]
    dy = scaled_centroid[1] - centroid[1]
    [x + dx, y + dy] for [x, y] in polyline

simplify_to_svg = (polylines) ->
  error = 400.0
  svg_paths = []
  for polyline in polylines
    beziers = fit_curve polyline, error
    path_data = ''
    continue unless beziers.length
    beziers = for a in beziers
      for [x, y] in a
        [x.toFixed(0), y.toFixed(0)]
    [x0, y0] = beziers[0][0]
    path_data += "M#{x0},#{y0}"
    for bezier in beziers
      [p0, p1, p2, p3] = bezier
      [x1, y1] = p1
      [x2, y2] = p2
      [x3, y3] = p3
      path_data += "C#{x1},#{y1},#{x2},#{y2},#{x3},#{y3}"
    svg_paths.push path_data
  svg_paths

extract_path_data_from_svg = () ->
  svg_path = "data/svgsZhHans"
  entries = fs.readdirSync svg_path
  svg_files = entries.filter (a) -> a.endsWith ".svg"
  for file in svg_files
    content = fs.readFileSync "#{svg_path}/#{file}", "utf8"
    $ = cheerio.load content, xmlMode: true
    path_elements = $ "path"
    paths_with_clip = []
    paths_without_clip = []
    for path in path_elements
      d_attr = $(path).attr "d"
      clip_path_attr = $(path).attr "clip-path"
      if clip_path_attr? then paths_with_clip.push d_attr
      else paths_without_clip.push d_attr
    char = String.fromCharCode parseInt file.replace(".svg", "")
    [char, paths_without_clip, paths_with_clip]

get_direction = (polyline) ->
  [x1, y1] = polyline[0]
  [x2, y2] = polyline[1]
  direction_vector = [x2 - x1, y2 - y1]
  magnitude = Math.sqrt direction_vector[0] ** 2 + direction_vector[1] ** 2
  [direction_vector[0] / magnitude, direction_vector[1] / magnitude]

extract_paths_and_direction_from_svg = () ->
  path_data = extract_path_data_from_svg()
  for [char, paths, clip_paths] in path_data
    polylines = for clip_path in clip_paths
      for a in SVGPathParser.parseSVG clip_path
        continue unless a.x
        [a.x, a.y]
    directions = for polyline in polylines
      get_direction polyline
    [char, paths, directions]

extract = () ->
  # extract graphics data from animcjk svg graphics
  json = JSON.stringify extract_paths_and_direction_from_svg()
  fs.writeFileSync "data/svg-graphics.json", json

point_distance = ([x1, y1], [x2, y2]) -> Math.sqrt (x2 - x1) ** 2 + (y2 - y1) ** 2

ensure_direction = (polyline, original_direction) ->
  direction = get_direction polyline
  dot_product = direction[0] * original_direction[0] + direction[1] * original_direction[1]
  delta = Math.max -1, Math.min(1, dot_product)
  if 0 > delta then polyline.reverse() else polyline

simplify = (start, end) ->
  svg_graphics = JSON.parse(read_text_file("data/svg-graphics.json")).slice(start, end)
  canvas_width = canvas_height = 1024
  stroke_width = 8
  canvas = createCanvas canvas_width, canvas_height
  ctx = canvas.getContext "2d"
  result = {}
  for [char, paths, directions] in svg_graphics
    continue unless "价" == char
    polylines = for path, i in paths
      ctx.clearRect 0, 0, canvas_width, canvas_height
      canvas_context_draw_svg_path ctx, path
      ensure_direction centerline_from_canvas(canvas), directions[i]
    strokes = simplify_to_svg scale_by_centroids(polylines, 0.85)
    result[char] = strokes
    paths_to_svg_file "#{char}.svg", strokes, stroke_width, canvas_width, canvas_height
  #fs.writeFileSync "tmp/svg-graphics-simple-#{start}-#{end}.json", JSON.stringify(result)

simplify_parallel = () ->
  total = read_text_file("data/svg-graphics.txt").split("\n").length
  max_processes = 28
  batch_size = Math.ceil total / max_processes
  active_processes = []
  call_script = (start, end, callback) ->
    child = spawn "exe/update-svg-graphics", ["simplify", start, end]
    child.stdout.on "data", (data) -> console.log "#{start}/#{end}: #{data.toString().trim()}"
    child.stderr.on "data", (data) -> console.error "#{start}/#{end}: #{data}"
    active_processes -= 1
    process_queue()
  process_queue = () ->
    while tasks.length > 0 and active_processes < max_processes
      {start, end} = tasks.shift()
      active_processes += 1
      call_script start, end
  tasks = for i in [0...(total / batch_size)]
    start = i * batch_size
    end = start + batch_size
    {start, end}
  process_queue tasks

merge = ->
  files = fs.readdirSync "tmp"
  result = {}
  for file in files
    continue unless file.endsWith ".json"
    Object.assign result, JSON.parse(read_text_file "tmp/" + file)
  fs.writeFileSync "data/svg-graphics-simple.json", JSON.stringify(result)

module.exports = {
  simplify
  simplify_parallel
  merge
  extract
}
