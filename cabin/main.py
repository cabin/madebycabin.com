import collections
import urllib2
import urlparse

import flask
from flask import abort, Blueprint, redirect, render_template, request, url_for

from cabin import util
from cabin.auth import get_current_user
from cabin.models import grouped_services, Project, Tumblr, Instagram, Flickr

main = Blueprint('main', __name__)


@main.route('/')
def index():
    return work(splash=True)


@main.route('/work')
def work(splash=False):
    projects = Project.get_summaries()
    return render_template('work.html', splash=splash, projects=projects)


@main.route('/work/<slug>')
def project(slug):
    is_admin = get_current_user().is_admin
    project = Project.get_by_slug(slug, allow_private=is_admin)
    if project is None:
        abort(404)
    if urllib2.unquote(slug) != project.slug:
        canonical_url = url_for('main.project', slug=project.slug)
        return redirect(canonical_url, code=301)
    return render_template('project.html', project=project)


@main.route('/about')
def about():
    Client = collections.namedtuple('Client', 'name, url')
    clients = (
        Client('GOOD', 'http://www.good.is/'),
        Client('Etsy', 'http://www.etsy.com/'),
        Client('Starbucks', 'http://www.starbucks.com/'),
        Client('Fitbit', 'http://www.fitbit.com/'),
        Client('Ancestry', 'http://www.ancestry.com/'),
        Client('Opower', 'http://opower.com/'),
        Client('Blurb', 'http://www.blurb.com/'),
        Client('Pressed Juicery', 'http://www.pressedjuicery.com/'),
    )
    return render_template(
        'about.html', clients=clients, grouped_services=grouped_services())


@main.route('/lab')
def lab():
    return render_template('lab.html')


@main.route('/life')
def blog():
    return render_template(
        'blog.html',
        tumblr=Tumblr.get_latest(3),
        instagram=Instagram.get_latest(24),  # 6 rows x 4 columns
        flickr=Flickr.get_latest(18),  # 6 rows x 3 columns
    )


@main.route('/ie')
def oldie():
    # Pinterest's /offsite/ redirector is broken; see issue #93. Until that's
    # resolved, we have to catch anyone incorrectly directed to the sad browser
    # page and redirect them to the correct URL.
    r = urlparse.urlparse(request.referrer or '')
    if r.netloc.endswith('pinterest.com') and r.path == '/offsite/':
        intended_url = urlparse.parse_qs(r.query).get('url')
        if not is_oldie() and len(intended_url) > 0:
            return redirect(intended_url[0], code=301)
    # End Pinterest hack. TODO: remove the above.
    if 'be_brave' in request.args:
        flask.session['brave_soul'] = True
        return redirect(url_for('main.index'))
    return render_template('ie.html')


def is_oldie():
    browser, version = util.browser_version()
    return browser == 'msie' and version < 10


@main.before_app_request
def redirect_oldie():
    oldie_path = url_for('main.oldie')
    brave = flask.session.get('brave_soul', False)
    on_ie_page = request.path == oldie_path
    if is_oldie() and not (on_ie_page or brave):
        return redirect(oldie_path)


@main.app_errorhandler(404)
def error_404(error):
    return render_template('404.html'), 404


@main.app_errorhandler(500)
def error_500(error):
    return render_template('500.html'), 500
