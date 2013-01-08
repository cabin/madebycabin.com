import time
import urllib2

import flask
from flask import redirect, render_template, request, url_for

from cabin import images, redis
from cabin.forms import ProjectForm
from cabin.models import Project

admin = flask.Blueprint('admin', __name__)


@admin.route('/work/<slug>', methods=['GET', 'POST'])
def project(slug):
    project = Project.get_by_slug(slug, allow_private=True)
    if project is None:
        flask.abort(404)
    if urllib2.unquote(slug) != project.slug:
        canonical_url = url_for('admin.project', slug=project.slug)
        return redirect(canonical_url, code=301)
    form = ProjectForm(obj=project)
    if form.validate_on_submit():
        form.populate_obj(project)
        project.save()
        return redirect(url_for('main.project', slug=project.slug))
    return render_template('admin/project.html', form=form)


@admin.route('/create', methods=['GET', 'POST'])
def create():
    form = ProjectForm()
    if form.validate_on_submit():
        project = Project()
        form.populate_obj(project)
        project.save()
        return redirect(url_for('main.project', slug=project.slug))
    return render_template('admin/project.html', form=form, is_new=True)


@admin.route('/upload', methods=['POST'])
def upload():
    filenames = []
    upload_queue = flask.current_app.config['UPLOAD_QUEUE']
    if 'file' in request.files:
        for f in request.files.getlist('file'):
            filename = images.save(f)
            redis.zadd(upload_queue, int(time.time()), filename)
            filenames.append(filename)
    return flask.jsonify({'files': filenames})
