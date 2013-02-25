from collections import defaultdict
from datetime import datetime, timedelta
import json

import lxml.html
import requests


def fetch_schedule_node(date):
    base_url = 'https://clients.mindbodyonline.com/ASP/'
    s = requests.Session()
    # Get the studio page once to set the studioid cookie, then post with the
    # date to get the frameset page.
    url = base_url + 'home.asp?studioid=1972'
    s.get(url)
    r = s.post(url, params={'date': date.strftime('%m/%d/%Y')})
    # Get the frame page.
    html = lxml.html.fromstring(r.content)
    frame = html.xpath('//frame[@name="mainFrame"]')[0]
    url = base_url + frame.get('src')
    r = s.get(url)
    # Return just the table we're interested in.
    html = lxml.html.fromstring(r.content)
    return html.xpath('//table[@id="classSchedule-mainTable"]')[0]


def text(node, index=None):
    text = list(node.itertext())
    if index is not None:
        text = [text[index]]
    return ''.join(s.strip() for s in text).encode('ascii', 'ignore')


def parse_schedule(schedule_node):
    schedule = defaultdict(list)
    date = None
    for node in schedule_node.getchildren():
        # Ignore thead.
        if node.tag != 'tr':
            continue
        if node[0].get('class') == 'header':
            date_s = text(node, index=-1)
            date = datetime.strptime(date_s, '%B %d, %Y').date().isoformat()
            continue
        time, _, class_type, teacher, studio, _, _ = node.getchildren()
        # We don't care about classes that aren't in the Portland studio.
        if text(studio) != 'Portland':
            continue
        class_type, duration = parse_class_type(text(class_type))
        schedule[date].append({
            'time': datetime.strptime(text(time), '%I:%M%p').time().isoformat(),
            'type': class_type,
            'duration': duration,
            'teacher': text(teacher),
        })
    return schedule


def parse_class_type(class_type):
    class_type, duration = class_type.lower().split('(')
    duration = duration.split(' ')[0]
    for t in ('hatha', 'vinyasa', 'yin'):
        if t in class_type:
            class_type = t
    return class_type, duration


def schedule_week_of(day):
    schedule_node = fetch_schedule_node(day)
    return parse_schedule(schedule_node)


def sync_schedule(redis):
    today = datetime.now().date()
    schedule = schedule_week_of(today)
    # To ensure we have tomorrow's data, if today ends a week, also fetch next
    # week's data.
    if today.weekday() == 6:
        schedule.update(schedule_week_of(today + timedelta(days=1)))
    for date, classes in schedule.items():
        redis.hset('yoga', date, json.dumps(classes))
