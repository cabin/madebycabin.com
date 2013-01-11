import urllib
import urlparse


def hostname(s):
    if s:
        return urlparse.urlparse(s).hostname
    return ''


def urlquote(s):
    if s:
        return urllib.quote_plus(s, safe='/')
    return ''
