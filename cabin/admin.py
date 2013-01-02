import urllib2

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
