var filterCoffeeScript = require('broccoli-coffee')
var uglifyJavaScript = require('broccoli-uglify-js')
var compileES6 = require('broccoli-es6-concatenator')
var pickFiles = require('broccoli-static-compiler')
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
  outputFile: '/build/rodeo_crop.js'
})

module.exports = new mergeTrees([libJs, publicDir], { overwrite: true })
