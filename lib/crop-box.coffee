`import _ from "funderscore"`
`import drawing from "drawing"`

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
    @cropWidth = options.cropWidth
    @cropHeight = options.cropHeight

    @marchingAnts = options.marchingAnts || true

    @dashOffset = 0

    @dragging = null
    @mouseDown = false

    @handles = {}

    @image.on 'load', () =>
      # reposition the frame when the image is loaded
      @setCropFrameAndUpdateFrame @cropFrame()

    @image.on 'crop', (image, previousCrop, crop) =>
      # reposition the frame when the image is loaded
      @cropX = if previousCrop.w >= crop.w then 0 else previousCrop.x - crop.x
      @cropY = if previousCrop.h >= crop.h then 0 else previousCrop.y - crop.y
      @cropWidth = if previousCrop.w >= crop.w then crop.w else previousCrop.w
      @cropHeight = if previousCrop.h >= crop.h then crop.h else previousCrop.h
      @setCropFrameAndUpdateFrame @cropFrame()

    @on 'mouseout', @onMouseOut
    @on 'mousemove', @onMouseMove
    @on 'mousedown', @onMouseDown
    @on 'mouseup', @onMouseUp
    @on 'dragstart', @onDragStart
    @on 'dragend', @onDragEnd
    @on 'dragmove', @onDragMove

    @setLooseTheAnts()

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

  updateCropFrameFromFrame: () ->
    frame = @frame()
    naturalBounds = @image.naturalBounds()
    imageBounds = @image.bounds()

    if @image.loaded
      @cropX      = (naturalBounds.w * (frame.x / imageBounds.w))
      @cropY      = (naturalBounds.h * (frame.y / imageBounds.h))
      @cropWidth  = (naturalBounds.w * (frame.w / imageBounds.w))
      @cropHeight = (naturalBounds.h * (frame.h / imageBounds.h))

    @trigger 'change:cropFrame', @cropFrame()

  setFrameAndUpdateCropArea: (frame) ->
    @x = frame.x
    @y = frame.y
    @w = frame.w
    @h = frame.h

    @updateCropFrameFromFrame()
    @markDirty()

  updateFrameFromCropFrame: () ->
    if @image.loaded
      naturalBounds = @image.naturalBounds()
      imageBounds = @image.bounds()

      @x = (imageBounds.w * (@cropX / naturalBounds.w))
      @y = (imageBounds.h * (@cropY / naturalBounds.h))
      @w = (imageBounds.w * (@cropWidth / naturalBounds.w))
      @h = (imageBounds.h * (@cropHeight / naturalBounds.h))

      @markDirty()

  setCropFrameAndUpdateFrame: (cropArea) ->
    # if the image is loaded, constrain the crop frame to the natural
    # image size
    #
    # Also update the drawn frame from the new crop frame
    if @image.loaded
      naturalBounds = @image.naturalBounds()

      # load up some sane defaults if the crop area components are null
      newCropX      = cropArea?.x || naturalBounds.w * .125
      newCropY      = cropArea?.y || naturalBounds.h * .125
      newCropWidth  = cropArea?.width || naturalBounds.w * .75
      newCropHeight = cropArea?.height || naturalBounds.h * .75

      @cropX      = Math.min(Math.max(newCropX, 0), naturalBounds.w)
      @cropY      = Math.min(Math.max(newCropY, 0), naturalBounds.h)
      @cropWidth  = Math.min(Math.max(newCropWidth, 0), naturalBounds.w - @cropX)
      @cropHeight = Math.min(Math.max(newCropHeight, 0), naturalBounds.h - @cropY)

      @updateFrameFromCropFrame()
    else
      # our image isn't loaded, so just set the crop area, and
      # assume that we will update the frame and constrain it when
      # it is loaded
      @cropX = cropArea?.x
      @cropY = cropArea?.y
      @cropWidth = cropArea?.width
      @cropHeight = cropArea?.height

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

  onMouseOut: (e) ->
    @canvas.style.cursor = 'default'

  onMouseMove: (e) ->
    return unless @enabled

    point = e.canvasPoint

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

  onMouseUp: (point) ->
    @dragging = @mouseDown = null

  onDragStart: (e) ->
    point = e.canvasPoint

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

  onDragMove: (e) ->
    point = e.canvasPoint

    if @dragging?.object == @
      # move the whole crop area
      localPoint = @convertFromCanvas point
      @moveTo
        x: localPoint.x - @dragging.offsetX
        y: localPoint.y - @dragging.offsetY

      @updateCropFrameFromFrame()
      @markDirty()
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

      @updateCropFrameFromFrame()
      @markDirty()

  onDragEnd: (e) ->
    point = e.canvasPoint

    # reset our frame after a drag to fix negative widths/heights used during
    # the dragging process
    frame = @frame()
    @x = frame.x
    @y = frame.y
    @w = frame.w
    @h = frame.h

    # trigger our change event at the end of the change
    @trigger 'change', @cropFrame()

  onClick: (e) ->

  moveTo: (point) ->
    pos = @convertToParent point

    x = Math.max 0, pos.x
    y = Math.max 0, pos.y
    x = Math.min @parent.bounds().w - @w, x
    y = Math.min @parent.bounds().h - @h, y

    @x = x
    @y = y

  setLooseTheAnts: ->
    animationFn = () =>
      if @marchingAnts
        @dashOffset += 0.15
        @markDirty()
      window.requestAnimationFrame animationFn

    window.requestAnimationFrame animationFn

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

    @topScreen.render ctx
    @leftScreen.render ctx
    @rightScreen.render ctx
    @bottomScreen.render ctx

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
      handle.render ctx

  drawCropLines: (ctx) ->
    frame = @frame()
    frame.x = Math.round frame.x
    frame.y = Math.round frame.y
    frame.w = Math.round frame.w
    frame.h = Math.round frame.h

    opacity = "0.5"
    lineDash = 4

    @positionContext ctx, (ctx) =>
      ctx.lineDashOffset = @dashOffset

      ctx.beginPath()
      ctx.strokeStyle = "rgba(255,255,255,#{1||opacity})"
      ctx.rect 0.5, 0.5, frame.w, frame.h
      ctx.closePath()
      ctx.stroke()

      ctx.beginPath()
      ctx.strokeStyle = "rgba(0,0,0,#{1||opacity})"
      ctx.setLineDash [lineDash]
      ctx.rect 0.5, 0.5, frame.w, frame.h
      ctx.closePath()
      ctx.stroke()

      ctx.lineDashOffset = 0

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

`export default CropBox`
