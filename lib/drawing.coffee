`import _ from "rodeo-crop/funderscore"`

drawing = {}

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

drawing.Drawable = Drawable

class CanvasImage extends Drawable
  constructor: (options) ->
    super options

    @source = options.source
    @naturalWidth = options.naturalWidth
    @naturalHeight = options.naturalHeight
    @onLoad = options.onLoad

    @loadImage()

  naturalBounds: () ->
    {
      x: 0
      y: 0
      w: @naturalWidth
      h: @naturalHeight
    }

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

  onCanvasSizeChange:  ->
    super()
    for child in @children
      child.onCanvasSizeChange()

  loadImage: ->
    @img = document.createElement 'img'
    @img.onload = =>
      @naturalWidth = @img.naturalWidth
      @naturalHeight = @img.naturalHeight
      @onLoad.call @ if _.isFunction @onLoad
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
