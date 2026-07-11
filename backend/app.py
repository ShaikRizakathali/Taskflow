from flask import Flask, jsonify, request
from flask_cors import CORS
import uuid
from datetime import datetime

app = Flask(__name__)
CORS(app)

tasks = []


@app.route('/api/tasks', methods=['GET'])
def get_tasks():
    """Return all tasks as a json response."""
    status_filter = request.args.get('status')

    if status_filter == 'completed':
        filtered_tasks = [task for task in tasks if task['completed']]
    elif status_filter == 'active':
        filtered_tasks = [task for task in tasks if not task['completed']]
    else:
        filtered_tasks = tasks

    return jsonify({
        'tasks': filtered_tasks,
        'count': len(filtered_tasks)
    })


@app.route('/api/tasks', methods=['POST'])
def create_task():
    """Create a new task from the JSON data sent by the user."""
    data = request.get_json()

    if not data or 'title' not in data:
        return jsonify({'error': 'Title is required'}), 400

    new_task = {
        'id': str(uuid.uuid4()),
        'title': data['title'],
        'description': data.get('description', ''),
        'priority': data.get('priority', 'medium'),
        'completed': False,
        'created_at': datetime.now().isoformat()
    }

    tasks.append(new_task)
    return jsonify(new_task), 201


@app.route('/api/tasks/<task_id>', methods=['PUT'])
def update_task(task_id):
    """Update an existing task."""
    data = request.get_json()

    for task in tasks:
        if task['id'] == task_id:
            if 'title' in data:
                task['title'] = data['title']
            if 'description' in data:
                task['description'] = data['description']
            if 'priority' in data:
                task['priority'] = data['priority']
            if 'completed' in data:
                task['completed'] = data['completed']
            return jsonify(task), 200

    return jsonify({'error': 'Task not found'}), 404


@app.route('/api/tasks/<task_id>', methods=['DELETE'])
def delete_task(task_id):
    """Delete a task by its ID."""
    for i, task in enumerate(tasks):
        if task['id'] == task_id:
            tasks.pop(i)
            return jsonify({'message': 'Task deleted'}), 200

    return jsonify({'error': 'Task not found'}), 404


if __name__ == '__main__':
    print("🚀 TaskFlow API is running on http://localhost:2505")
    print("📝 Try visiting http://localhost:2505/api/tasks")
    app.run(debug=False, port=2505, host='0.0.0.0')
    
            