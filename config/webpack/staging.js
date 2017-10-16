const environment = require('./environment')
const webpack = require('webpack')
const UglifyJsPlugin = require('uglify-js')

environment.plugins.set(
  'UglifyJs',
  new webpack.optimize.UglifyJsPlugin({
    compress: {
      warnings: false
    }
  })
)

module.exports = environment.toWebpackConfig()
