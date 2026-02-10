from flask import Flask, render_template, request, redirect, url_for
import boto3
import os
import uuid
from datetime import datetime

app = Flask(__name__)

# Configure DynamoDB
dynamodb = boto3.resource('dynamodb',
                          region_name=os.getenv('AWS_REGION'),
                          aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
                          aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'))

table = dynamodb.Table(os.getenv('DYNAMO_TABLE_NAME'))

@app.route('/')
def index():
    try:
        response = table.scan()
        notes = sorted(response['Items'], key=lambda x: x['timestamp'], reverse=True)
        return render_template('index.html', notes=notes)
    except Exception as e:
        return f"Error connecting to DynamoDB: {e}", 500

@app.route('/add_note', methods=['POST'])
def add_note():
    note_content = request.form.get('note_content')
    if note_content:
        note_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        table.put_item(
            Item={
                'note_id': note_id,
                'note_content': note_content,
                'timestamp': timestamp
            }
        )
    return redirect(url_for('index'))

@app.route('/delete_note/<note_id>', methods=['POST'])
def delete_note(note_id):
    table.delete_item(
        Key={
            'note_id': note_id
        }
    )
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)