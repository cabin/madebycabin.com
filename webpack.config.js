const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: './index.js',

  module: {
    rules: [
      {
        test: /\.(ttf|woff)$/,
        loader: 'url-loader',
      }, {
        test: /\.styl$/,
        use: [
          MiniCssExtractPlugin.loader,
          'css-loader',
          'stylus-loader',
        ],
      },
    ],
  },

  plugins: [
    new HtmlWebpackPlugin({
      favicon: __dirname + '/assets/favicon.ico',
      template: './index.html',
    }),
    new MiniCssExtractPlugin(),
  ],
};
