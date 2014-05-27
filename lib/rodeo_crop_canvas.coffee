'use strict'

# http://simonsarris.com/project/canvasdemo/shapes.js

# Fake underscore.js, funderscore if you will
_ = {}

_.extend = (obj, source) ->
  if source
    for prop of source
      obj[prop] = source[prop]
  obj

for type in ['Arguments', 'Function', 'String', 'Number', 'Date', 'RegExp']
  do (type) ->
    _["is#{type}"] = (obj) -> Object.prototype.toString.call(obj) == "[object #{type}]"

class Drawable
  constructor: (options) ->
    @options = options

    @x = options.x
    @y = options.y
    @w = options.w
    @h = options.h
    @scale = options.scale
    @parent = options.parent
    @canvas = options.canvas
    @children = options.children || []
    @dragable = options.dragable || false

  onCanvasSizeChange: () ->
    @options.onCanvasSizeChange.call @ if _.isFunction @options.onCanvasSizeChange

  set: (options) ->
    for own key, value of options
      @[key] = value

  bounds: ->
    {
      x: 0
      y: 0
      w: @w
      h: @h
    }

  frame: ->
    {
      x: @x
      y: @y
      w: @w
      h: @h
    }

  convertToParent: (point) ->
    frame = @frame()
    {
      x: point.x + frame.x
      y: point.y + frame.y
    }

  convertFromParent: (point) ->
    frame = @frame()
    {
      x: point.x - frame.x
      y: point.y - frame.y
    }

  convertToCanvas: (point) ->
    parent = @
    x = point.x
    y = point.y
    while parent
      x += parent.frame().x
      y += parent.frame().y

      parent = parent.parent

    {
      x: x
      y: y
    }

  convertFromCanvas: (point) ->
    parent = @
    x = point.x
    y = point.y
    while parent
      x -= parent.frame().x
      y -= parent.frame().y

      parent = parent.parent

    {
      x: x
      y: y
    }

  positionContext: (ctx, fn) ->
    if @parent
      pos = @convertToCanvas @parent.bounds()
      ctx.translate pos.x, pos.y
    fn.call @, ctx

  isolateAndMoveToParent: (ctx, fn) ->
    ctx.save()
    @positionContext ctx, (ctx) ->
      fn.call @, ctx
    ctx.restore()

  containsCanvasPoint: (point) ->
    localPoint = @convertFromCanvas point
    @containsPoint localPoint

  containsPoint: (point) ->
    frame = @frame()
    0 <= point.x <= frame.w &&
    0 <= point.y <= frame.h

  addChild: (child) ->
    child.parent = @
    @children.push child

  removeChild: (child) ->
    i = @children.indexOf child
    if i >= 0
      child.parent = null
      @children.splice i, 1

  drawChildren: (ctx) ->
    for child in @children
      child.draw ctx

  draw: (ctx) ->
    # noop

class CanvasImage extends Drawable
  constructor: (options) ->
    super options

    @source = options.source
    @naturalWidth = options.naturalWidth
    @naturalHeight = options.naturalHeight
    @onLoad = options.onLoad

    @loadImage()

  resizeToParent: () ->
    cw = @parent.frame().w
    ch = @parent.frame().h

    scaleX = 1
    scaleY = 1

    scaleX = cw / @naturalWidth if @naturalWidth > cw
    scaleY = ch / @naturalHeight if @naturalHeight > ch

    @scale = Math.min scaleX, scaleY
    @w = (@naturalWidth * @scale)|0
    @h = (@naturalHeight * @scale)|0

  centerOnParent: () ->
    @x = ((@parent.frame().w / 2) - (@w / 2))|0
    @y = ((@parent.frame().h / 2) - (@h / 2))|0

  draw: (ctx) ->
    @isolateAndMoveToParent ctx, (ctx) ->
      ctx.drawImage @img, 0, 0, @w, @h

    @drawChildren ctx

  loadImage: ->
    @img = document.createElement 'img'
    @img.onload = =>
      @naturalWidth = @img.naturalWidth
      @naturalHeight = @img.naturalHeight
      @onLoad.call @ if _.isFunction @onLoad
    @img.src = @source

class Rectangle extends Drawable
  constructor: (options) ->
    super options
    @fillStyle = options.fillStyle || 'rgba(0, 0, 0, 0)'
    @strokeStyle = options.strokeStyle
    @lineWidth = options.lineWidth

  draw: (ctx) ->
    @isolateAndMoveToParent ctx, (ctx) =>
      ctx.fillStyle = @fillStyle if @fillStyle
      ctx.strokeStyle = @strokeStyle if @strokeStyle
      ctx.lineWidth = @lineWidth if @lineWidth
      ctx.beginPath()
      ctx.rect 0, 0, @w, @h
      ctx.closePath()
      ctx.fill() if @fillStyle
      ctx.stroke() if @lineWidth && @strokeStyle

class CropBox extends Drawable
  constructor: (options) ->
    super _.extend
      dragable: true
    , options

    @image = options.image
    @handleSize = options.handleSize || 10
    @screenStyle = options.screenStyle || 'rgba(0, 0, 0, .75)'

    @topScreen    = new Rectangle fillStyle: @screenStyle
    @leftScreen   = new Rectangle fillStyle: @screenStyle
    @rightScreen  = new Rectangle fillStyle: @screenStyle
    @bottomScreen = new Rectangle fillStyle: @screenStyle

    @dragging = null

    @handles = {}

  frame: () ->
    {
      x: if @w < 0 then @x + @w else @x
      y: if @h < 0 then @y + @h else @y
      w: Math.abs @w
      h: Math.abs @h
    }

  bounds: () ->
    {
      x: 0
      y: 0
      w: Math.abs @w
      h: Math.abs @h
    }

  containsCanvasPoint: (point) ->
    local = @convertFromCanvas point
    containsPoint = @containsPoint local
    return containsPoint if containsPoint

    # if the body doesn't contain the point, check the handles, which are rendered partly outside the bounds
    # of the crop tool
    for direction, handle of @handles
      return true if handle.containsCanvasPoint point

    return false

  mouseOut: (point) ->
    @canvas.style.cursor = 'default'

  mouseMove: (point) ->
    for direction, handle of @handles
      if handle.containsCanvasPoint point
        switch direction
          when 'tl'
            @canvas.style.cursor = 'nw-resize'
          when 'tm'
            @canvas.style.cursor = 'n-resize'
          when 'tr'
            @canvas.style.cursor = 'ne-resize'
          when 'ml'
            @canvas.style.cursor = 'w-resize'
          when 'mr'
            @canvas.style.cursor = 'e-resize'
          when 'bl'
            @canvas.style.cursor = 'sw-resize'
          when 'bm'
            @canvas.style.cursor = 's-resize'
          when 'br'
            @canvas.style.cursor = 'se-resize'
        return

    @canvas.style.cursor = 'move'


  mouseDown: (point) ->
  mouseUp: (point) ->
    @dragging = null
  dragStart: (point) ->
    for direction, handle of @handles
      if handle.containsCanvasPoint point
        localPoint = handle.convertFromCanvas point
        @dragging =
          resizeDirection: direction
          object: handle
          offsetX: localPoint.x
          offsetY: localPoint.y
        return

    localPoint = @convertFromCanvas point

    @dragging =
      object: @
      offsetX: localPoint.x
      offsetY: localPoint.y

  constrainPointInParent: (point) ->
    {
      x: Math.min Math.max(point.x, 0), @parent.frame().w
      y: Math.min Math.max(point.y, 0), @parent.frame().h
    }

  dragMove: (point) ->
    if @dragging?.object == @
      # move the whole crop area
      localPoint = @convertFromCanvas point
      @moveTo
        x: localPoint.x - @dragging.offsetX
        y: localPoint.y - @dragging.offsetY
    else if @dragging?.resizeDirection
      parentPoint = @parent.convertFromCanvas point

      switch @dragging.resizeDirection
        when 'tl'
          point = @constrainPointInParent parentPoint
          @w = @w + (@x - point.x)
          @h = @h + (@y - point.y)
          @x = point.x
          @y = point.y
        when 'tm'
          point = @constrainPointInParent parentPoint
          @w = @w
          @h = @h + (@y - point.y)
          @x = @x
          @y = point.y
        when 'tr'
          point = @constrainPointInParent parentPoint
          @w = (point.x - @x)
          @h = @h + (@y - point.y)
          @x = @x
          @y = point.y
        when 'ml'
          point = @constrainPointInParent parentPoint
          @w = @w + (@x - point.x)
          @h = @h
          @x = point.x
          @y = @y
        when 'mr'
          point = @constrainPointInParent parentPoint
          @w = (point.x - @x)
          @h = @h
          @x = @x
          @y = @y
        when 'bl'
          point = @constrainPointInParent parentPoint
          @w = @w + (@x - point.x)
          @h = (point.y - @y)
          @x = point.x
          @y = @y
        when 'bm'
          point = @constrainPointInParent parentPoint
          @w = @w
          @h = (point.y - @y)
          @x = @x
          @y = @y
        when 'br'
          point = @constrainPointInParent parentPoint
          @w = (point.x - @x)
          @h = (point.y - @y)
          @x = @x
          @y = @y

  dragEnd: (point) ->
    # reset our frame after a drag to fix negative widths/heights used during
    # the dragging process
    frame = @frame()
    @x = frame.x
    @y = frame.y
    @w = frame.w
    @h = frame.h

  click: (point) ->

  moveTo: (point) ->
    pos = @convertToParent point

    x = Math.max 0, pos.x
    y = Math.max 0, pos.y
    x = Math.min @parent.bounds().w - @w, x
    y = Math.min @parent.bounds().h - @h, y

    @x = x
    @y = y

  drawScreen: (ctx) ->
    frame = @frame()

    @topScreen.set
      parent: @parent
      x: 0
      y: 0
      w: @parent.w
      h: frame.y

    @bottomScreen.set
      parent: @parent
      x: 0
      y: frame.y + frame.h
      w: @parent.w
      h: @parent.h - (frame.y + frame.h)

    @leftScreen.set
      parent: @parent
      x: 0
      y: frame.y
      w: frame.x
      h: frame.h

    @rightScreen.set
      parent: @parent
      x: frame.x + frame.w
      y: frame.y
      w: @parent.w - (frame.x + frame.w)
      h: frame.h

    @topScreen.draw ctx
    @leftScreen.draw ctx
    @rightScreen.draw ctx
    @bottomScreen.draw ctx

  drawHandles: (ctx) ->
    frame = @frame()

    newRect = (x, y) =>
      return new Rectangle
        parent: @
        x: x - (@handleSize / 2) - 0.5
        y: y - (@handleSize / 2) - 0.5
        w: @handleSize
        h: @handleSize
        lineWidth: 1
        strokeStyle: 'rgba(192, 192, 192, 1)'
        fillStyle: 'rgba(64, 64, 64, 1)'

    @handles["tl"] = newRect 0, 0
    @handles["tm"] = newRect (frame.w / 2), 0
    @handles["tr"] = newRect frame.w, 0

    @handles["ml"] = newRect 0, (frame.h / 2)
    @handles["mr"] = newRect frame.w, (frame.h / 2)

    @handles["bl"] = newRect 0, frame.h
    @handles["bm"] = newRect (frame.w / 2), frame.h
    @handles["br"] = newRect frame.w, frame.h

    for direction, handle of @handles
      handle.draw ctx

  drawCropLines: (ctx) ->
    frame = @frame()
    opacity = "0.5"
    lineDash = 8

    @isolateAndMoveToParent ctx, (ctx) =>
      ctx.beginPath()
      ctx.strokeStyle = "rgba(255,255,255,#{opacity})"
      ctx.rect 0.5, 0.5, frame.w, frame.h
      ctx.closePath()
      ctx.stroke()

      ctx.beginPath()
      ctx.strokeStyle = "rgba(0,0,0,#{opacity})"
      ctx.setLineDash [lineDash]
      ctx.rect 0.5, 0.5, frame.w, frame.h
      ctx.closePath()
      ctx.stroke()

      for x in [ frame.w / 3 + 0.5, (frame.w / 3) * 2 + 0.5 ]
        ctx.beginPath()
        ctx.moveTo x, 0
        ctx.strokeStyle = "rgba(255,255,255,#{opacity})"
        ctx.setLineDash []
        ctx.lineTo x, frame.h
        ctx.stroke()

        ctx.beginPath()
        ctx.moveTo x, 0
        ctx.strokeStyle = "rgba(0,0,0,#{opacity})"
        ctx.setLineDash [lineDash]
        ctx.lineTo x, frame.h
        ctx.stroke()

      for y in [ frame.h / 3 + 0.5, (frame.h / 3) * 2 + 0.5 ]
        ctx.beginPath()
        ctx.moveTo 0, y
        ctx.strokeStyle = "rgba(255,255,255,#{opacity})"
        ctx.setLineDash []
        ctx.lineTo frame.w, y
        ctx.stroke()

        ctx.beginPath()
        ctx.moveTo 0, y
        ctx.strokeStyle = "rgba(0,0,0,#{opacity})"
        ctx.setLineDash [lineDash]
        ctx.lineTo frame.w, y
        ctx.stroke()

  draw: (ctx) ->
    @drawScreen ctx
    @drawCropLines ctx
    @drawHandles ctx

class Stage extends Drawable
  initialize: (options) ->
    @canvas = options.canvas

  frame: ->
    {
      x: 0
      y: 0
      w: @canvas.width
      h: @canvas.height
    }

  bounds: ->
    @frame()

  onCanvasSizeChange: () ->
    for child in @children
      child.onCanvasSizeChange()

  draw: (ctx) ->
    @drawChildren ctx

  clear: (ctx) ->
    ctx.clearRect 0, 0, @canvas.width, @canvas.height

class window.RodeoCrop
  constructor: (el, options) ->
    @el = if _.isString el
      document.querySelector el
    else
      el

    @options = _.extend
      cropEnabled: true
      cropX: null
      cropY: null
      cropWidth: null
      cropHeight: null
      width: 100
      height: 100
      imageSource: null
    , options

    @valid = false
    @ctx = null
    @stage = null
    @imageSource = @options.imageSource

    @initializeCanvas()
    @createStage()
    @createImage()
    @createCropBox()
    @attachListeners()
    @runLoop()

  initializeCanvas: () ->
    @canvas = document.createElement 'canvas'
    @canvas.width = @options.width
    @canvas.height = @options.height

    @el.appendChild @canvas

    @ctx = @canvas.getContext '2d'

  createStage: () ->
    @stage = new Stage
      canvas: @canvas

  createImage: () ->
    @image = new CanvasImage
      canvas: @canvas
      source: @imageSource
      onLoad: () =>
        @valid = false
        @image.resizeToParent()
        @image.centerOnParent()

      onCanvasSizeChange: () =>
        @image.resizeToParent()
        @image.centerOnParent()

    @stage.addChild @image

  createCropBox: () ->
    @cropBox = new CropBox
      canvas: @canvas
      image: @image
      x: 10
      y: 10
      w: 150
      h: 150

    @image.addChild @cropBox

  attachListeners: () ->
    globalToCanvas = (e) =>
      rect = @canvas.getBoundingClientRect()
      x = e.clientX - rect.left
      y = e.clientY - rect.top

      {
        x: x
        y: y
      }

    @canvas.addEventListener 'mouseup', (e) =>
      pos = globalToCanvas e

      if @dragging
        @dragging.dragEnd pos
        @dragging.mouseUp pos
      else if @mouseDown
        @mouseDown.mouseUp pos
        @mouseDown.click pos
      else
        pos = globalToCanvas e
        @cropBox.mouseUp pos if @cropBox.containsCanvasPoint pos

      @dragging = @mouseDown = null

    @canvas.addEventListener 'mousedown', (e) =>
      pos = globalToCanvas e

      if @cropBox.containsCanvasPoint pos
        @mouseDown = @cropBox
        @cropBox.mouseDown pos

    @canvas.addEventListener 'mousemove', (e) =>
      if @dragging || @mouseDown
        pos = globalToCanvas e

        if ! @dragging
          @dragging = @mouseDown
          @dragging.dragStart pos

        @dragging.dragMove pos
        @valid = false
      else
        pos = globalToCanvas e
        cropboxContainsPoint = @cropBox.containsCanvasPoint pos

        if cropboxContainsPoint && @mouseOver != @cropBox
          @mouseOver?.mouseOut pos if @mouseOver
          @mouseOver = @cropBox
          @cropBox.mouseIn pos
        else if cropboxContainsPoint && @mouseOver == @cropBox
          @cropBox.mouseMove pos
        else if ! cropboxContainsPoint && @mouseOver == @cropBox
          @mouseOver.mouseOut pos
          @mouseOver = null


  updateCanvasSize: () ->
    w = window.getComputedStyle(@canvas.parentNode).getPropertyValue 'width'
    h = window.getComputedStyle(@canvas.parentNode).getPropertyValue 'height'
    w = parseInt w, 10
    h = parseInt h, 10

    if @canvas.width != w || @canvas.height != h
      @canvas.width = w
      @canvas.height = h

      true
    else
      false

  runLoop: (arg) ->
    canvasSizeChanged = @updateCanvasSize()
    @valid = false if canvasSizeChanged

    unless @valid
      @stage.clear @ctx
      @stage.onCanvasSizeChange() if canvasSizeChanged
      @stage.draw @ctx

    @valid = true
    window.requestAnimationFrame => @runLoop()
