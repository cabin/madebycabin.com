from uwsgidecorators import timer

from cabin import create_app, models


@timer(1800)
def update_feeds(signum):
    with create_app().app_context():
        models.Tumblr.sync()
        models.Instagram.sync()
        models.Flickr.sync()
