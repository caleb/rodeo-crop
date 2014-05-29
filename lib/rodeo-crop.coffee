`import _ from "funderscore"`
`import drawing from "drawing"`

RodeoCrop = {}

class CropBox extends drawing.Drawable
  constructor: (options) ->
    super _.extend
      dragable: true
    , options

    @image = options.image
    @handleSize = options.handleSize || 10
    @screenStyle = options.screenStyle || 'rgba(0, 0, 0, .75)'

    @topScreen    = new drawing.Rectangle fillStyle: @screenStyle
    @leftScreen   = new drawing.Rectangle fillStyle: @screenStyle
    @rightScreen  = new drawing.Rectangle fillStyle: @screenStyle
    @bottomScreen = new drawing.Rectangle fillStyle: @screenStyle

    @cropX = options.cropX || 0
    @cropY = options.cropY || 0
    @cropWidth = options.cropWidth || @handleSize * 4
    @cropHeight = options.cropHeight || @handleSize * 4

    @onCropFrameChanged = options.onCropFrameChanged || null

    @dragging = null

    @handles = {}

  frame: () ->
    {
      x: if @w < 0 then @x + @w else @x
      y: if @h < 0 then @y + @h else @y
      w: Math.abs @w
      h: Math.abs @h
    }

  cropFrame: () ->
    {
      x: @cropX
      y: @cropY
      width: @cropWidth
      height: @cropHeight
    }

  updateCropAreaFromFrame: () ->
    frame = @frame()
    naturalBounds = @image.naturalBounds()
    imageBounds = @image.bounds()

    if imageBounds.w && imageBounds.h
      @cropX      = (naturalBounds.w * (frame.x / imageBounds.w))
      @cropY      = (naturalBounds.h * (frame.y / imageBounds.h))
      @cropWidth  = (naturalBounds.w * (frame.w / imageBounds.w))
      @cropHeight = (naturalBounds.h * (frame.h / imageBounds.h))

    @onCropFrameChanged? @cropFrame()

  setFrameAndUpdateCropArea: (frame) ->
    @x = frame.x
    @y = frame.y
    @w = frame.w
    @h = frame.h

    @updateCropAreaFromFrame()

  updateFrameFromCropArea: () ->
    naturalBounds = @image.naturalBounds()
    imageBounds = @image.bounds()

    if imageBounds.w && imageBounds.h
      @x = (imageBounds.w * (@cropX / naturalBounds.w))
      @y = (imageBounds.h * (@cropY / naturalBounds.h))
      @w = (imageBounds.w * (@cropWidth / naturalBounds.w))
      @h = (imageBounds.h * (@cropHeight / naturalBounds.h))

  setCropAreaAndUpdateFrame: (cropArea) ->
    naturalBounds = @image.naturalBounds()

    @cropX      = Math.min(Math.max(cropArea.x, 0.0), naturalBounds.w)
    @cropY      = Math.min(Math.max(cropArea.y, 0.0), naturalBounds.h)
    @cropWidth  = Math.min(Math.max(cropArea.width, 0.0), naturalBounds.w - @cropX)
    @cropHeight = Math.min(Math.max(cropArea.height, 0.0), naturalBounds.h - @cropY)

    @updateFrameFromCropArea()

  bounds: () ->
    {
      x: 0
      y: 0
      w: Math.abs @w
      h: Math.abs @h
    }

  onCanvasSizeChange: () ->
    # move/size the crop area based on the image size
    @updateFrameFromCropArea()

  containsCanvasPoint: (point) ->
    local = @convertFromCanvas point
    containsPoint = @containsPoint local
    return containsPoint if containsPoint

    # if the body doesn't contain the point, check the handles, which are rendered partly outside the bounds
    # of the crop tool
    for direction, handle of @handles
      return true if handle.containsCanvasPoint point

    return false

  onMouseOut: (point) ->
    @canvas.style.cursor = 'default'

  onMouseMove: (point) ->
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

  constrainPointInParent: (point) ->
    {
      x: Math.min Math.max(point.x, 0), @parent.frame().w
      y: Math.min Math.max(point.y, 0), @parent.frame().h
    }

  onMouseDown: (point) ->
  onMouseUp: (point) ->
    @dragging = null
  onDragStart: (point) ->
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

  onDragMove: (point) ->
    if @dragging?.object == @
      # move the whole crop area
      localPoint = @convertFromCanvas point
      @moveTo
        x: localPoint.x - @dragging.offsetX
        y: localPoint.y - @dragging.offsetY

      @updateCropAreaFromFrame()
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

      @updateCropAreaFromFrame()

  onDragEnd: (point) ->
    # reset our frame after a drag to fix negative widths/heights used during
    # the dragging process
    frame = @frame()
    @x = frame.x
    @y = frame.y
    @w = frame.w
    @h = frame.h

  onClick: (point) ->

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
    frame.x = Math.round frame.x
    frame.y = Math.round frame.y
    frame.w = Math.round frame.w
    frame.h = Math.round frame.h

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
    frame.x = Math.round frame.x
    frame.y = Math.round frame.y
    frame.w = Math.round frame.w
    frame.h = Math.round frame.h

    newRect = (x, y) =>
      return new drawing.Rectangle
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
    frame.x = Math.round frame.x
    frame.y = Math.round frame.y
    frame.w = Math.round frame.w
    frame.h = Math.round frame.h

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

class Stage extends drawing.Drawable
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
    super()
    for child in @children
      child.onCanvasSizeChange()

  draw: (ctx) ->
    @drawChildren ctx

  clear: (ctx) ->
    ctx.clearRect 0, 0, @canvas.width, @canvas.height

class Cropper
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
      onCropFrameChanged: null
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
    @image = new drawing.CanvasImage
      canvas: @canvas
      source: @imageSource
      onLoad: () =>
        @valid = false
        @image.resizeToParent()
        @image.centerOnParent()

        @cropBox.updateFrameFromCropArea()

      onCanvasSizeChange: () =>
        @image.resizeToParent()
        @image.centerOnParent()

    @stage.addChild @image

  createCropBox: () ->
    @cropBox = new CropBox
      canvas: @canvas
      image: @image
      cropX: @options.cropX
      cropY: @options.cropY
      cropWidth: @options.cropWidth
      cropHeight: @options.cropHeight

      onCropFrameChanged: (cropFrame) =>
        @options.onCropFrameChanged? cropFrame

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

    window.addEventListener 'mouseup', (e) =>
      pos = globalToCanvas e

      if @dragging
        @dragging.onDragEnd pos
        @dragging.onMouseUp pos
      else if @mouseDown
        @mouseDown.onMouseUp pos
        @mouseDown.onClick pos
      else
        pos = globalToCanvas e
        @cropBox.onMouseUp pos if @cropBox.containsCanvasPoint pos

      @dragging = @mouseDown = null

    window.addEventListener 'mousedown', (e) =>
      pos = globalToCanvas e

      if @cropBox.containsCanvasPoint pos
        @mouseDown = @cropBox
        @cropBox.onMouseDown pos

    window.addEventListener 'mousemove', (e) =>
      if @dragging || @mouseDown
        pos = globalToCanvas e

        if ! @dragging
          @dragging = @mouseDown
          @dragging.onDragStart pos

        @dragging.onDragMove pos
        @valid = false
      else
        pos = globalToCanvas e
        cropboxContainsPoint = @cropBox.containsCanvasPoint pos

        if cropboxContainsPoint && @mouseOver != @cropBox
          @mouseOver?.onMouseOut pos if @mouseOver
          @mouseOver = @cropBox
          @cropBox.onMouseIn? pos
        else if cropboxContainsPoint && @mouseOver == @cropBox
          @cropBox.onMouseMove? pos
        else if ! cropboxContainsPoint && @mouseOver == @cropBox
          @mouseOver.onMouseOut? pos
          @mouseOver = null

  setCropFrame: (frame) ->
    @cropBox.setCropAreaAndUpdateFrame frame
    @valid = false

    @cropBox.cropFrame()

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

RodeoCrop.Cropper = Cropper

`export default RodeoCrop`
