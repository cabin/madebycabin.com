from itertools import groupby
import os

import flask
from flask.ext.wtf import Form, ValidationError
from wtforms import Form as SimpleForm
from wtforms.fields import *
from wtforms.validators import *

from cabin import images, redis
from cabin.models import SERVICES, SERVICE_TYPES
from cabin.util.fields import SelectMultipleGroupedField, StringListField


def grouped_services():
    grouped = groupby(SERVICES, key=lambda s: s.type)
    types = dict(SERVICE_TYPES)
    return [(types[k], [(s.id, s.name) for s in g]) for k, g in grouped]


class CohortForm(SimpleForm):
    name = StringField('Name')
    role = StringField('Role')
    twitter_user = StringField('@username')

    def validate_twitter_user(self, field):
        if field.data and 'twitter.com' in field.data:
            raise ValidationError('Just the username, not the whole URL.')
        # Remove whitespace and errant leading '@'
        field.data = field.data.strip().lstrip('@')

    def validate_name(self, field):
        # Since we can't mark name and role as required on the fields
        # themselves while still allowing submission with an empty form,
        # instead ensure that they're both set if either one is set.
        if bool(field.data) != bool(self.role.data):
            raise ValidationError('Name and role are required.')


class ImageForm(SimpleForm):
    file = StringField('File')
    height = IntegerField('Height')
    shadow = StringField('Shadowed', default='0')

    def validate_shadow(self, field):
      # This is displayed as a hidden field, which means string values.
      # BooleanField is naive about conversion, so it has to happen here.
      field.data = field.data in ['1', 'true', 'True']


class ProjectForm(Form):
    slug = StringField('URL slug', [InputRequired(), Length(min=2, max=64)],
                       filters=[lambda s: s and s.strip()])
    title = TextAreaField('Title', [InputRequired(), Length(min=2)])
    type = StringField('Project type', [InputRequired(), Length(min=2)])
    is_public = BooleanField('Public', default=False)
    is_featured = BooleanField('Featured', default=False)
    is_slideshow = BooleanField('Be the movie', default=False)
    brief = TextAreaField('Brief', [InputRequired()],
                          description='Keep it that way.')
    thumbnail_file = HiddenField(validators=[InputRequired()])
    external_url = StringField('URL in the wild', [Optional(), URL()])

    services = SelectMultipleGroupedField(
        choices=grouped_services(), coerce=int)
    cohorts = FieldList(FormField(CohortForm), min_entries=1)
    dev_shortlist = StringListField('Development Shortlist')
    images = FieldList(FormField(ImageForm))

    def validate_slug(self, field):
        if not field.data.replace('-', '').isalnum():
            raise ValidationError(
                'Slug must contain only "-" and alphanumerics.')

    def _populate_cohorts(self, obj):
        obj.cohorts = [c for c in self.cohorts.data
                       if c.get('name') and c.get('role')]
        del self.cohorts

    def _populate_images(self, obj):
      previous = set(img['file'] for img in getattr(obj, 'images', []))
      current = set(img['file'] for img in self.images.data)
      obj.images = self.images.data
      del self.images
      # Delete files that were removed from the list, and claim ownership of
      # any new files.
      for old_file in previous - current:
        os.unlink(images.path(old_file))
      for new_file in current - previous:
        redis.zrem(flask.current_app.config['UPLOAD_QUEUE'], new_file)

    def populate_obj(self, obj):
        self._populate_cohorts(obj)
        self._populate_images(obj)
        # Claim ownership of the new thumbnail if necessary.
        if hasattr(obj, 'thumbnail_file'):
            if self.thumbnail_file.data != obj.thumbnail_file:
                os.unlink(images.path(obj.thumbnail_file))
                redis.zrem(flask.current_app.config['UPLOAD_QUEUE'],
                           self.thumbnail_file.data)
        return super(ProjectForm, self).populate_obj(obj)
