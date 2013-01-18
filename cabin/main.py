import collections
import urllib2

from flask import abort, Blueprint, redirect, render_template, request, url_for

from cabin.auth import get_current_user
from cabin.models import grouped_services, Project

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


@main.app_errorhandler(404)
def error_404(self):
    return render_template('404.html')


@main.app_errorhandler(500)
def error_500(self):
    return render_template('500.html')
