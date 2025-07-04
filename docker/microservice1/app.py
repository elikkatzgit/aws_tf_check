import boto3
import json
import time
import os
import uuid

# ENV vars
QUEUE_URL = os.environ.get("SQS_QUEUE_URL")
S3_BUCKET = os.environ.get("S3_BUCKET_NAME")

# Clients
sqs = boto3.client('sqs')
s3 = boto3.client('s3')

def poll_sqs_and_push_to_s3():
    while True:
        response = sqs.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=10,
            WaitTimeSeconds=10
        )

        messages = response.get('Messages', [])
        if not messages:
            print("No messages, waiting...")
            time.sleep(5)
            continue

        for msg in messages:
            try:
                message_body = msg['Body']
                file_key = f"messages/{uuid.uuid4()}.json"

                # Store in S3
                s3.put_object(
                    Bucket=S3_BUCKET,
                    Key=file_key,
                    Body=message_body,
                    ContentType='application/json'
                )
                print(f"Stored message to S3: {file_key}")

                # Delete from SQS
                sqs.delete_message(
                    QueueUrl=QUEUE_URL,
                    ReceiptHandle=msg['ReceiptHandle']
                )
            except Exception as e:
                print(f"Error processing message: {e}")

if __name__ == "__main__":
    poll_sqs_and_push_to_s3()
