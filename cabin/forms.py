from itertools import groupby

from flask.ext.wtf import Form, ValidationError
from wtforms import Form as SimpleForm
from wtforms.fields import *
from wtforms.validators import *

from cabin import images, redis
from cabin.models import SERVICES, SERVICE_TYPES
from cabin.util.fields import SelectMultipleGroupedField


def grouped_services():
    grouped = groupby(SERVICES, key=lambda s: s.type)
    types = dict(SERVICE_TYPES)
    return [(types[k], [(s.id, s.name) for s in g]) for k, g in grouped]


class CohortForm(SimpleForm):
    name = StringField('Name')  # XXX should be required
    role = StringField('Role')  # XXX should be required
    twitter_user = StringField('@username')

    def validate_twitter_user(self, field):
        if field.data and not field.data.isalnum():
            raise ValidationError('Just the username, not the whole URL.')

    def validate_name(self, field):
        # Since we can't mark name and role as required on the fields
        # themselves while still allowing submission with an empty form,
        # instead ensure that they're both set if either one is set.
        if bool(field.data) != bool(self.role.data):
            raise ValidationError('Name and role are required.')


class ProjectForm(Form):
    slug = StringField('URL slug', [InputRequired(), Length(max=64)],
                       filters=[lambda s: s and s.strip()])
    title = TextAreaField('Title', [InputRequired()])
    type = StringField('Project type', [InputRequired()])
    is_public = BooleanField('Public', default=False)
    is_featured = BooleanField('Featured', default=False)
    brief = TextAreaField('Brief', [InputRequired()],
                          description='Keep it that way.')
    thumbnail_file = HiddenField()
    external_url = StringField('URL in the wild', [Optional(), URL()])

    services = SelectMultipleGroupedField(
        choices=grouped_services(), coerce=int)
    cohorts = FieldList(FormField(CohortForm), min_entries=1)
    images = FieldList(StringField())
    image_files = FieldList(FileField('Image'), min_entries=1)

    def validate_slug(self, field):
        if not field.data.replace('-', '').isalnum():
            raise ValidationError(
                'Slug must contain only "-" and alphanumerics.')

    def _populate_cohorts(self, obj):
        obj.cohorts = [c for c in self.cohorts.data
                       if c.get('name') and c.get('role')]
        del self.cohorts

    def populate_obj(self, obj):
        self._populate_cohorts(obj)
        # Claim ownership of the new thumbnail if necessary.
        if self.thumbnail_file.data != obj.thumbnail_file:
            redis.zrem('uploaded-files', self.thumbnail_file.data)
        return super(ProjectForm, self).populate_obj(obj)
