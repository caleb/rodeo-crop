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
    @fillParent = if _.isBoolean(options.fillParent) then options.fillParent else true

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

  # Returns the whole frame for this container, including the padding
  outerFrame: () ->
    if @fillParent
      parentFrame = @parent.frame()
      {
        x: @padding
        y: @padding
        w: parentFrame.w
        h: parentFrame.h
      }
    else
      {
        x: @x
        y: @y
        w: @w
        h: @h
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

  setFrame: (newFrame) ->
    @w = newFrame.w + 2 * @padding if newFrame.w
    @h = newFrame.h + 2 * @padding if newFrame.h
    @x = newFrame.x - @padding if newFrame.x
    @y = newFrame.y - @padding if newFrame.y

drawing.PaddedContainer = PaddedContainer

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
