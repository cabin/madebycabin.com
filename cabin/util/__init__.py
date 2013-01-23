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
