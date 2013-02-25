import datetime
import json

import flask

from cabin import redis

labs = flask.Blueprint('labs', __name__)


@labs.route('/yoga')
def yoga():
    today = datetime.date.today()
    tomorrow = today + datetime.timedelta(days=1)
    today_classes, tomorrow_classes = redis.hmget(
        'yoga', today.isoformat(), tomorrow.isoformat())
    today_classes = json.loads(today_classes) if today_classes else []
    tomorrow_classes = json.loads(tomorrow_classes) if tomorrow_classes else []
    return flask.render_template(
        'labs/yoga.html',
        schedule={today: today_classes, tomorrow: tomorrow_classes},
        timeformat=timeformat)


# Ghetto pretty time format for yoga schedule.
def timeformat(s):
    t = datetime.datetime.strptime(s, '%H:%M:%S').time()
    h = t.hour
    p = 'am'
    if h == 0:
        h = 12
    elif h >= 12:
        if h > 12:
            h -= 12
        p = 'pm'
    if t.minute == 0:
        return '%d%s' % (h, p)
    else:
        return '%d:%02d%s' % (h, t.minute, p)
