var filterCoffeeScript = require('broccoli-coffee')
var uglifyJavaScript = require('broccoli-uglify-js')
var compileES6 = require('broccoli-es6-concatenator')
var pickFiles = require('broccoli-static-compiler')
var moveFile = require('broccoli-file-mover')
var mergeTrees = require('broccoli-merge-trees')

function preprocess(tree) {
  tree = filterCoffeeScript(tree, {
    bare: true
  })

  return tree
}

var lib = 'lib'
lib = pickFiles(lib, {
  srcDir: '/',
  destDir: 'rodeo-crop'
})
lib = preprocess(lib)

var vendor = 'vendor'
var publicDir = 'public'
var libAndDependencies = new mergeTrees([lib, vendor], { overwrite: true })

var libJs = compileES6(libAndDependencies, {
  loaderFile: 'loader.js',
  inputFiles: [
    'rodeo-crop/**/*.js'
  ],
  legacyFilesToAppend: [
    'rodeo-crop/bootstrap.js'
  ],
  wrapInEval: false,
  outputFile: '/javascripts/rodeo-crop.js'
})

var uglifiedLibJs = moveFile(libJs, {
  srcFile: '/javascripts/rodeo-crop.js',
  destFile: '/javascripts/rodeo-crop.min.js'
})
uglifiedLibJs = uglifyJavaScript(uglifiedLibJs)

module.exports = new mergeTrees([libJs, uglifiedLibJs, publicDir], { overwrite: true })
