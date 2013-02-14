import time
import urllib2

import flask
from flask import redirect, render_template, request, url_for

from cabin import images, redis
from cabin.auth import admin_required
from cabin.forms import ProjectForm
from cabin.models import Project

admin = flask.Blueprint('admin', __name__)


@admin.route('/work/<slug>', methods=['GET', 'POST', 'PUT'])
@admin_required
def project(slug):
    project = Project.get_by_slug(slug, allow_private=True)
    if project is None:
        flask.abort(404)
    if urllib2.unquote(slug) != project.slug:
        canonical_url = url_for('admin.project', slug=project.slug)
        return redirect(canonical_url, code=301)
    # PUT implies an update request from the Manage Work page.
    if request.method == 'PUT':
        update_project(project, request.form)
        return flask.jsonify({'success': True})
    form = ProjectForm(obj=project)
    if form.validate_on_submit():
        form.populate_obj(project)
        project.save()
        return redirect(url_for('main.project', slug=project.slug))
    return render_template('admin/project.html', form=form)


# Since we want to allow updating only those attributes that are passed without
# affecting any other attributes (and WTForms BooleanField expects HTML
# checkbox-like behavior), just do it in a hack here.
def update_project(project, data):
    conv_bool = lambda v: v in [1, '1', 'true', 'True', True]
    operations = {
        'is_public': lambda v: setattr(project, 'is_public', conv_bool(v)),
        'is_featured': lambda v: setattr(project, 'is_featured', conv_bool(v)),
    }
    for attr, fn in operations.items():
        if attr in data:
            fn(data[attr])
    project.save()


@admin.route('/work', methods=['GET', 'POST'])
@admin_required
def work():
    if request.method == 'POST':
        order = request.json['order']
        key = 'projects:public'
        with redis.pipeline() as pipe:
            pipe.delete(key)
            pipe.rpush(key, *order)
            pipe.execute()
        return flask.jsonify({'success': True})
    return render_template(
        'admin/work.html',
        projects=Project.get_summaries(private=False),
        private_projects=Project.get_summaries(private=True),
    )


@admin.route('/create', methods=['GET', 'POST'])
@admin_required
def create():
    form = ProjectForm()
    if form.validate_on_submit():
        project = Project()
        form.populate_obj(project)
        project.save()
        return redirect(url_for('main.project', slug=project.slug))
    return render_template('admin/project.html', form=form, is_new=True)


@admin.route('/upload', methods=['POST'])
@admin_required
def upload():
    filenames = []
    upload_queue = flask.current_app.config['UPLOAD_QUEUE']
    if 'file' in request.files:
        for f in request.files.getlist('file'):
            filename = images.save(f)
            redis.zadd(upload_queue, int(time.time()), filename)
            filenames.append(filename)
    return flask.jsonify({'files': filenames})
