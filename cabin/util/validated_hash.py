import collections
import json

import jsonschema


# As we're stuck with only Redis for now, this hack provides a data access
# layer.
class ValidatedHash(object):
    """A simple wrapper around objects stored as Redis hashes.

    Each `ValidatedHash` subclass must have a JSON schema (in the form of a
    dictionary) `schema` attribute, which is used to decode the Redis hash
    members (which are stored as strings) appropriately.
    
    Subclasses can provide `_decode_<type>` methods for custom decoding of
    arbitrary JSON schema types.

    The primary interface is via the `decode` method, which can be passed the
    results of a Redis `HGETALL` command.

    """
    type_map = {
        'array': list,
        'boolean': bool,
        'integer': int,
        'object': dict,
        'string': str,
    }

    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)

    @classmethod
    def decode(cls, data):
        return cls(**cls._decode_object(data, cls.schema))

    @classmethod
    def _get_decoder(cls, _type):
        return getattr(cls, '_decode_%s' % _type, cls._decode_default)

    @classmethod
    def _decode_default(cls, value, schema):
        _type = cls.type_map[schema['type']]
        if value is None:
            if 'default' in schema:
                value = schema['default']
            else:
                value = _type()
        return value

    @classmethod
    def _decode_array(cls, value, schema):
        value = cls._decode_default(value, schema)
        item_schema = schema.get('items')
        if not item_schema:
            return value
        decoder = cls._get_decoder(item_schema['type'])
        arr = []
        for item in value:
            arr.append(decoder(item, item_schema))
        return arr

    @classmethod
    def _decode_boolean(cls, value, schema):
        value = cls._decode_default(value, schema)
        return value in {True, '1', 'True', 'true'}

    @classmethod
    def _decode_integer(cls, value, schema):
        value = cls._decode_default(value, schema)
        return cls.type_map['integer'](value)

    @classmethod
    def _decode_object(cls, value, schema):
        obj = {}
        for name, schema in schema['properties'].items():
            item = value.get(name)
            # A leading underscore indicates a JSON-encoded object (necessary
            # since we can't nest hashes in Redis). We drop the underscore on
            # the output object for API convenience.
            if name.startswith('_'):
                name = name[1:]
                if item is not None:
                    item = json.loads(item)
            item = cls._get_decoder(schema['type'])(item, schema)
            obj[name] = item
        return obj

    def encode(self, skip_json=False):
        obj = {}
        for name in self.schema['properties']:
            if name.startswith('_'):
                item = getattr(self, name[1:])
                if not skip_json:
                    item = json.dumps(item)
            else:
                item = getattr(self, name)
            obj[name] = item
        return obj

    @property
    def errors(self):
        validator = jsonschema.Draft3Validator(self.schema)
        errors = collections.defaultdict(list)
        for error in validator.iter_errors(self.encode(skip_json=True)):
            path = '.'.join(reversed(error.path))
            errors[path].append(error.message)
        return errors

    def is_valid(self):
        return not bool(self.errors)
