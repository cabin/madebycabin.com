from uwsgidecorators import timer

from cabin import create_app, models, redis
from cabin.labs.yoga import sync_schedule

MINUTE = 60
HOUR = 60 * MINUTE


@timer(30 * MINUTE)
def update_feeds(signum):
    with create_app().app_context():
        models.Tumblr.sync()
        models.Instagram.sync()
        models.Flickr.sync()


@timer(3 * HOUR)
def update_yoga(signum):
    sync_schedule(redis)
