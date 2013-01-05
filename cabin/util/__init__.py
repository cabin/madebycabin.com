import urlparse


def hostname(s):
    if s:
        return urlparse.urlparse(s).hostname
    return ''
