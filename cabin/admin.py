import time
import urllib2

from flask import (
    abort, Blueprint, jsonify, redirect, render_template, request, url_for)

from cabin import images, redis
from cabin.forms import ProjectForm
from cabin.models import Project

admin = Blueprint('admin', __name__)


@admin.route('/work/<slug>', methods=['GET', 'POST'])
def project(slug):
    project = Project.get_by_slug(slug, private=True)
    if project is None:
        abort(404)
    if urllib2.unquote(slug) != project.slug:
        canonical_url = url_for('admin.project', slug=project.slug)
        return redirect(canonical_url, code=301)
    form = ProjectForm(obj=project)
    if form.validate_on_submit():
        form.populate_obj(project)
        project.save()
        return redirect(url_for('admin.project', slug=project.slug))
    return render_template('admin/project.html', form=form, project=project)


@admin.route('/upload', methods=['POST'])
def upload():
    filenames = []
    if 'file' in request.files:
        for f in request.files.getlist('file'):
            filename = images.save(f)
            redis.zadd('uploaded-files', int(time.time()), filename)
            filenames.append(filename)
    return jsonify({'files': filenames})
