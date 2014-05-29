var compileCoffeeScript = require('broccoli-coffee')
var uglifyJavaScript    = require('broccoli-uglify-js')
var compileES6          = require('broccoli-es6-concatenator')
var pickFiles           = require('broccoli-static-compiler')
var moveFile            = require('broccoli-file-mover')
var mergeTrees          = require('broccoli-merge-trees')

var lib = 'lib'
var vendor = 'vendor'
var publicDir = 'public'

lib = compileCoffeeScript(lib, {
  bare: true
})

vendor = pickFiles(vendor, {
  srcDir: '/',
  destDir: '/vendor'
})

var libAndVendor = new mergeTrees([lib, vendor], { overwrite: true })

var libJs = compileES6(libAndVendor, {
  loaderFile: '/vendor/loader.js',
  inputFiles: [
    '**/*.js'
  ],
  ignoredModules: [
    'bootstrap'
  ],
  legacyFilesToAppend: [
    'bootstrap.js'
  ],
  wrapInEval: false,
  outputFile: '/javascripts/rodeo-crop.js'
})

var uglifiedLibJs = moveFile(libJs, {
  srcFile: '/javascripts/rodeo-crop.js',
  destFile: '/javascripts/rodeo-crop.min.js'
})
uglifiedLibJs = uglifyJavaScript(uglifiedLibJs, {
  mangle: true,
  compress: true
})

module.exports = new mergeTrees([libJs, uglifiedLibJs, publicDir], { overwrite: true })
