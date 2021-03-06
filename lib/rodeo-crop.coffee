`import _ from "funderscore"`
`import drawing from "drawing"`
`import Events from "events"`
`import CanvasImage from "canvas-image"`
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
      crossOrigin: null
      cropEnabled: true
      cropX: null
      cropY: null
      cropWidth: null
      cropHeight: null
      marchingAnts: true
      handleSize: 10
      width: 100
      height: 100
      imageSource: null
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
    @canvas.style.display = 'block'

    @el.appendChild @canvas

    @ctx = @canvas.getContext '2d'

  createStage: () ->
    @stage = new Stage
      canvas: @canvas

  createImage: () ->
    @paddedContainer = new drawing.PaddedContainer
      padding: (@options.handleSize / 2) + 1

    @image = new CanvasImage
      crossOrigin: @options.crossOrigin
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
      enabled: @options.cropEnabled
      canvas: @canvas
      image: @image
      cropX: @options.cropX
      cropY: @options.cropY
      cropWidth: @options.cropWidth
      cropHeight: @options.cropHeight
      handleSize: @options.handleSize
      marchingAnts: @options.marchingAnts

    @cropBox.on 'disabled', (cropBox) =>
      @trigger 'disabled', cropBox

    @cropBox.on 'enabled', (cropBox) =>
      @trigger 'enabled', cropBox

    @cropBox.on 'change', (cropFrame) =>
      @trigger 'change', cropFrame

    @image.on 'resize', () =>
      @cropBox.updateFrameFromCropFrame()

    @image.on 'adjustBrightness', (image, previousContrast, newContrast) =>
      @trigger 'adjustBrightness', previousContrast, newContrast

    @image.on 'adjustContrast', (image, previousContrast, newContrast) =>
      @trigger 'adjustContrast', previousContrast, newContrast

    @image.addChild @cropBox

  isCropped: () ->
    @image.cropped

  isChanged: () ->
    @image.isChanged()

  getImageSource: ->
    @image.getSource()

  setImageSource: (source) ->
    @image.setSource source

  setCropFrame: (frame) ->
    @cropBox.setCropFrameAndUpdateFrame frame
    @cropBox.cropFrame()

  enableCrop: (enabled) ->
    @cropBox.enable enabled

  revertImage: () ->
    @image.revertImage()

  undo: () ->
    @image.undo()

  cropImage: () ->
    @image.crop @cropBox.cropFrame() if @cropBox.enabled

  adjustBrightness: (amount) ->
    @image.adjustBrightness amount

  adjustContrast: (amount) ->
    @image.adjustContrast amount

  commitChanges: () ->
    @image.commitChanges()

  toDataURL: (format = 'image/png') ->
    @image.toDataURL format

  toBlob: (callback, format = 'image/png') ->
    @image.toBlob callback, format

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
RodeoCrop._ = _

`export default RodeoCrop`
