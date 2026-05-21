import os
from datetime import datetime
from zoneinfo import ZoneInfo

import boto3

s3 = boto3.client("s3")
sns = boto3.client("sns")


def lambda_handler(event, context):
    bucket = os.environ["BUCKET_NAME"]
    prefix_base = os.environ.get("PREFIX", "latest/form-data/")
    topic_arn = os.environ["SNS_TOPIC_ARN"]

    timezone = os.environ.get("TIMEZONE", "Europe/London")

    now_local = datetime.now(ZoneInfo(timezone))
    target_date = (now_local.date()).isoformat()

    search_prefix = f"{prefix_base}Manifest_{target_date}"

    resp = s3.list_objects_v2(Bucket=bucket, Prefix=search_prefix, MaxKeys=1000)
    contents = resp.get("Contents", [])
    found_csv = any(obj["Key"].endswith(".csv") for obj in contents)

    if found_csv:
        return {"status": "ok", "date": target_date, "found": True}

    msg = (
        f"DAP manifest missing.\n"
        f"Bucket: {bucket}\n"
        f"Prefix searched: {search_prefix}*.csv\n"
        f"Expected date: {target_date}\n"
        f"Checked at: {now_local.isoformat()}\n"
    )

    sns.publish(
        TopicArn=topic_arn,
        Subject=f"DAP manifest missing for {target_date} ({bucket})",
        Message=msg,
    )

    return {"status": "alert_sent", "date": target_date, "found": False}
