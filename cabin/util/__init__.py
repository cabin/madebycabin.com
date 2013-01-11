import urllib
import urlparse


def hostname(s):
    if s:
        return urlparse.urlparse(s.encode('utf8')).hostname
    return ''


def urlquote(s):
    if s:
        return urllib.quote_plus(s.encode('utf8'), safe='/')
    return ''
