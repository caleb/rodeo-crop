class Events
  on: (event, callback, context) ->
    @events ||= {}
    @events[event] ||= []
    @events[event].push [callback, context]

  trigger: (event) ->
    tail = Array.prototype.slice.call arguments, 1
    callbacks = @events[event] || []

    for callbackStruct in callbacks
      callback = callbackStruct[0]
      context = callbackStruct[1] || @
      callback.apply context, tail

`export default Events`
