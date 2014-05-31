`import _ from "funderscore"`

class Events
  on: (event, callback, context) ->
    @events ||= {}
    @events[event] ||= []
    @events[event].push [callback, context] if _.isFunction callback

  trigger: (event) ->
    tail = Array.prototype.slice.call arguments, 1
    callbacks = if @events && @events[event] then @events[event] else []

    for callbackStruct in callbacks
      callback = callbackStruct[0]
      context = callbackStruct[1] || @
      callback.apply context, tail

class Event
  constructor: (options) ->
    for k, v of options
      @[k] = v

`export default Events`
`export { Event }`
