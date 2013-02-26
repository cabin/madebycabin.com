import datetime
import json

import flask

from cabin import auth, redis
from cabin.auth import admin_required

labs = flask.Blueprint('labs', __name__)


@labs.route('/yoga')
def yoga():
    today = datetime.date.today()
    tomorrow = today + datetime.timedelta(days=1)
    today_classes, tomorrow_classes, selected = redis.hmget(
        'yoga', today.isoformat(), tomorrow.isoformat(), 'selected')
    today_classes = load_classes(today_classes)
    tomorrow_classes = load_classes(tomorrow_classes)
    return flask.render_template(
        'labs/yoga.html',
        now=datetime.datetime.now().time(),
        selected=json.loads(selected) if selected else {},
        schedule=[(today, today_classes), (tomorrow, tomorrow_classes)],
        timeformat=timeformat)


@labs.route('/yoga/select', methods=['POST'])
@admin_required
def yoga_select():
    data = flask.request.form.copy()
    data['index'] = int(data['index'])
    redis.hset('yoga', 'selected', json.dumps(data))
    return flask.jsonify({'status': 'ok'})


# Decode JSON and parse time values.
def load_classes(s):
    classes = json.loads(s) if s else []
    for c in classes:
        c['time'] = datetime.datetime.strptime(c['time'], '%H:%M:%S').time()
    return classes


# Ghetto pretty time format for yoga schedule.
def timeformat(t):
    h = t.hour
    m = ''

    if t.minute == 0:
        if h == 0:
            return 'midnight'
        if h == 12:
            return 'noon'
    else:
        m = ':%02d' % t.minute

    if h > 12:
        h -= 12
        ampm = 'p'
    else:
        ampm = 'a'

    return '%d%s%s' % (h, m, ampm)
