import datetime
import os.path
import shutil
import tempfile

from fabric.api import *
from fabric.contrib.files import exists
from fabric.contrib.project import rsync_project


env.app_name = 'cabin'
env.branch = 'master'
env.hosts = ['madebycabin.com']  # XXX

env.user = 'root'
env.key_filename = os.path.expanduser('~/.ssh/cabin.pem')

env.uwsgi_conf = os.path.join('/etc/uwsgi/apps', env.app_name)
env.app_dir = os.path.join('/srv/http', env.app_name)
env.virtualenv_dir = os.path.join(env.app_dir, 'virtualenv')
env.sync_dir = os.path.join(env.app_dir, 'sync')
env.release_dir = os.path.join(env.app_dir, 'releases')
env.current_dir = os.path.join(env.app_dir, 'current')


# XXX unneeded?
#def bootstrap():
    # push uwsgi.conf to env.uwsgi_dir/app_name.conf
    #/etc/uwsgi/apps/<app_name>.conf
    #/srv/http/<app_name>
    #    sock
    #    sync
    #    releases/...
    #    current -> releases/...


# Export the latest revision on `branch` to a temporary directory, then rsync
# it with the remote syncdir (to save some bandwidth on small changes), then
# recursively copy it into its final remote place.
def make_release():
    require('branch', 'sync_dir', 'release_dir')
    env.version = datetime.datetime.now().strftime('%Y%m%dT%H%M%S')
    tmpdir = tempfile.mkdtemp()
    os.chmod(tmpdir, 0755)
    with hide('running'):
        puts('Publishing from the %(branch)s branch...' % env)
        # git archive's output is affected by CWD.
        git_dir = '$(git rev-parse --show-toplevel)'
        local('cd %s && git archive %s | tar -x -C %s' % (
            git_dir, env.branch, tmpdir))
        local('cd %s && ./manage assets build' % tmpdir)
        local('find %s -type d -name .webassets-cache | xargs rm -rf' % tmpdir)
        sudo('mkdir -p %(release_dir)s' % env)
        rsync_project(env.sync_dir, local_dir=tmpdir + '/', delete=True)
        shutil.rmtree(tmpdir)
        sudo('cp -R %(sync_dir)s %(release_dir)s/%(version)s' % env)
        # If there is a local_settings.cfg on the remote, link to it.
        local_settings = os.path.join(env.app_dir, 'local_settings.cfg')
        if exists(local_settings):
            release_dir = os.path.join(env.release_dir, env.version)
            run('ln -s %s %s' % (local_settings, release_dir))


def update_virtualenv():
    require('release_dir', 'version', 'virtualenv_dir')
    if not exists(env.virtualenv_dir):
        run('virtualenv --quiet --distribute -p python2 %s' % env.virtualenv_dir)
    with hide('running', 'output'):
        puts('Updating python libraries...')
        sudo('%(virtualenv_dir)s/bin/pip install -r %(release_dir)s/%(version)s/requirements.txt' % env)


def link_release():
    require('release_dir', 'current_dir', 'version')
    if not exists('%(release_dir)s/%(version)s' % env):
        abort('%(version)s does not exist' % env)
    with hide('running'):
        puts('Setting %(version)s as the current release...' % env)
        sudo('ln -sfn %(release_dir)s/%(version)s %(current_dir)s' % env)


def reload_uwsgi():
    require('uwsgi_conf')
    # Touching the uwsgi configuration file causes the emperor to reload.
    run('touch %(uwsgi_conf)s.ini' % env)


@task
def deploy(branch=None):
    "Deploy the latest version of all configs and sites."
    if branch is not None:
        env.branch = branch
    make_release()
    update_virtualenv()
    link_release()
    reload_uwsgi()
    # TODO: cleanup old releases to conserve space?


@task
def rollback(version=None):
    "Rollback to the specified version."
    if not version:
        raise Exception('TODO: find latest non-current version')  # XXX
    env.version = version
    link_release()
    update_virtualenv()
    reload_uwsgi()


@task
def manage(cmd):
    "Run a Flask-Script command."
    require('virtualenv_dir', 'current_dir')
    manage = '%(virtualenv_dir)s/bin/python %(current_dir)s/manage' % env
    run('%s %s' % (manage, cmd))


@task
def sync():
    "Copy the production data to the local instance."
    require('app_dir')
    local_instance = '$(git rev-parse --show-toplevel)/instance'
    local('cp %s/dump.rdb %s/dump.rdb.backup' % (
        local_instance, local_instance))
    local('rsync %s:/var/lib/redis/dump.rdb %s' % (
        env.host_string, local_instance))
    local('rsync -rv %s:%s/instance/images/ %s/images' % (
        env.host_string, env.app_dir, local_instance))
