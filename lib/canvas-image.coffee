`import _ from "funderscore"`
`import drawing from "drawing"`

class CanvasImage extends drawing.Drawable
  constructor: (options) ->
    super options

    @source = options.source
    @naturalWidth = options.naturalWidth
    @naturalHeight = options.naturalHeight
    @originalNaturalBounds = @naturalBounds()
    @brightness = 0
    @contrast = 0
    @cropped = false
    @history = []
    @loaded = false

    @cropX = 0
    @cropY = 0
    @cropWidth = @naturalWidth
    @cropHeight = @naturalHeight

    @updateBrightnessAndContrastTable()

    @loadImage()

  clearImage: () ->
    @loaded = false
    @cropped = false
    @brightness = 0
    @contrast = 0
    @w = null
    @h = null
    @naturalWidth = null
    @naturalHeight = null
    @history = []
    @originalNaturalBounds = @naturalBounds()

    @updateBrightnessAndContrastTable()

    @markDirty()

  getSource: ->
    @source

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

  adjustBrightness: (brightness) ->
    previousBrightness = @brightness

    @brightness = brightness
    @updateBrightnessAndContrastTable()

    @history.push
      action: 'adjustBrightness'
      fromBrightness: previousBrightness
      toBrightness: brightness

    @trigger 'adjustBrightness', @, previousBrightness, @brightness

    @markDirty()

  adjustContrast: (contrast) ->
    previousContrast = @contrast

    @contrast = contrast
    @updateBrightnessAndContrastTable()

    @history.push
      action: 'adjustContrast'
      fromContrast: previousContrast
      toContrast: contrast

    @trigger 'adjustContrast', @, previousContrast, @contrast

    @markDirty()

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

  undo: () ->
    if @history.length > 0
      action = @history.pop()

      switch action.action
        when 'crop'
          newCropFrame = action.fromCropFrame

          @cropX = newCropFrame.x
          @cropY = newCropFrame.y
          @cropWidth = newCropFrame.w
          @cropHeight = newCropFrame.h
          @naturalWidth = newCropFrame.w
          @naturalHeight = newCropFrame.h

          @resizeToParent()
          @centerOnParent()

          @cropped = false if @cropX == 0 && @cropY == 0 && @cropWidth == @naturalWidth && @cropHeight == @naturalHeight

          @trigger 'crop', @, action.toCropFrame, @cropFrame()
        when 'adjustBrightness'
          @brightness = action.fromBrightness
          @updateBrightnessAndContrastTable()
          @trigger 'adjustBrightness', @, action.toBrightness, @brightness
        when 'adjustContrast'
          @contrast = action.fromContrast
          @updateBrightnessAndContrastTable()
          @trigger 'adjustContrast', @, action.toContrast, @contrast

      @markDirty()

  revertImage: () ->
    @cropped = false

    if @history.length > 0
      previousCropFrame = @cropFrame()
      previousBrightness = @brightness
      previousContrast = @contrast

      @brightness = 0
      @contrast = 0
      @cropX = 0
      @cropY = 0
      @cropWidth = @originalNaturalBounds.w
      @cropHeight = @originalNaturalBounds.h
      @naturalWidth = @originalNaturalBounds.w
      @naturalHeight = @originalNaturalBounds.h

      @resizeToParent()
      @centerOnParent()
      @updateBrightnessAndContrastTable()

      @trigger 'crop', @, previousCropFrame, @cropFrame()
      @trigger 'adjustBrightness', @, previousBrightness, @brightness
      @trigger 'adjustContrast', @, previousContrast, @contrast

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

    imageData = ctx.getImageData 0, 0, @cropWidth, @cropHeight

    # Run our image through the filters
    pixelData = imageData.data
    for filter in @filters()
      filter.call @, pixelData

    ctx.putImageData imageData, 0, 0

    canvas.toDataURL format

  draw: (ctx) ->
    return unless @loaded

    @positionContext ctx, (ctx) ->
      if @cropped
        ctx.drawImage @img, @cropX, @cropY, @cropWidth, @cropHeight, 0, 0, @w, @h
      else
        ctx.drawImage @img, 0, 0, @w, @h

      canvasPoint = @convertToCanvas { x: 0, y: 0 }
      imageData = ctx.getImageData canvasPoint.x, canvasPoint.y, @w, @h

      # Run our image through the filters
      pixelData = imageData.data
      for filter in @filters()
        filter.call @, pixelData

      ctx.putImageData imageData, canvasPoint.x, canvasPoint.y

  filters: ->
    [
      @filterBrightness
    ]

  filterBrightness: (pixelData) ->
    i = 0
    n = pixelData.length
    while i < n
      pixelData[i + 0] = @brightnessAndContrastTable[pixelData[i + 0]]
      pixelData[i + 1] = @brightnessAndContrastTable[pixelData[i + 1]]
      pixelData[i + 2] = @brightnessAndContrastTable[pixelData[i + 2]]

      i += 4

  updateBrightnessAndContrastTable: ->
    @brightnessAndContrastTable = []

    legacy = false

    if legacy
      brightness = Math.min(150, Math.max(-150, @brightness))
    else
      brightMul = 1 + Math.min(150, Math.max(-150, @brightness)) / 150

    contrast = Math.max 0, @contrast + 1

    if contrast != 1
      if legacy
        mul = contrast
        add = (brightness - 128) * contrast + 128
      else
        mul = brightMul * contrast
        add = - contrast * 128 + 128
    else
      if legacy
        mul = 1
        add = brightness
      else
        mul = brightMul
        add = 0

    i = 0
    while i < 256
      v = i * mul + add

      @brightnessAndContrastTable[i] = if v > 255
        255
      else if v < 0
        0
      else
        v

      i++

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
