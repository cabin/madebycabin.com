from flask import Blueprint, render_template

main = Blueprint('main', __name__)


@main.route('/')
def index():
    return render_template('index.html')


@main.route('/work')
def work():
    return 'work'


@main.route('/about')
def about():
    return 'about'


@main.route('/lab')
def lab():
    return 'lab'
