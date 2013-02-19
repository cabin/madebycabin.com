import pytest

from cabin.util.validated_hash import ValidatedHash


class Empty(ValidatedHash):
    schema = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {}
    }


class Defaults(ValidatedHash):
    schema = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {
            'boolF': {'type': 'boolean'},
            'boolT': {'type': 'boolean', 'default': True},
            'string': {'type': 'string'},
            'int': {'type': 'integer'},
            'stringSpam': {'type': 'string', 'default': 'spam'},
            'array': {'type': 'array'},
        }
    }


class Nested(ValidatedHash):
    schema = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {
            'name': {'type': 'string', 'required': True},
            'intList': {
                'type': 'array',
                'items': {'type': 'integer'},
            },
            'menu': {
                'type': 'array',
                'uniqueItems': True,
                'items': {
                    'type': 'object',
                    'properties': {
                        'name': {'type': 'string', 'required': True},
                        'price': {'type': 'integer', 'required': True},
                    }
                }
            }
        }
    }


class Required(ValidatedHash):
    schema = {
        'type': 'object',
        'additionalProperties': False,
        'properties': {
            'req': {'type': 'string', 'required': True},
            'notreq': {'type': 'string', 'required': False},
        }
    }



def test_ignore_bad_input():
    obj = Empty.decode({'no': 'valid', 'properties': 'here'})
    assert obj.__dict__ == {}
    assert obj.is_valid() is True


def test_default_values():
    obj = Defaults.decode({})
    assert obj.boolF == False
    assert obj.boolT == True
    assert obj.string == ''
    assert obj.stringSpam == 'spam'
    assert obj.array == []
    # Ensure that defaults don't *always* override decoded values.
    obj = Defaults.decode(
        {'boolF': True, 'boolT': False, 'string': 'foo', 'stringSpam': 'bar'})
    assert obj.boolF == True
    assert obj.boolT == False
    assert obj.string == 'foo'
    assert obj.stringSpam == 'bar'


def test_coercion():
    obj = Defaults.decode({
        'int': '123',
        'boolF': 'False',
        'boolT': 'True',
    })
    assert obj.int == 123
    assert obj.boolF == False
    assert obj.boolT == True


def test_nested_object():
    obj = Nested.decode({})
    assert obj.menu == []
    obj = Nested.decode({'menu': [{'name': 'eggs', 'price': '12'}]})
    assert obj.menu[0]['name'] == 'eggs'
    assert obj.menu[0]['price'] == 12
    obj = Nested.decode({'intList': ['1', '2', '3']})
    assert obj.intList == [1, 2, 3]


def test_nested_json():
    pytest.skip('TODO')


def test_validation():
    pytest.skip('TODO')


def test_not_required():
    obj = Required(req='x').encode()
    assert 'notreq' not in obj
