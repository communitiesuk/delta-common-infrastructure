import json
import logging
import os
from datetime import datetime, timedelta, timezone


logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    import boto3
    from botocore.config import Config

    check_rotation(
        boto3.client("secretsmanager"),
        boto3.client("dynamodb"),
        boto3.client("ses", config=Config(retries={"total_max_attempts": 1})),
        secret_arn=os.environ["SECRET_ARN"],
        table=os.environ["CLAIMS_TABLE"],
        from_address=os.environ["FROM_ADDRESS"],
        to_addresses=json.loads(os.environ["TO_ADDRESSES"]),
        environment=os.environ["ENVIRONMENT"],
        today=datetime.now(timezone.utc).date(),
    )


def check_rotation(
    secrets, dynamodb, ses, *, secret_arn, table, from_address, to_addresses, environment, today
):
    metadata = secrets.describe_secret(SecretId=secret_arn)
    if not metadata.get("RotationEnabled"):
        logger.info("Skipping reminder: rotation is disabled")
        return
    next_rotation = metadata.get("NextRotationDate")
    if next_rotation is None:
        logger.info("Skipping reminder: AWS did not report a next rotation date")
        return
    rotation_date = next_rotation.astimezone(timezone.utc).date()
    if rotation_date != today + timedelta(days=14):
        logger.info("Skipping reminder: reported rotation date %s is not 14 days away", rotation_date)
        return

    current_versions = [
        version
        for version, stages in metadata.get("VersionIdsToStages", {}).items()
        if "AWSCURRENT" in stages
    ]
    if len(current_versions) != 1:
        raise ValueError("Expected exactly one AWSCURRENT secret version for a due reminder")

    key = {"cycle": {"S": f"{secret_arn}#{current_versions[0]}"}}
    try:
        dynamodb.put_item(
            TableName=table,
            Item={**key, "rotation_date": {"S": rotation_date.isoformat()}},
            ConditionExpression="attribute_not_exists(cycle)",
        )
    except dynamodb.exceptions.ConditionalCheckFailedException:
        logger.info("Skipping reminder: this rotation cycle has already been claimed")
        return

    try:
        message = ses.send_email(
            Source=from_address,
            Destination={"ToAddresses": to_addresses},
            Message={
                "Subject": {"Data": f"[{environment}] Azure DAP export key rotation reminder"},
                "Body": {
                    "Text": {
                        "Data": (
                            f"Secret: {metadata['Name']}\n"
                            f"Latest scheduled rotation date reported by AWS: {rotation_date} (UTC)\n\n"
                            "Coordinate with the Azure DAP export owner before rotation. "
                            "Ensure Azure picks up the new credentials when they become current "
                            "and verify the export can still read S3. Rotation deletes the old key."
                        )
                    }
                },
            },
        )
    except Exception:
        # A failed response may still mean SES accepted the email.
        logger.exception("Reminder send failed or is unconfirmed; retaining the cycle claim")
        raise

    dynamodb.update_item(
        TableName=table,
        Key=key,
        UpdateExpression="SET ses_message_id = :id",
        ExpressionAttributeValues={":id": {"S": message["MessageId"]}},
    )
    logger.info("SES accepted rotation reminder %s for %s", message["MessageId"], rotation_date)
