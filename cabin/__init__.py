from flask import Flask
from flask.ext.assets import Bundle, Environment


def create_app():
    app = Flask(__name__, instance_relative_config=True)
    app.config.update(
        ASSETS_URL='/static',
        COFFEE_NO_BARE=True,
    )
    app.config.from_pyfile('settings.cfg', silent=True)

    register_assets(app)

    from cabin.main import main
    app.register_blueprint(main)

    return app


def register_assets(app):
    assets = Environment(app)
    assets.config['stylus_plugins'] = ['nib']
    assets.config['stylus_extra_args'] = [
        '--inline',
        '--include', '%s/style' % app.root_path,
        '--include', '%s/static' % app.root_path,
    ]

    assets.register(
        'screen.css',
        'vendor/normalize-2.0.1.css',
        Bundle(
            '../style/screen.styl',
            depends='../style/*.styl',
            filters='stylus', output='gen/stylus.css'),
        filters='cssmin', output='gen/screen.css')

    assets.register(
        'vendor.js',
        'vendor/jquery-1.9.0b1.js',
        'vendor/jquery.backstretch-2.0.3.js',
        'vendor/underscore-1.4.3.js',
        filters='uglifyjs', output='gen/vendor.js')

    #assets.register(
    #    'site.js',
    #    Bundle(
    #        '../templates/js/*',
    #        depends='dummy',  # TODO: remove this once webassets fix is in
    #        filters='handlebars', output='gen/templates.js'),
    #    Bundle(
    #        '../script/support.coffee',
    #        '../script/bb.coffee',
    #        #'../script/drop.coffee',
    #        filters='coffeescript', output='gen/coffee.js'),
    #    filters='uglifyjs', output='gen/site.js')
