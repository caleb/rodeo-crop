`import _ from "funderscore"`
`import Events from "events"`

drawing = {}

class Drawable extends Events
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
    @enabled = options.enabled || true

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
      child.draw ctx if child.enabled

  draw: (ctx) ->
    # noop

drawing.Drawable = Drawable

class CanvasImage extends Drawable
  constructor: (options) ->
    super options

    @source = options.source
    @naturalWidth = options.naturalWidth
    @naturalHeight = options.naturalHeight
    @originalNaturalBounds = @naturalBounds()
    @cropped = false
    @cropStack = []
    @loaded = false

    @cropX = 0
    @cropY = 0
    @cropWidth = @naturalWidth
    @cropHeight = @naturalHeight

    @loadImage()

  clearImage: () ->
    @loaded = false
    @cropped = false
    @w = null
    @h = null
    @naturalWidth = null
    @naturalHeight = null
    @cropStack = []
    @originalNaturalBounds = @naturalBounds()

  setSource: (source) ->
    @clearImage()
    @source = source
    @loadImage()

  naturalBounds: () ->
    {
      x: 0
      y: 0
      w: @naturalWidth
      h: @naturalHeight
    }

  cropFrame: () ->
    {
      x: @cropX
      y: @cropY
      w: @cropWidth
      h: @cropHeight
    }

  crop: (frame) ->
    unless @cropped
      @cropped = true
      @cropX = @cropY = 0

    @cropX = frame.x + @cropX
    @cropY = frame.y + @cropY
    @cropWidth = frame.width
    @cropHeight = frame.height

    @naturalWidth = @cropWidth
    @naturalHeight = @cropHeight

    @resizeToParent()
    @centerOnParent()

    @cropStack.push @cropFrame()

    @trigger 'crop', @, @cropStack[@cropStack.length - 2], @cropFrame()

  undoCrop: () ->
    @cropped = true

    if @cropStack.length > 1
      previousCropFrame = @cropStack.pop()
      newCropFrame = @cropStack[@cropStack.length - 1]

      @cropX = newCropFrame.x
      @cropY = newCropFrame.y
      @cropWidth = newCropFrame.w
      @cropHeight = newCropFrame.h
      @naturalWidth = newCropFrame.w
      @naturalHeight = newCropFrame.h

      @resizeToParent()
      @centerOnParent()

      @trigger 'crop', @, previousCropFrame, @cropFrame()

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

    @trigger 'resize', @frame()

  centerOnParent: () ->
    @x = ((@parent.frame().w / 2) - (@w / 2))|0
    @y = ((@parent.frame().h / 2) - (@h / 2))|0

    @trigger 'reposition', @frame()

  draw: (ctx) ->
    @isolateAndMoveToParent ctx, (ctx) ->
      if @cropped
        ctx.drawImage @img, @cropX, @cropY, @cropWidth, @cropHeight, 0, 0, @w, @h
      else
        ctx.drawImage @img, 0, 0, @w, @h

    @drawChildren ctx

  loadImage: ->
    @img = document.createElement 'img'
    @img.onload = =>
      @loaded = true
      @naturalWidth = @img.naturalWidth
      @naturalHeight = @img.naturalHeight

      @cropX = 0
      @cropY = 0
      @cropWidth = @img.naturalWidth
      @cropHeight = @img.naturalHeight

      @cropStack.push @cropFrame()

      @trigger 'load', @
    @img.src = @source

drawing.CanvasImage = CanvasImage

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

drawing.Rectangle = Rectangle

`export default drawing`
