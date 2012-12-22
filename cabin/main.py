from flask import Blueprint, render_template, request

main = Blueprint('main', __name__)


@main.context_processor
def request_is_pjax():
    return {'request_is_pjax': 'X-PJAX' in request.headers}


@main.route('/')
def index():
    return render_template('work.html', splash=True)


@main.route('/work')
def work():
    return render_template('work.html')


@main.route('/about')
def about():
    return render_template('about.html')


@main.route('/lab')
def lab():
    return render_template('lab.html')
