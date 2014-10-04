# Fake underscore.js, funderscore if you will
_ = {}

_.clone = (obj) ->
  _.extend {}, obj

_.extend = (obj, source) ->
  if source
    for prop of source
      obj[prop] = source[prop]
  obj

for type in ['Arguments', 'Function', 'String', 'Number', 'Date', 'RegExp']
  do (type) ->
    _["is#{type}"] = (obj) -> Object.prototype.toString.call(obj) == "[object #{type}]"

# A (possibly faster) way to get the current timestamp as an integer.
_.now = Date.now || () ->
  new Date().getTime()

# Returns a function, that, as long as it continues to be invoked, will not
# be triggered. The function will be called after it stops being called for
# N milliseconds. If `immediate` is passed, trigger the function on the
# leading edge, instead of the trailing.
_.debounce = (func, wait, immediate) ->
  args = null
  context = null
  timestamp = null
  timeout = null
  result = null

  later = () ->
    last = _.now() - timestamp

    if last < wait && last > 0
      timeout = setTimeout later, wait - last
    else
      timeout = null
      if !immediate
        result = func.apply context, args
        if !timeout then context = args = null

  () ->
    context = @
    args = arguments
    timestamp = _.now()
    callNow = immediate && !timeout
    if !timeout then timeout = setTimeout later, wait
    if callNow
      result = func.apply context, args
      context = args = null

    result

`export default _`
