import logging
import math
import os
from datetime import datetime, timezone
from urllib.parse import unquote_plus

import boto3
from botocore.exceptions import ClientError


logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
cloudwatch = boto3.client("cloudwatch")

BUCKET = os.environ["DAP_EXPORT_BUCKET"]
ARCHIVE_PREFIX = os.environ.get("ARCHIVE_PREFIX", "archive/")
LATEST_PREFIX = os.environ.get("LATEST_PREFIX", "latest/")
COPY_OBJECT_LIMIT = 5 * 1024 * 1024 * 1024
MINIMUM_PART_SIZE = 5 * 1024 * 1024
DEFAULT_PART_SIZE = 512 * 1024 * 1024
MAXIMUM_PARTS = 10_000


def lambda_handler(event, context):
    records = event.get("Records", [])
    if not records:
        logger.info("Ignoring event without S3 records")
        return {"promoted": 0, "skipped": 0}

    promoted = 0
    skipped = 0
    for record in records:
        result = promote_record(record)
        if result == "promoted":
            promoted += 1
        else:
            skipped += 1

    return {"promoted": promoted, "skipped": skipped}


def promote_record(record):
    bucket = record["s3"]["bucket"]["name"]
    if bucket != BUCKET:
        raise ValueError(f"Unexpected source bucket {bucket}")

    source = record["s3"]["object"]
    source_key = unquote_plus(source["key"])
    source_version = source.get("versionId")
    sequencer = source.get("sequencer", "0")
    source_date, relative_key = archive_key_parts(source_key)
    destination_key = f"{LATEST_PREFIX}{relative_key}"

    if destination_is_newer(destination_key, source_date, sequencer):
        logger.info("Skipping older or duplicate event for %s", source_key)
        return "skipped"

    head_arguments = {"Bucket": BUCKET, "Key": source_key}
    if source_version:
        head_arguments["VersionId"] = source_version
    source_head = s3.head_object(**head_arguments)

    metadata = dict(source_head.get("Metadata", {}))
    metadata.update(
        {
            "dap-source-date": source_date,
            "dap-source-sequencer": sequencer,
            "dap-source-version": source_version or "unversioned",
        }
    )
    copy_source = {"Bucket": BUCKET, "Key": source_key}
    if source_version:
        copy_source["VersionId"] = source_version

    size = source_head["ContentLength"]
    logger.info(
        "Promoting s3://%s/%s (%d bytes) to s3://%s/%s",
        BUCKET,
        source_key,
        size,
        BUCKET,
        destination_key,
    )
    if size <= COPY_OBJECT_LIMIT:
        copy_small_object(
            copy_source, destination_key, source_head, metadata
        )
    else:
        copy_large_object(
            copy_source, destination_key, source_head, metadata, size
        )

    publish_latency_metric(record)
    return "promoted"


def archive_key_parts(source_key):
    if not source_key.startswith(ARCHIVE_PREFIX):
        raise ValueError(f"Object is outside {ARCHIVE_PREFIX}: {source_key}")

    remainder = source_key[len(ARCHIVE_PREFIX) :]
    parts = remainder.split("/", 1)
    if len(parts) != 2 or not parts[1]:
        raise ValueError(f"Archive object has no relative path: {source_key}")

    source_date, relative_key = parts
    datetime.strptime(source_date, "%Y-%m-%d")
    return source_date, relative_key


def destination_is_newer(destination_key, source_date, sequencer):
    try:
        destination = s3.head_object(Bucket=BUCKET, Key=destination_key)
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") in {
            "404",
            "NoSuchKey",
            "NotFound",
        }:
            return False
        raise

    metadata = destination.get("Metadata", {})
    destination_date = metadata.get("dap-source-date")
    if not destination_date:
        return False
    if destination_date > source_date:
        return True
    if destination_date < source_date:
        return False

    destination_sequencer = metadata.get("dap-source-sequencer", "0")
    width = max(len(destination_sequencer), len(sequencer))
    return destination_sequencer.zfill(width) >= sequencer.zfill(width)


def copy_small_object(copy_source, destination_key, source_head, metadata):
    arguments = copy_properties(source_head, metadata)
    s3.copy_object(
        Bucket=BUCKET,
        Key=destination_key,
        CopySource=copy_source,
        MetadataDirective="REPLACE",
        TaggingDirective="COPY",
        **arguments,
    )


def copy_large_object(
    copy_source, destination_key, source_head, metadata, size
):
    arguments = copy_properties(source_head, metadata)
    upload = s3.create_multipart_upload(
        Bucket=BUCKET,
        Key=destination_key,
        **arguments,
    )
    upload_id = upload["UploadId"]
    try:
        part_size = max(
            DEFAULT_PART_SIZE,
            math.ceil(size / MAXIMUM_PARTS),
            MINIMUM_PART_SIZE,
        )
        parts = []
        for part_number, start in enumerate(range(0, size, part_size), 1):
            end = min(start + part_size, size) - 1
            response = s3.upload_part_copy(
                Bucket=BUCKET,
                Key=destination_key,
                UploadId=upload_id,
                PartNumber=part_number,
                CopySource=copy_source,
                CopySourceRange=f"bytes={start}-{end}",
            )
            parts.append(
                {
                    "ETag": response["CopyPartResult"]["ETag"],
                    "PartNumber": part_number,
                }
            )

        s3.complete_multipart_upload(
            Bucket=BUCKET,
            Key=destination_key,
            UploadId=upload_id,
            MultipartUpload={"Parts": parts},
        )
    except Exception:
        s3.abort_multipart_upload(
            Bucket=BUCKET,
            Key=destination_key,
            UploadId=upload_id,
        )
        raise


def copy_properties(source_head, metadata):
    arguments = {
        "Metadata": metadata,
        "ServerSideEncryption": "AES256",
    }
    property_names = (
        "CacheControl",
        "ContentDisposition",
        "ContentEncoding",
        "ContentLanguage",
        "ContentType",
        "Expires",
    )
    for name in property_names:
        if source_head.get(name) is not None:
            arguments[name] = source_head[name]
    return arguments


def publish_latency_metric(record):
    event_time = datetime.fromisoformat(record["eventTime"].replace("Z", "+00:00"))
    latency = max(0, (datetime.now(timezone.utc) - event_time).total_seconds())
    cloudwatch.put_metric_data(
        Namespace="Delta/DAPExport",
        MetricData=[
            {
                "MetricName": "PromotionLatencySeconds",
                "Value": latency,
                "Unit": "Seconds",
            }
        ],
    )
