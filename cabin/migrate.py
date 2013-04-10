from cabin import redis
from cabin.models import Project


def _update_cohort_twitter_user(project):
    for c in project.cohorts:
        if c['twitter_user']:
            c['url'] = 'https://twitter.com/%s' % c['twitter_user']
            c['twitter_user'] = ''


def migrate_twitter_user():
    for key in 'projects:public', 'projects:private':
        ids = redis.lrange(key, 0, -1)
        for _id in ids:
            project = Project.get(_id, allow_private=True)
            if project.cohorts:
                _update_cohort_twitter_user(project)
                project.save()
