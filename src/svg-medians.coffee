fs = require "fs"
canvas = require "canvas"
{ createCanvas } = canvas
SVGPathParser = require "svg-path-parser"
TraceSkeleton = require "skeleton-tracing-js"
read_text_file = (a) -> fs.readFileSync a, "utf8"
array_from_newline_file = (path) -> read_text_file(path).toString().trim().split("\n")
simplify_svg_path = null
rbush = null
import_modules = -> Promise.all [import("@luncheon/simplify-svg-path"), import("rbush")]

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

find_longest_paths = (polylines) ->
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
  # Step 3: Reconstruct the polyline
  longestPathNodeIds.map (nodeId) -> idToPoint[nodeId]

calculate_centroid = (polylines) ->
  sum_x = 0
  sum_y = 0
  total_points = 0
  for polyline in polylines
    for point in polyline
      x = point[0]
      y = point[1]
      sum_x += x
      sum_y += y
      total_points += 1
  [sum_x / total_points, sum_y / total_points]

# Union-Find data structure for grouping
class UnionFind
  constructor: (n) ->
    @parent = (i for i in [0...n])
  find: (i) ->
    if @parent[i] != i
      @parent[i] = @find(@parent[i])
    @parent[i]
  union: (i, j) ->
    pi = @find(i)
    pj = @find(j)
    if pi != pj
      @parent[pi] = pj

compute_min_distance = (polyline1, polyline2) ->
  min_distance = Infinity
  for [x1, y1] in polyline1
    for [x2, y2] in polyline2
      dx = x1 - x2
      dy = y1 - y2
      distance = Math.sqrt(dx ** 2 + dy ** 2)
      if distance < min_distance
        min_distance = distance
        point1 = [x1, y1]
        point2 = [x2, y2]
  [min_distance, point1, point2]

compute_bounding_box = (polyline) ->
  min_x = Infinity
  min_y = Infinity
  max_x = -Infinity
  max_y = -Infinity
  for [x, y] in polyline
    if x < min_x then min_x = x
    if y < min_y then min_y = y
    if x > max_x then max_x = x
    if y > max_y then max_y = y
  return {min_x, min_y, max_x, max_y}

expand_bounding_box = (bbox, margin) ->
  {
    min_x: bbox.min_x - margin
    min_y: bbox.min_y - margin
    max_x: bbox.max_x + margin
    max_y: bbox.max_y + margin
  }

compute_group_bounding_box = (group_polylines) ->
  min_x = Infinity
  min_y = Infinity
  max_x = -Infinity
  max_y = -Infinity
  for polyline in group_polylines
    bbox = compute_bounding_box(polyline)
    if bbox.min_x < min_x then min_x = bbox.min_x
    if bbox.min_y < min_y then min_y = bbox.min_y
    if bbox.max_x > max_x then max_x = bbox.max_x
    if bbox.max_y > max_y then max_y = bbox.max_y
  { min_x, min_y, max_x, max_y }

compute_min_distance_between_groups = (polylines, group_i, group_j) ->
  min_distance = Infinity
  point_i = null
  point_j = null
  for idx_i in group_i
    polyline_i = polylines[idx_i]
    for idx_j in group_j
      polyline_j = polylines[idx_j]
      [dist, p_i, p_j] = compute_min_distance(polyline_i, polyline_j)
      if dist < min_distance
        min_distance = dist
        point_i = p_i
        point_j = p_j
  [min_distance, point_i, point_j]

# Function to identify connected strokes
identify_connected_strokes = (polylines) ->
  n = polylines.length
  uf = new UnionFind(n)
  # Threshold for considering strokes as connected
  connection_threshold = 2  # Adjust as needed
  # Compare each pair of strokes
  for i in [0...n]
    polyline_i = polylines[i]
    for j in [i+1...n]
      polyline_j = polylines[j]
      # Compute minimum distance
      [min_distance, _, _] = compute_min_distance polyline_i, polyline_j
      uf.union i, j if min_distance <= connection_threshold
  # Build groups based on union-find structure
  groups = {}
  for i in [0...n]
    root = uf.find(i)
    groups[root] = [] unless groups[root]
    groups[root].push(i)
  # Convert groups to a list
  stroke_groups = []
  for key, indices of groups
    stroke_groups.push(indices)
  stroke_groups

get_group_neighbors = (group_bounding_boxes) ->
  n = group_bounding_boxes.length
  proximity_margin = 30 * 1.5
  items = []
  for i in [0...n]
    bbox = expand_bounding_box group_bounding_boxes[i], proximity_margin
    items.push {
      minX: bbox.min_x,
      minY: bbox.min_y,
      maxX: bbox.max_x,
      maxY: bbox.max_y,
      groupIndex: i
    }
  tree = new rbush()
  tree.load items
  neighbors = ([] for _ in group_bounding_boxes)
  for i in [0...n]
    bbox_i = items[i]
    potential_neighbors = tree.search bbox_i
    for item in potential_neighbors
      j = item.groupIndex
      neighbors[i].push j unless j == i
  neighbors

reduce_stroke_distances = (polylines) ->
  old_stroke_width = 50
  new_stroke_width = 5
  delta_stroke_width = old_stroke_width - new_stroke_width
  stroke_groups = identify_connected_strokes(polylines)
  group_bounding_boxes = []
  for group in stroke_groups
    group_polylines = (polylines[i] for i in group)
    bbox = compute_group_bounding_box group_polylines
    group_bounding_boxes.push bbox
  neighbors = get_group_neighbors group_bounding_boxes
  group_movement_vectors = []  # Will store [dx, dy] for each group

  # For each stroke group
  for i in [0...stroke_groups.length]
    group = stroke_groups[i]
    neighbors_i = neighbors[i]  # Neighboring group indices

    # Compute the centroid of the current group
    group_points = []
    for polyline_index in group
      polyline = polylines[polyline_index]
      group_points = group_points.concat polyline

    sum_x = 0
    sum_y = 0
    n_points = group_points.length
    for point in group_points
      sum_x += point[0]
      sum_y += point[1]
    centroid_x = sum_x / n_points
    centroid_y = sum_y / n_points

    # Initialize cumulative movement vector
    mv_x = 0
    mv_y = 0
    count = 0

    # For each neighboring group
    for neighbor_index in neighbors_i
      neighbor_group = stroke_groups[neighbor_index]

      # Compute the centroid of the neighbor group
      neighbor_points = []
      for polyline_index in neighbor_group
        polyline = polylines[polyline_index]
        neighbor_points = neighbor_points.concat polyline

      sum_x_n = 0
      sum_y_n = 0
      n_points_n = neighbor_points.length
      for point in neighbor_points
        sum_x_n += point[0]
        sum_y_n += point[1]
      neighbor_centroid_x = sum_x_n / n_points_n
      neighbor_centroid_y = sum_y_n / n_points_n

      # Compute the vector from current group to neighbor group
      vector_x = neighbor_centroid_x - centroid_x
      vector_y = neighbor_centroid_y - centroid_y
      vector_length = Math.sqrt(vector_x * vector_x + vector_y * vector_y)

      # Avoid division by zero
      if vector_length == 0
        continue

      # Compute the unit vector
      unit_vector_x = vector_x / vector_length
      unit_vector_y = vector_y / vector_length

      # Desired reduction per neighbor (we divide by 2 because each group moves half the distance)
      move_amount = delta_stroke_width / 2

      # Compute the movement towards the neighbor
      move_x = unit_vector_x * move_amount
      move_y = unit_vector_y * move_amount

      # Accumulate movement vectors
      mv_x += move_x
      mv_y += move_y
      count += 1

    # Average the movement vectors if there are multiple neighbors
    if count > 0
      mv_x /= count
      mv_y /= count

    # Store the movement vector for the group
    group_movement_vectors[i] = [mv_x, mv_y]

  # For each stroke group
  for i in [0...stroke_groups.length]
    group = stroke_groups[i]
    mv = group_movement_vectors[i] || [0, 0]  # Default to [0, 0] if undefined
    mv_x = mv[0]
    mv_y = mv[1]

    # Move each stroke in the group
    for polyline_index in group
      polyline = polylines[polyline_index]

      # Move each point in the polyline
      for point in polyline
        point[0] += mv_x
        point[1] += mv_y

  polylines

svg = (canvas_width, canvas_height, paths) ->
 "<svg width=\"#{canvas_width}\" height=\"#{canvas_height}\"><rect width=\"100%\" height=\"100%\" fill=\"black\"/>#{paths}</svg>"

update_medians = () ->
  # measured stroke widths: middle: 44, 39, 55, ends and curves: 91, 100
  characters = (JSON.parse a for a in array_from_newline_file("data/svg-graphics.txt").slice(120, 130))
  canvas_width = canvas_height = 1024
  canvas = createCanvas canvas_width, canvas_height
  ctx = canvas.getContext "2d"
  for character in characters
    #continue unless character.character == "鲍"
    result_canvas = createCanvas canvas_width, canvas_height
    result_ctx = result_canvas.getContext "2d"
    result_ctx.fillStyle = "#000"
    result_ctx.fillRect 0, 0, canvas_width, canvas_height
    polylines = []
    for path, i in character.strokes
      ctx.fillStyle = "#000"
      ctx.fillRect 0, 0, canvas_width, canvas_height
      commands = SVGPathParser.parseSVG path
      draw_path_from_commands ctx, commands
      #image_data = ctx.getImageData 0, 0, canvas_width, canvas_height
      ctx.translate 0, canvas_height
      ctx.scale 1, -1
      #canvas_to_png_file canvas, "#{character.character}-path.png"
      result_ctx.globalCompositeOperation = "lighten"
      result_ctx.drawImage canvas, 0, 0
      skeleton = TraceSkeleton.fromCanvas canvas
      a = skeleton.polylines
      polyline = if 1 < a.length then find_longest_paths a else a[0]
      polylines.push polyline
    polylines = reduce_stroke_distances polylines
    medians = []
    medians.push simplify_svg_path polyline for polyline in polylines
    original_medians = []
    original_medians.push simplify_svg_path polyline for polyline in character.medians
    stroke_width = 20
    #canvas_to_png_file result_canvas, "#{character.character}.png"
    paths = ("<path d=\"#{a}\" fill=\"none\" stroke-linecap=\"round\" stroke-width=\"#{stroke_width}\" stroke=\"white\"/>" for a in medians).join "\n"
    svg_content = svg canvas_width, canvas_height, paths
    fs.writeFileSync "#{character.character}.svg", svg_content
    paths = ("<path d=\"#{a}\" fill=\"none\" stroke-linecap=\"round\" stroke-width=\"#{stroke_width}\" stroke=\"white\"/>" for a in original_medians).join "\n"
    svg_content = svg canvas_width, canvas_height, paths
    fs.writeFileSync "#{character.character}-original.svg", svg_content

import_modules().then ([simplify_svg_module, rbush_module]) ->
  simplify_svg_path = simplify_svg_module.default
  rbush = rbush_module.default
  update_medians()
