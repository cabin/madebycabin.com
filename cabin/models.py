import collections
from itertools import groupby
import json

import jsonschema

from cabin import images, redis
from cabin.util.validated_hash import ValidatedHash


# Since these won't change much, storing them in Redis just complicates things.
# This way, each project stores a set of Service IDs, and the appropriately-
# grouped display object can be constructed in Python. Order here determines
# display order, and IDs must not change or be duplicated.
ServiceType = collections.namedtuple('ServiceType', 'id, name')
Service = collections.namedtuple('Service', 'id, type, name')

SERVICE_TYPES = [
    ServiceType('pln', 'Planning <span class="thin-text">/</span> Strategy'),
    ServiceType('dsn', 'Design'),
    ServiceType('dev', 'Development'),
]
SERVICES = [
    Service( 1, 'pln', 'Research and audits'),
    Service( 2, 'pln', 'Brand strategy'),
    Service( 3, 'pln', 'Product strategy'),
    Service( 4, 'pln', 'Content planning'),
    Service( 5, 'pln', 'Idea generation'),
    Service( 6, 'pln', 'Prioritization and metrics'),
    Service( 7, 'pln', 'Training and education'),

    Service( 8, 'dsn', 'Brand guidelines'),
    Service( 9, 'dsn', 'Identity design'),
    Service(11, 'dsn', 'Environmental and signage'),
    Service(12, 'dsn', 'Print and packaging'),
    Service(13, 'dsn', 'Information architecture'),
    Service(14, 'dsn', 'Interaction design'),
    Service(15, 'dsn', 'Multi-screen design'),
    Service(16, 'dsn', 'Prototyping'),
    Service(17, 'dsn', 'Usability testing'),
    Service(18, 'dsn', 'Data visualization'),
    Service(19, 'dsn', 'Photography'),

    Service(20, 'dev', 'Software architecture'),
    Service(21, 'dev', 'Database design'),
    Service(22, 'dev', 'API / services layer definition'),
    Service(23, 'dev', 'Build consultation'),
    Service(24, 'dev', 'Front-end development'),
    Service(25, 'dev', 'Back-end development'),
    Service(26, 'dev', 'Social media integration'),
    Service(27, 'dev', 'Dev ops'),
    Service(28, 'dev', 'Quality assurance'),
    Service(29, 'dev', 'Analytics'),
]

# Sanity check: no duplicate IDs, all services have a valid type.
assert len(SERVICES) == len({s.id for s in SERVICES})
assert {st.id for st in SERVICE_TYPES} == {s.type for s in SERVICES}


SCHEMAS = {
    'cohorts': {
        'type': 'array',
        'uniqueItems': True,
        'default': [],
        'items': {
            'type': 'object',
            'additionalProperties': False,
            'properties': {
                'name': {'type': 'string', 'required': True},
                'role': {'type': 'string', 'required': True},
                'twitter_user': {'type': 'string'},
            },
        },
    },
    'images': {
        'type': 'array',
        'uniqueItems': True,
        'default': [],
        'items': {
            'type': 'object',
            'additionalProperties': False,
            'properties': {
                'file': {'type': 'string', 'required': True},
                # Width is assumed to be 1100px.
                'height': {'type': 'integer', 'required': True},
                'shadow': {'type': 'boolean', 'default': False},
            },
        },
    },
    'services': {
        'type': 'array',
        'uniqueItems': True,
        'default': [],
        'items': {'type': 'integer'},
    },
}
SCHEMAS['project'] = {
    'type': 'object',
    'additionalProperties': False,
    'properties': {
        'slug': {'type': 'string', 'required': True, 'minLength': 2},
        'title': {'type': 'string', 'required': True, 'minLength': 2},
        'type': {'type': 'string', 'required': True, 'minLength': 2},
        'is_featured': {'type': 'boolean', 'required': True, 'default': False},
        'brief': {'type': 'string', 'required': True},
        'thumbnail_file': {'type': 'string', 'required': True},
        'external_url': {'type': 'string', 'format': 'uri'},
        '_cohorts': SCHEMAS['cohorts'],
        '_images': SCHEMAS['images'],
        '_services': SCHEMAS['services'],
    }
}


class Project(ValidatedHash):
    schema = SCHEMAS['project']
    summary_attrs = ('slug', 'title', 'type', 'is_featured', 'thumbnail_file')

    @classmethod
    def get_summaries(cls, private=False):
        key = 'projects:%s' % ('private' if private else 'public')
        ids = redis.lrange(key, 0, -1)
        with redis.pipeline() as pipe:
            for _id in ids:
                pipe.hmget('project:%s' % _id, *cls.summary_attrs)
            results = pipe.execute()
        return [cls.decode(dict(zip(cls.summary_attrs, r))) for r in results]

    @classmethod
    def get(cls, _id, allow_private=False):
        _id = str(_id)
        key = 'project:%s' % _id
        project = None
        extra_attrs = {'_id': _id}
        public_projects = redis.lrange('projects:public', 0, -1)
        try:
            pindex = public_projects.index(_id)
        except ValueError:
            # Not in the list of public projects.
            if allow_private:
                project = redis.hgetall(key)
        else:
            # Find the prev/next slugs (and wrap around).
            prev_index = (pindex - 1) % len(public_projects)
            next_index = (pindex + 1) % len(public_projects)
            with redis.pipeline() as pipe:
                pipe.hgetall(key)
                pipe.hget('project:%s' % public_projects[prev_index], 'slug')
                pipe.hget('project:%s' % public_projects[next_index], 'slug')
                project, extra_attrs['prev_slug'], extra_attrs['next_slug'] = (
                    pipe.execute())
        if project:
            project = cls.decode(project)
            for name, value in extra_attrs.items():
                setattr(project, name, value)
        return project

    @classmethod
    def get_by_slug(cls, slug, allow_private=False):
        key = 'project:slug:%s' % slug.lower()
        return cls.get(redis.get(key), allow_private=allow_private)

    @property
    def grouped_services(self):
        "Convert the list of services into ordered names grouped by type."
        services = filter(lambda s: s.id in self.services, SERVICES)
        grouped = groupby(services, key=lambda s: s.type)
        types = dict(SERVICE_TYPES)
        return [(types[k], [s.name for s in g]) for k, g in grouped]

    @property
    def is_public(self):
        _id = getattr(self, '_id', None)
        return _id and str(self._id) in redis.lrange('projects:public', 0, -1)

    @is_public.setter
    def is_public(self, value):
        if value == self.is_public:
            return
        self._is_public = value

    @property
    def thumbnail_url(self):
        if self.thumbnail_file:
            return images.url(self.thumbnail_file)

    def _save_slug(self):
        "Ensure the slug is not used by another id before saving it."
        key = 'project:slug:%s' % self.slug.lower()
        def save_unique_slug(pipe):
            current = pipe.get(key)
            # If the slug key is unset, set it to our ID.
            if current is None:
                pipe.multi()
                pipe.set(key, self._id)
            # If it's set to another ID, we have a problem.
            elif int(current) != int(self._id):
                raise ValueError('duplicate slug')  # XXX
            # Otherwise, it's already set to our ID; do nothing.
        redis.transaction(save_unique_slug, key)

    def _save_publicity(self, is_new):
        value = getattr(self, '_is_public', False if is_new else None)
        if value is not None:
            from_key, to_key = ['projects:public', 'projects:private']
            if value:
                from_key, to_key = ['projects:private', 'projects:public']
            with redis.pipeline() as pipe:
                pipe.lrem(from_key, 0, self._id)
                pipe.rpush(to_key, self._id)
                pipe.execute()

    def save(self):
        if not self.is_valid():
            raise ValueError('invalid objects cannot be saved')
        is_new = not hasattr(self, '_id')
        if is_new:
            self._id = redis.incr('projects:last-id')
        key = 'project:%s' % self._id
        redis.hmset(key, self.encode())
        self._save_publicity(is_new)
        self._save_slug()
