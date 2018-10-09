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
        loader: 'url-loader',
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
    new HtmlWebpackPlugin({
      favicon: __dirname + '/assets/favicon.ico',
      template: './index.html',
    }),
    new MiniCssExtractPlugin({
      filename: 'main.[hash].css',
    }),
  ],

  devServer: {
    allowedHosts: ['webpack.test'],
    host: '0.0.0.0',
  }
};
