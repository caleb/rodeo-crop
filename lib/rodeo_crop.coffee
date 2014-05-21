"use strict";

extend = (obj, source) ->
    if source
      for prop of source
        obj[prop] = source[prop]
    obj

class window.RodeoCrop
  constructor: (el, options) ->
    @el = el
    @src = el.src
    @options = extend {
      backgroundColor: '#222222'
      fixedRatio: false
      ratio: 1
    }, options

    @initialize()

  initialize: ->
    # set up the stage
    @container = document.createElement 'div'
    @container.className = 'rodeo-crop'
    @container.style.height = '100%'
    @container.style.width = '100%'

    @stage = new Kinetic.Stage
      container: @container

    @imageLayer = new Kinetic.Layer
    @cropLayer = new Kinetic.Layer

    @stage.add @imageLayer
    @stage.add @cropLayer

    @el.parentNode.replaceChild @container, @el

    @drawImage()
    @drawCropTool()
    @resizeStage()
    @addResizeListeners()

  drawCropTool: ->
    @cropTool = new Kinetic.Group
      draggable: true
      dragBoundFunc: (pos) =>
        {
          x: Math.max(Math.min(pos.x, @image.position().x + Math.floor(@scale * @image.width()) - @cropToolRect.width()), @image.position().x)
          y: Math.max(Math.min(pos.y, @image.position().y + Math.floor(@scale * @image.height()) - @cropToolRect.height()), @image.position().y)
        }

    @cropToolRect = new Kinetic.Rect
      fill: '#980000'
      opacity: 0.5
      x: 0
      y: 0
      width: 100
      height: 100

    @cropToolRect.addEventListener 'mouseover', =>
      document.body.style.cursor = 'pointer'

    @cropToolRect.addEventListener 'mouseout', =>
      document.body.style.cursor = 'default'

    @cropTool.add @cropToolRect
    @cropLayer.add @cropTool

  drawImage: ->
    img = document.createElement 'img'
    img.onload = (a) =>
      @image = new Kinetic.Image
        image: img
        width: img.naturalWidth
        height: img.naturalHeight

      @imageLayer.add @image
      @resizeImage()

    img.src = @src

  addResizeListeners: ->
    @container.style.position = 'relative';

    @resizeTriggers = document.createElement 'div'

    @expandTrigger = document.createElement 'div'
    @expandTriggerChild = document.createElement 'div'
    @expandTrigger.appendChild @expandTriggerChild

    @contractTrigger = document.createElement 'div'
    @contractTriggerChild = document.createElement 'div'
    @contractTrigger.appendChild @contractTriggerChild

    # set some styles
    @resizeTriggers.style.visibility = 'hidden'

    for trigger in [@resizeTriggers, @expandTrigger, @contractTrigger, @contractTriggerChild]
      trigger.style.content = ' '
      trigger.style.display = 'block'
      trigger.style.position = 'absolute'
      trigger.style.top = 0
      trigger.style.left = 0
      trigger.style.height = '100%'
      trigger.style.width = '100%'
      trigger.style.overflow = 'hidden'

    for trigger in [@expandTrigger, @contractTrigger]
      trigger.style.background = '#eee'
      trigger.style.overflow = 'auto'

    @contractTriggerChild.style.width = '200%'
    @contractTriggerChild.style.height = '200%'

    # add the triggers to the trigger container
    @resizeTriggers.appendChild @expandTrigger
    @resizeTriggers.appendChild @contractTrigger

    # add the triggers to our container
    @container.appendChild @resizeTriggers

    requestFrame = ( ->
      raf = window.requestAnimationFrame ||
            window.mozRequestAnimationFrame ||
            window.webkitRequestAnimationFrame ||
            (fn) =>
              window.setTimeout fn, 20

      (fn) ->
        raf fn
    )()

    cancelFrame = ( ->
      cancel = window.cancelAnimationFrame ||
               window.mozCancelAnimationFrame ||
               window.webkitCancelAnimationFrame ||
               window.clearTimeout
      (id) ->
        cancel id
    )()

    resetTriggers = =>
      @contractTrigger.scrollLeft      = @contractTrigger.scrollWidth
      @contractTrigger.scrollTop       = @contractTrigger.scrollHeight
      @expandTriggerChild.style.width  = @expandTrigger.offsetWidth + 1 + 'px'
      @expandTriggerChild.style.height = @expandTrigger.offsetHeight + 1 + 'px'
      @expandTrigger.scrollLeft        = @expandTrigger.scrollWidth
      @expandTrigger.scrollTop         = @expandTrigger.scrollHeight

    checkTriggers = =>
      @container.offsetWidth != @container.__resizeLast__.width ||
      @container.offsetHeight != @container.__resizeLast__.height

    scrollListener = (e) =>
      resetTriggers()
      cancelFrame @__resizeRAF__ if @__resizeRAF__
      @__resizeRAF__ = requestFrame =>
        if checkTriggers()
          @container.__resizeLast__.width = @container.offsetWidth
          @container.__resizeLast__.height = @container.offsetHeight
          @resizeStage()

    # clear our trigger state now
    @container.__resizeLast__ = {}
    @container.__resizeListeners__ = []

    resetTriggers()
    @container.addEventListener 'scroll', scrollListener, true

  reSizeAndPositionCropTool: ->
    pos = @cropTool.dragBoundFunc()(@cropTool.position())
    @cropTool.position pos

    @cropTool.draw()

  resizeImage: ->
    sw = @stage.width()
    sh = @stage.height()
    w = @image.width()
    h = @image.height()

    scaleX = 1
    scaleY = 1
    scaleMin = 1
    scaleMax = 1

    # if the image is too big… shrink it down
    scaleX = sw / w if w > sw
    scaleY = sh / h if h > sh
    @scale = Math.min scaleX, scaleY

    x = (sw / 2) - (w * @scale / 2)
    y = (sh / 2) - (h * @scale / 2)

    @image.scale {
      x: 1 || @scale
      y: 1 || @scale
    }
    @image.width Math.floor(@scale * w)
    @image.height Math.floor(@scale * h)
    @image.position
      x: Math.floor(x)
      y: Math.floor(y)

    @image.draw()

    @reSizeAndPositionCropTool() if @cropTool

  resizeStage: ->
    containerHeight = window.getComputedStyle(@container).getPropertyValue 'height'
    containerWidth = window.getComputedStyle(@container).getPropertyValue 'width'

    @stage.width parseInt(containerWidth, 10)
    @stage.height parseInt(containerHeight, 10)

    @stage.clear()

    @resizeImage() if @image
