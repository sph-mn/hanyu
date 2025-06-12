class syllable_circle_class
  character_data: __character_data__
  tone_colors:
    1: "#ccddee"  # blue is calm, high, stable - like a flat tone.
    2: "#cceecc"  # green grows - rising movement.
    3: "#eeeecc"  # yellow is ambiguous, soft, unstable - matching the tone's falling-rising contour.
    4: "#eecccc"  # red is strong and final - matching the sharp, falling quality.
  update_display: (syllable) ->
    chars = @character_data[syllable] or []
    g = @dom.character_display
    g.innerHTML = ""
    bbox = @dom.syllable_circle_svg.viewBox.baseVal
    cx = bbox.x + bbox.width / 2
    cy = bbox.y + bbox.height / 2
    n = chars.length
    cols = Math.ceil(Math.sqrt(n))
    rows = Math.ceil(n / cols)
    font_size = 52
    size = font_size + 8
    box_w = cols * size
    box_h = rows * size
    box_x = cx - box_w / 2
    box_y = cy - box_h / 2
    g.innerHTML += "<rect x=\"#{box_x}\" y=\"#{box_y}\" width=\"#{box_w}\" height=\"#{box_h}\" fill=\"black\" rx=\"10\" ry=\"10\"/>"
    for i in [0...n]
      [char, tone] = chars[i]
      col = i % cols
      row = Math.floor(i / cols)
      x = box_x + col * size + size / 2
      y = box_y + row * size + size / 2
      color = @tone_colors[tone] or "white"
      g.innerHTML += "<text x='#{x}' y='#{y}' fill='#{color}' font-size='#{font_size}' text-anchor='middle' dominant-baseline='middle'>#{char}</text>"
  update_line_to: (x, y) ->
    line = @dom.center_line
    bbox = @dom.syllable_circle_svg.viewBox.baseVal
    cx = bbox.x + bbox.width / 2
    cy = bbox.y + bbox.height / 2
    line.setAttribute "x1", cx
    line.setAttribute "y1", cy
    line.setAttribute "x2", x
    line.setAttribute "y2", y
    line.style.display = "block"
  locked_syllable: null
  lock_syllable: (el) =>
    if @locked_syllable == el
      el.style.fontWeight = "normal"
      @locked_syllable = null
      return
    if @locked_syllable?
      @locked_syllable.style.fontWeight = "normal"
    el.style.fontWeight = "bold"
    @locked_syllable = el
    syllable = el.dataset.syllable
    sx = parseFloat el.getAttribute "x"
    sy = parseFloat el.getAttribute "y"
    @update_display syllable
    @update_line_to sx, sy
  constructor: ->
    ids = ["syllable_circle_svg", "center_line", "character_display"]
    @dom = {}; (@dom[a] = document.getElementById a for a in ids)
    @dom.syllable_circle_svg.setAttribute "width", window.innerWidth
    @dom.syllable_circle_svg.setAttribute "height", window.innerWidth
    for text in document.querySelectorAll "text[data-syllable]"
      handler = (event) =>
        return if @locked_syllable?
        syllable = event.target.dataset.syllable
        sx = parseFloat event.target.getAttribute "x"
        sy = parseFloat event.target.getAttribute "y"
        @update_display syllable
        @update_line_to sx, sy
      text.addEventListener("mouseenter", handler)
      text.addEventListener("touchstart", handler)
      text.addEventListener("click", (e) => @lock_syllable(e.target))

new syllable_circle_class
