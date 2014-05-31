`import _ from "funderscore"`
`import drawing from "drawing"`
`import Events from "events"`
`import CropBox from "crop-box"`
`import Stage from "stage"`

RodeoCrop = {}

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
      handleSize: 10
      width: 100
      height: 100
      imageSource: null
      onCropFrameChanged: null
    , options

    @ctx = null
    @stage = null
    @imageSource = @options.imageSource

    @initializeCanvas()
    @createStage()
    @createImage()
    @createCropBox()
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
    @paddedContainer = new drawing.PaddedContainer
      padding: (@options.handleSize / 2) + 1

    @image = new drawing.CanvasImage
      canvas: @canvas
      source: @imageSource

    @image.on 'load', () =>
      @image.resizeToParent()
      @image.centerOnParent()

    @stage.on 'resize', () =>
      @image.resizeToParent()
      @image.centerOnParent()

    @paddedContainer.addChild @image
    @stage.addChild @paddedContainer

  createCropBox: () ->
    @cropBox = new CropBox
      enabled: @cropEnabled
      canvas: @canvas
      image: @image
      cropX: @options.cropX
      cropY: @options.cropY
      cropWidth: @options.cropWidth
      cropHeight: @options.cropHeight
      handleSize: @options.handleSize

    @cropBox.on 'change', (cropFrame) =>
      @trigger 'change', cropFrame

    @image.on 'resize', () =>
      @cropBox.updateFrameFromCropFrame()

    @image.addChild @cropBox

  setImageSource: (source) ->
    @image.setSource source

  setCropFrame: (frame) ->
    @cropBox.setCropFrameAndUpdateFrame frame
    @cropBox.cropFrame()

  enableCrop: (enabled) ->
    @cropBox.enabled = enabled
    @cropBox.markDirty()

  unCropImage: () ->
    @image.undoCrop()

  cropImage: () ->
    @image.crop @cropBox.cropFrame()

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

    if canvasSizeChanged || @stage.dirty
      @stage.clear @ctx
      @stage.trigger 'resize' if canvasSizeChanged
      @stage.render @ctx

    window.requestAnimationFrame => @runLoop()

RodeoCrop.Cropper = Cropper

`export default RodeoCrop`
