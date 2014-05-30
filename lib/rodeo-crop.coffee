`import _ from "funderscore"`
`import drawing from "drawing"`
`import Events from "events"`
`import CropBox from "crop-box"`

RodeoCrop = {}

class Stage extends drawing.Drawable
  initialize: (options) ->
    @canvas = options.canvas

  windowToCanvas: (e) ->
    rect = @canvas.getBoundingClientRect()
    x = e.clientX - rect.left
    y = e.clientY - rect.top

    {
      x: x
      y: y
    }
  frame: ->
    {
      x: 0
      y: 0
      w: @canvas.width
      h: @canvas.height
    }

  bounds: ->
    @frame()

  draw: (ctx) ->
    @drawChildren ctx

  clear: (ctx) ->
    ctx.clearRect 0, 0, @canvas.width, @canvas.height

class Cropper extends Events
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

    @image.on 'load', () =>
      @valid = false
      @image.resizeToParent()
      @image.centerOnParent()

    @stage.on 'resize', () =>
      @image.resizeToParent()
      @image.centerOnParent()

    @stage.addChild @image

  createCropBox: () ->
    @cropBox = new CropBox
      enabled: @cropEnabled
      canvas: @canvas
      image: @image
      cropX: @options.cropX
      cropY: @options.cropY
      cropWidth: @options.cropWidth
      cropHeight: @options.cropHeight

    @cropBox.on 'change', (cropFrame) =>
      @trigger 'change', cropFrame

    @image.on 'resize', () =>
      @cropBox.updateFrameFromCropFrame()

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

      return unless @cropBox.enabled

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
        return unless @cropBox.enabled

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

  setImageSource: (source) ->
    @image.setSource source
    @valid = false

  setCropFrame: (frame) ->
    @cropBox.setCropFrameAndUpdateFrame frame
    @valid = false

    @cropBox.cropFrame()

  enableCrop: (enabled) ->
    @cropBox.enabled = enabled
    @valid = false

  unCropImage: () ->
    @image.undoCrop()
    @valid = false

  cropImage: () ->
    @image.crop @cropBox.cropFrame()
    @valid = false

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
      @stage.trigger 'resize' if canvasSizeChanged
      @stage.draw @ctx

    @valid = true
    window.requestAnimationFrame => @runLoop()

RodeoCrop.Cropper = Cropper

`export default RodeoCrop`
