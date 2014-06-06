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
    @dirty = true
    @scale = options.scale
    @parent = options.parent
    @canvas = options.canvas
    @children = options.children || []
    @dragable = options.dragable || false
    @enabled = if options.enabled != undefined then !!options.enabled else true

  set: (options) ->
    for own key, value of options
      @[key] = value

  enable: (enabled) ->
    previous = @enabled
    @enabled = !!enabled
    @markDirty()
    if previous != @enabled
      if @enabled
        @trigger 'enabled', @
      else
        @trigger 'disabled', @

  markDirty: () ->
    @dirty = true
    @parent.markDirty() if @parent

  bubble: (eventName, event, args...) ->
    event.currentTarget = @
    @trigger.apply @, arguments

    parent = @parent
    while parent
      # clone the event so we can change the current target for this listening node
      event = _.clone event
      event.currentTarget = parent
      parent.trigger.apply parent, [eventName, event].concat(args)
      parent = parent.parent

  findChildAtPoint: (point) ->
    i = @children.length - 1
    while i >= 0
      child = @children[i]
      grandChild = child.findChildAtPoint point
      if grandChild
        return grandChild
      else
        return child if child.containsCanvasPoint point
      i--

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
    @markDirty()

  removeChild: (child) ->
    i = @children.indexOf child
    if i >= 0
      child.parent = null
      @children.splice i, 1
      @markDirty()

  renderChildren: (ctx) ->
    for child in @children
      child.render ctx if child.enabled

  clear: (ctx) ->
    frame = @frame()
    if @parent
      positionContext ctx, (ctx) =>
        ctx.clearRect frame.x, frame.y, frame.w, frame.h
    else
      ctx.clearRect frame.x, frame.y, frame.w, frame.h

  render: (ctx) ->
    ctx.save()
    @draw ctx
    ctx.restore()
    @renderChildren ctx
    @dirty = false

  draw: (ctx) ->
    # noop

drawing.Drawable = Drawable

class PaddedContainer extends Drawable
  constructor: (options = {}) ->
    super options

    @padding = options.padding || 10
    @fillParent = options.fillParent || true

  frame: () ->
    if @fillParent
      parentFrame = @parent.frame()
      {
        x: @padding
        y: @padding
        w: parentFrame.w - 2 * @padding
        h: parentFrame.h - 2 * @padding
      }
    else
      {
        x: @x + @padding
        y: @y + @padding
        w: @w - 2 * @padding
        h: @h - 2 * @padding
      }

  bounds: () ->
    if @fillParent
      parentFrame = @parent.frame()
      {
        x: 0
        y: 0
        w: parentFrame.w - 2 * @padding
        h: parentFrame.h - 2 * @padding
      }
    else
      {
        x: 0
        y: 0
        w: @w - 2 * @padding
        h: @h - 2 * @padding
      }

drawing.PaddedContainer = PaddedContainer

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

    @markDirty()

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

    @markDirty()

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

      @markDirty()

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

  toDataURL: (format = 'image/png') ->
    canvas = document.createElement 'canvas'
    canvas.width = @cropWidth
    canvas.height = @cropHeight
    ctx = canvas.getContext '2d'

    if @cropped
      ctx.drawImage @img, @cropX, @cropY, @cropWidth, @cropHeight, 0, 0, @cropWidth, @cropHeight
    else
      ctx.drawImage @img, 0, 0, @cropWidth, @cropHeight

    canvas.toDataURL format

  draw: (ctx) ->
    @positionContext ctx, (ctx) ->
      if @cropped
        ctx.drawImage @img, @cropX, @cropY, @cropWidth, @cropHeight, 0, 0, @w, @h
      else
        ctx.drawImage @img, 0, 0, @w, @h

  loadImage: ->
    @img = document.createElement 'img'
    @img.onload = =>
      @loaded = true
      @naturalWidth = @img.naturalWidth
      @naturalHeight = @img.naturalHeight

      @cropped = false
      @cropStack = []

      @cropX = 0
      @cropY = 0
      @cropWidth = @img.naturalWidth
      @cropHeight = @img.naturalHeight

      @cropStack.push @cropFrame()

      @markDirty()

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
    @positionContext ctx, (ctx) =>
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
