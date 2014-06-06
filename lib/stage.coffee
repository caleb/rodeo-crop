`import _ from "funderscore"`
`import drawing from "drawing"`
`import { Event } from "events"`

class Stage extends drawing.Drawable
  constructor: (options) ->
    super options

    @canvas = options.canvas
    @lastMouseDownTarget = null
    @lastMouseMoveTarget = null
    @dragTarget = null
    @clickTarget = null
    @attachListeners()

  bubbleMouseEvent: (target, event, originalEvent, canvasPoint) ->
    eventObject = new Event
      target: target
      originalEvent: originalEvent
      canvasPoint: canvasPoint

    target.bubble event, eventObject

  attachListeners: () ->
    window.addEventListener 'mouseup', (e) =>
      return unless e.which == 1
      e.preventDefault()

      pos = @windowToCanvas e

      target = @findChildAtPoint(pos) || @
      @bubbleMouseEvent target, 'mouseup', e, pos

      @bubbleMouseEvent @clickTarget, 'click', e, pos if @clickTarget == target
      @bubbleMouseEvent @dragTarget, 'dragend', e, pos if @dragTarget

      @lastMouseDownTarget = null
      @lastMouseMoveTarget = null
      @dragTarget = null

    window.addEventListener 'mousedown', (e) =>
      return unless e.which == 1
      e.preventDefault()

      pos = @windowToCanvas e

      target = @findChildAtPoint(pos) || @
      @bubbleMouseEvent target, 'mousedown', e, pos

      @lastMouseDownTarget = target
      @clickTarget = target
      @movedSinceMouseDown = false

    window.addEventListener 'mousemove', (e) =>
      e.preventDefault()
      pos = @windowToCanvas e

      target = @findChildAtPoint(pos) || @
      @bubbleMouseEvent target, 'mousemove', e, pos

      if @lastMouseDownTarget
        if ! @dragTarget
          @bubbleMouseEvent @lastMouseDownTarget, 'dragstart', e, pos
          @dragTarget = @lastMouseDownTarget

        @bubbleMouseEvent @dragTarget, 'dragmove', e, pos

      if target != @lastMouseMoveTarget
        @bubbleMouseEvent @lastMouseMoveTarget, 'mouseout', e, pos if @lastMouseMoveTarget
        @bubbleMouseEvent target, 'mouseover', e, pos

      @lastMouseMoveTarget = target

  windowToCanvas: (e) ->
    rect = @canvas.getBoundingClientRect()

    x = e.clientX - rect.left - parseInt(window.getComputedStyle(@canvas).getPropertyValue('padding-left'), 0)
    y = e.clientY - rect.top - parseInt(window.getComputedStyle(@canvas).getPropertyValue('padding-top'), 0)

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

`export default Stage`
