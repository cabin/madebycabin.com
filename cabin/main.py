from flask import Blueprint, render_template

main = Blueprint('main', __name__)


@main.route('/')
def index():
    return render_template('work.html', splash=True)


@main.route('/work')
def work():
    return render_template('work.html')


@main.route('/about')
def about():
    return 'about'


@main.route('/lab')
def lab():
    return 'lab'
