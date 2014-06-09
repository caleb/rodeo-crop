`import drawing from "drawing"`

class CanvasImage extends drawing.Drawable
  constructor: (options) ->
    super options

    @source = options.source
    @naturalWidth = options.naturalWidth
    @naturalHeight = options.naturalHeight
    @originalNaturalBounds = @naturalBounds()
    @cropped = false
    @history = []
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
    @history = []
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

    previousCrop = @cropFrame()

    @cropX = frame.x + @cropX
    @cropY = frame.y + @cropY
    @cropWidth = frame.width
    @cropHeight = frame.height

    @naturalWidth = @cropWidth
    @naturalHeight = @cropHeight

    @resizeToParent()
    @centerOnParent()

    @history.push
      action: 'crop'
      fromCropFrame: previousCrop
      toCropFrame: @cropFrame()

    @trigger 'crop', @, previousCrop, @cropFrame()

    @markDirty()

  undoCrop: () ->
    if @history.length > 0
      cropHistory = @history.pop()
      newCropFrame = cropHistory.fromCropFrame

      @cropX = newCropFrame.x
      @cropY = newCropFrame.y
      @cropWidth = newCropFrame.w
      @cropHeight = newCropFrame.h
      @naturalWidth = newCropFrame.w
      @naturalHeight = newCropFrame.h

      @resizeToParent()
      @centerOnParent()

      @cropped = false if @history.length == 0

      @trigger 'crop', @, cropHistory.toCropFrame, @cropFrame()

      @markDirty()

  revertImage: () ->
    @cropped = false

    if @history.length > 0
      cropHistory = @history.pop()

      @cropX = 0
      @cropY = 0
      @cropWidth = @originalNaturalBounds.w
      @cropHeight = @originalNaturalBounds.h
      @naturalWidth = @originalNaturalBounds.w
      @naturalHeight = @originalNaturalBounds.h

      @resizeToParent()
      @centerOnParent()

      @trigger 'crop', @, cropHistory.toCropFrame, @cropFrame()

      @history = []

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
      @history = []

      @cropX = 0
      @cropY = 0
      @cropWidth = @img.naturalWidth
      @cropHeight = @img.naturalHeight

      @originalNaturalBounds = @naturalBounds()

      @markDirty()

      @trigger 'load', @
    @img.src = @source

`export default CanvasImage`
