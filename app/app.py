import os
from flask import Flask, render_template, request, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
from sqlalchemy import func

app = Flask(__name__)

# Configure the PostgreSQL database
user = os.getenv('POSTGRES_USER')
password = os.getenv('POSTGRES_PASSWORD')
db = os.getenv('POSTGRES_DB')
host = os.getenv('POSTGRES_HOST')
app.config['SQLALCHEMY_DATABASE_URI'] = f'postgresql://{user}:{password}@{host}/{db}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Define the Task model
class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)
    interval = db.Column(db.Integer, nullable=False)

# Define the Record model
class Record(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    task_id = db.Column(db.Integer, db.ForeignKey('task.id'), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)
    task = db.relationship('Task', backref=db.backref('Records', lazy=True))

# Create the database tables (run once at app startup)
@app.before_request
def create_tables():
    if not hasattr(create_tables, '_initialized'):
        db.create_all()
        create_tables._initialized = True

@app.route('/', methods=['GET'])
def index():
    tasks = Task.query.all()
    if len(tasks) == 0:
        return render_template('no_records.html'), 200
    latest_records = db.session.query(
        Record.task_id,
        func.max(Record.timestamp).label('latest_timestamp')
    ).group_by(Record.task_id).all()
    latest_records_dict = {exec_entry.task_id: exec_entry.latest_timestamp for exec_entry in latest_records}
    latest_records_data = []
    for task in tasks:
        latest_timestamp = latest_records_dict.get(task.id)
        latest_record = None
        next_due_date = None
        if latest_timestamp:
            latest_record = Record.query.filter_by(
                task_id=task.id,
                timestamp=latest_timestamp
            ).first()
            next_due_date = latest_timestamp + timedelta(days=task.interval)
        latest_records_data.append({
            'task': task,
            'record': latest_record,
            'next_due_date': next_due_date
        })
    return render_template('index.html', records=latest_records_data), 200

@app.route('/complete', methods=['GET'])
def complete():
    now = datetime.now()
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    record = Record(task_id=task.id, timestamp=now.replace(microsecond=0))
    db.session.add(record)
    db.session.commit()
    return redirect(url_for('index'))

@app.route('/enter_date', methods=['GET', 'POST'])
def enter_date():
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    if request.method == 'POST':
        completion_date_str = request.form['completion_date']
        completion_date = datetime.strptime(completion_date_str, '%Y-%m-%dT%H:%M')
        record = Record(task_id=task.id, timestamp=completion_date)
        db.session.add(record)
        db.session.commit()
        return redirect(url_for('index'))
    return render_template('enter_date.html', task=task), 200

@app.route('/history', methods=['GET', 'POST'])
def history():
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    records = Record.query.filter_by(task_id=task.id).order_by(Record.timestamp.desc()).all()
    return render_template('history.html', task=task, records=records), 200

@app.route('/record_delete', methods=['GET'])
def record_delete():
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    record_id = request.args['record_id']
    record: Record | None = Record.query.get(record_id)
    if record is None:
        return f"Record with id {task_id} does not exist", 404
    try:
        db.session.delete(record)
        db.session.commit()
        return redirect(url_for('history', id=task_id))
    except Exception as e:
        db.session.rollback()
        return f"An error occurred while deleting the record: {e}", 500

@app.route('/tasks', methods=['GET'])
def read_tasks():
    all_tasks = Task.query.all()
    if len(all_tasks) == 0:
        return render_template('tasks/no_tasks.html'), 200
    return render_template('tasks/index.html', tasks=all_tasks), 200

@app.route('/task_create', methods=['GET'])
def task_create():
    return render_template('tasks/create.html'), 200

@app.route('/task_create_confirmation', methods=['POST'])
def task_create_confirmation():
    name = request.form['name']
    interval = int(request.form['interval'])
    new_task = Task(name=name, interval=interval)
    db.session.add(new_task)
    db.session.commit()
    return render_template('tasks/create_confirmation.html', task=new_task), 200

@app.route('/task_update', methods=['GET'])
def task_update():
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    return render_template('tasks/update.html', task=task), 200

@app.route('/task_update_confirmation', methods=['POST'])
def update_tasks():
    print(request.form)
    task_id = request.form['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    old_name = task.name
    old_interval = task.interval
    new_name = request.form['name']
    new_interval = int(request.form['interval'])
    task.name = new_name
    task.interval = new_interval
    db.session.commit()
    return render_template('tasks/update_confirmation.html', task=task, old_name=old_name, old_interval=old_interval)

@app.route('/task_delete', methods=['GET'])
def task_delete():
    task_id = request.args['id']
    task: Task | None = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    return render_template('tasks/delete.html', task=task), 200

@app.route('/task_delete_confirmation', methods=['POST'])
def delete_tasks():
    task_id = request.form.get('id')
    task = Task.query.get(task_id)
    if task is None:
        return f"Task with id {task_id} does not exist", 404
    try:
        Record.query.filter_by(task_id=task_id).delete()
        db.session.delete(task)
        db.session.commit()
        return render_template('tasks/delete_confirmation.html', task=task), 200
    except Exception as e:
        db.session.rollback()
        return f"An error occurred while deleting the task: {e}", 500


if __name__ == '__main__':
    app.run(debug=True)
