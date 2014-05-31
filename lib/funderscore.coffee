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

`export default _`
