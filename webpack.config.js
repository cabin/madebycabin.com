const CopyWebpackPlugin = require('copy-webpack-plugin');
const HtmlWebpackInlineSourcePlugin = require('html-webpack-inline-source-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: './index.js',
  output: {
    filename: 'main.[hash].js',
  },

  module: {
    rules: [
      {
        test: /\.(ttf|woff)$/,
        use: {
          loader: 'url-loader',
          options: {limit: 32768},
        },
      }, {
        test: /\.styl$/,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader',
          'postcss-loader',
          'stylus-loader',
        ],
      },
    ],
  },

  plugins: [
    new CopyWebpackPlugin(['assets/*.jpg', 'assets/*.mp4']),
    new HtmlWebpackPlugin({
      favicon: __dirname + '/assets/favicon.ico',
      inlineSource: '\.(js|css)$',
      template: './index.html',
    }),
    new HtmlWebpackInlineSourcePlugin(),
    new MiniCssExtractPlugin({
      filename: 'main.[hash].css',
    }),
  ],

  devServer: {
    allowedHosts: ['webpack.test'],
    host: '0.0.0.0',
  }
};
