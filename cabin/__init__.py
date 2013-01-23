import os.path

from flask import Flask, request
from flask.ext.assets import Bundle, Environment
from flask.ext.uploads import UploadSet, configure_uploads
from redis import StrictRedis as Redis

from cabin import util

PROD_INSTANCE_PATH = '/srv/http/cabin/instance'

# TODO: make this configurable.
redis = Redis(charset='utf8', decode_responses=True, db=0)

images = UploadSet('images')


def create_app():
    instance_path = None
    if os.path.exists(PROD_INSTANCE_PATH):
        instance_path = PROD_INSTANCE_PATH
    app = Flask(
        __name__, instance_relative_config=True, instance_path=instance_path)
    app.config.update(
        ASSETS_URL='/static',
        COFFEE_NO_BARE=True,
        UPLOAD_QUEUE='uploaded-files',
        UPLOADS_DEFAULT_DEST=app.instance_path,
        UPLOADS_DEFAULT_URL='/u/',
    )
    app.config.from_pyfile('settings.cfg', silent=True)

    register_assets(app)
    configure_uploads(app, [images])

    from cabin.auth import get_current_user
    app.context_processor(lambda: {
        'debug': app.debug,
        'blank_img': 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        'image_url': images.url,
        'request_is_pjax': 'X-PJAX' in request.headers,
        'current_user': get_current_user(),
    })
    app.jinja_env.filters['external_url'] = util.external_url
    app.jinja_env.filters['hostname'] = util.hostname
    app.jinja_env.filters['urlquote'] = util.urlquote

    from cabin.main import main
    app.register_blueprint(main)

    from cabin.auth import auth
    app.register_blueprint(auth, url_prefix='/auth')

    from cabin.admin import admin
    app.register_blueprint(admin, url_prefix='/admin')

    return app


def register_assets(app):
    assets = Environment(app)
    assets.manifest = 'file'
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
            'fonts/ywft-ultramagnetic-light.css',
            'fonts/proxima-nova.css',
            filters='cssrewrite', output='gen/fonts.css'),
        Bundle(
            '../style/screen.styl',
            depends='../style/*.styl',
            filters='stylus', output='gen/stylus.css'),
        filters='cssmin', output='gen/screen-%(version)s.css')

    assets.register(
        'icons.css',
        Bundle(
            '../style/icons.styl',
            filters='stylus', output='gen/icons.css'),
        filters='cssmin', output='gen/icons-%(version)s.css')

    assets.register(
        'client-logos.css',
        Bundle(
            '../style/client-logos.styl',
            filters='stylus', output='gen/client-logos.css'),
        filters='cssmin', output='gen/client-logos-%(version)s.css')

    # Modernizr is separate, as it bootstraps the other scripts. Run it through
    # webassets with no filters to add the hash to the filename.
    assets.register(
        'modernizr.js',
        'vendor/modernizr.js',
        output='gen/modernizr-%(version)s.js')

    assets.register(
        'vendor.js',
        'vendor/jquery-1.9.0zj.js',
        'vendor/underscore-1.4.3.js',
        'vendor/backbone-0.9.9.js',
        'vendor/keymaster-1.0.3pre.js',
        'vendor/jquery.masonry-2.1.07.js',
        'vendor/jquery.tapclick.js',
        'vendor/d3.v3.js',
        'vendor/jquery.sortable.js',  # XXX extract to admin.js?
        filters='uglifyjs', output='gen/vendor-%(version)s.js')

    assets.register(
        'site.js',
    #    Bundle(
    #        '../templates/js/*',
    #        depends='dummy',  # TODO: remove this once webassets fix is in
    #        filters='handlebars', output='gen/templates.js'),
        Bundle(
            '../script/charts.coffee',
            '../script/views.coffee',
            filters='coffeescript', output='gen/coffee.js'),
        filters='uglifyjs', output='gen/site-%(version)s.js')
