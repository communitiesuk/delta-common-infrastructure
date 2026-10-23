import random

from .processing import SendFailure, process_record


def retry_delay(attempt, status=None):
    base = 300 if status == 429 else 30
    return min(3600, base * 2 ** min(max(attempt - 1, 0), 6)) + random.randint(0, 10)


def handle_batch(records, retry=None):
    failures = []
    for record in records:
        try:
            process_record(record)
        except SendFailure as error:
            failures.append({"itemIdentifier": record["messageId"]})
            if retry is not None:
                delay = retry_delay(int(record.get("attributes", {}).get("ApproximateReceiveCount", "1")), error.status)
                try:
                    retry(record["receiptHandle"], delay)
                except Exception:
                    # The original message must still be reported as failed.
                    pass
    return {"batchItemFailures": failures}


def handler(event, context):
    import boto3
    import os
    client = boto3.client("sqs")
    def retry(receipt, delay):
        client.change_message_visibility(QueueUrl=os.environ["SQS_QUEUE_URL"], ReceiptHandle=receipt, VisibilityTimeout=delay)
    return handle_batch(event["Records"], retry)
