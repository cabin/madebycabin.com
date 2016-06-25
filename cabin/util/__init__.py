import urllib
import urlparse

from flask import request


def external_url(s):
    if s.startswith('/'):
        return 'http://{}{}'.format(request.host, s)
    return s


def hostname(s):
    if s:
        hostname = urlparse.urlparse(s.encode('utf8')).hostname
        if hostname.startswith('www.'):
            hostname = hostname[4:]
        return hostname
    return ''


def urlquote(s):
    if s:
        return urllib.quote_plus(s.encode('utf8'), safe='/')
    return ''


def browser_version():
    ua = request.user_agent
    try:
        version = ua.version and int(ua.version.split('.')[0])
    except ValueError:
        version = None
    return [ua.browser, version]


def icon_for_url(url):
    icons = {
        'facebook.com': 'facebook',
        'github.com': 'github',
        'instagram.com': 'instagram',
        'twitter.com': 'twitter',
    }
    host = hostname(url)
    return icons.get(host, 'XXX')
