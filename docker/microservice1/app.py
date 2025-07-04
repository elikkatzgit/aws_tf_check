from flask import Flask, request, jsonify
import boto3
import os
import json

app = Flask(__name__)

# Load env vars
SECRET_NAME = os.environ.get("SECRET_NAME")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
REGION = os.environ.get("AWS_REGION", "us-east-1")

# Init AWS clients
session = boto3.session.Session(region_name=REGION)
secrets_client = session.client('secretsmanager')
sqs = session.client('sqs')

# Cache the token
def get_secret_token():
    response = secrets_client.get_secret_value(SecretId=SECRET_NAME)
    secret_string = response['SecretString']
    return json.loads(secret_string).get("token")

EXPECTED_TOKEN = get_secret_token()

@app.route("/submit", methods=["POST"])
def submit():
    try:
        data = request.get_json()
        if not data or "token" not in data:
            return jsonify({"error": "Missing token"}), 400

        if data["token"] != EXPECTED_TOKEN:
            return jsonify({"error": "Invalid token"}), 403

        # Remove token before sending
        clean_data = {k: v for k, v in data.items() if k != "token"}

        # Push to SQS
        sqs.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(clean_data)
        )

        return jsonify({"status": "success"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
