from functools import wraps
import json

import flask
import requests

from cabin import redis

auth = flask.Blueprint('auth', __name__)


@auth.route('/login', methods=['POST'])
def login():
    if 'assertion' not in flask.request.form:
        flask.abort(400)
    resp = requests.post('https://verifier.login.persona.org/verify', data={
        'assertion': flask.request.form['assertion'],
        'audience': flask.request.url_root,
    }, verify=True)
    if resp.ok:
        data = json.loads(resp.content)
        if data['status'] == 'okay':
            flask.session['user'] = data['email']
            return resp.content
    flask.abort(500)


@auth.route('/logout', methods=['POST'])
def logout():
    if 'user' in flask.session:
        del flask.session['user']
    return flask.jsonify({'status': 'okay'})


class CurrentUser(object):

    def __init__(self, email=None):
        self.email = email

    def __nonzero__(self):
        return self.email is not None

    @property
    def is_admin(self):
        if not hasattr(self, '_is_admin'):
            self._is_admin = (self.email and
                              redis.sismember('admins', self.email))
        return self._is_admin


def get_current_user():
    if not hasattr(flask.g, 'current_user'):
        flask.g.current_user = CurrentUser(flask.session.get('user', None))
    return flask.g.current_user


def admin_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not get_current_user().is_admin:
            flask.abort(401)
        return f(*args, **kwargs)
    return wrapper
