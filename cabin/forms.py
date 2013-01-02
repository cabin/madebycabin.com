from itertools import groupby

from flask.ext.wtf import Form
from wtforms import Form as SimpleForm
from wtforms.fields import *
from wtforms.validators import *

from cabin import thumbnails
from cabin.models import SERVICES, SERVICE_TYPES
from cabin.util.fields import SelectMultipleGroupedField


def grouped_services():
    grouped = groupby(SERVICES, key=lambda s: s.type)
    types = dict(SERVICE_TYPES)
    return [(types[k], [(s.id, s.name) for s in g]) for k, g in grouped]


class CohortForm(SimpleForm):
    full_name = StringField('Name')  # XXX should be required
    role = StringField('Role')  # XXX should be required
    twitter_user = StringField('@username')


class ProjectForm(Form):
    slug = StringField('URL slug', [InputRequired(), Length(max=64)])
    title = TextAreaField('Title', [InputRequired()])
    type = StringField('Project type', [InputRequired()])
    is_public = BooleanField('Public', default=False)
    is_featured = BooleanField('Featured', default=False)
    brief = TextAreaField('Brief', [InputRequired()],
                          description='Keep it that way.')
    thumbnail_file = FileField()
    external_url = StringField('URL in the wild', [Optional(), URL()])

    services = SelectMultipleGroupedField(
        choices=grouped_services(), coerce=int)
    cohorts = FieldList(FormField(CohortForm), min_entries=1)
    images = FieldList(StringField())
    image_files = FieldList(FileField('Image'), min_entries=1)

    def _populate_cohorts(self, obj):
        cohorts = self.cohorts.data
        del self.cohorts
        # XXX handle cohorts

    def _populate_thumbnail(self, obj):
        if self.thumbnail_file.data:
            obj.thumbnail_file = thumbnails.save(self.thumbnail_file.data)
        del self.thumbnail_file

    def populate_obj(self, obj):
        self._populate_cohorts(obj)
        self._populate_thumbnail(obj)
        return super(ProjectForm, self).populate_obj(obj)
