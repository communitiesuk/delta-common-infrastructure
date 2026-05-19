import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

iam = boto3.client("iam")
secretsmanager = boto3.client("secretsmanager")


def lambda_handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]
    logger.info("Starting rotation step %s for secret %s", step, arn)

    logger.info("Describing secret rotation metadata")
    metadata = secretsmanager.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    version_stages = metadata["VersionIdsToStages"].get(token)
    logger.info("Rotation token has stages: %s", version_stages)
    if version_stages is None:
        raise ValueError(f"Secret version {token} has no stage for {arn}")
    if "AWSCURRENT" in version_stages:
        logger.info("Rotation token is already AWSCURRENT; skipping step %s", step)
        return
    if "AWSPENDING" not in version_stages:
        raise ValueError(f"Secret version {token} is not marked AWSPENDING")

    if step == "createSecret":
        create_secret(arn, token)
    elif step == "setSecret":
        return
    elif step == "testSecret":
        test_secret(arn, token)
    elif step == "finishSecret":
        finish_secret(arn, token, metadata)
    else:
        raise ValueError(f"Unknown rotation step {step}")
    logger.info("Finished rotation step %s for secret %s", step, arn)


def create_secret(arn, token):
    logger.info("Checking whether AWSPENDING secret version already exists")
    try:
        secretsmanager.get_secret_value(
            SecretId=arn,
            VersionId=token,
            VersionStage="AWSPENDING",
        )
        logger.info("AWSPENDING secret version already exists; not creating another key")
        return
    except secretsmanager.exceptions.ResourceNotFoundException:
        logger.info("No AWSPENDING secret version exists yet")
        pass

    user_name = os.environ["IAM_USER_NAME"]
    logger.info("Reading AWSCURRENT secret JSON")
    current_secret = get_secret_json(arn, "AWSCURRENT")
    current_access_key_id = current_secret.get("access_key_id")
    logger.info(
        "Current secret %s an access key id",
        "has" if current_access_key_id else "does not have",
    )

    logger.info("Ensuring IAM user %s has capacity for a new access key", user_name)
    make_space_for_new_key(user_name, current_access_key_id)
    logger.info("Creating new IAM access key for user %s", user_name)
    new_key = iam.create_access_key(UserName=user_name)["AccessKey"]
    logger.info("Created new IAM access key %s", new_key["AccessKeyId"])

    pending_secret = {
        "access_key_id": new_key["AccessKeyId"],
        "secret_access_key": new_key["SecretAccessKey"],
        "region": os.environ["AWS_REGION_NAME"],
        "bucket": os.environ["DAP_EXPORT_BUCKET"],
        "prefix": os.environ["DAP_EXPORT_PREFIX"],
    }

    logger.info("Writing new key metadata to AWSPENDING secret version")
    secretsmanager.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(pending_secret),
        VersionStages=["AWSPENDING"],
    )
    logger.info("Wrote AWSPENDING secret version")


def test_secret(arn, token):
    logger.info("Testing pending secret by checking IAM key status")
    pending_secret = get_secret_json(arn, "AWSPENDING", token)
    access_key_id = pending_secret["access_key_id"]
    user_name = os.environ["IAM_USER_NAME"]

    logger.info("Listing IAM access keys for user %s", user_name)
    keys = iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"]
    matching_keys = [key for key in keys if key["AccessKeyId"] == access_key_id]
    logger.info("Found %d matching pending access keys", len(matching_keys))
    if len(matching_keys) != 1:
        raise ValueError("Pending access key was not found on the IAM user")
    if matching_keys[0]["Status"] != "Active":
        raise ValueError("Pending access key is not active")


def finish_secret(arn, token, metadata):
    logger.info("Finding current secret version before promotion")
    current_version = None
    for version, stages in metadata["VersionIdsToStages"].items():
        if "AWSCURRENT" in stages:
            current_version = version
            break

    if current_version == token:
        logger.info("Pending token is already current; no promotion needed")
        return

    logger.info("Promoting pending version to AWSCURRENT")
    secretsmanager.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )

    logger.info("Reading AWSPREVIOUS secret to identify old key")
    old_access_key_id = get_secret_json(arn, "AWSPREVIOUS").get("access_key_id")
    if old_access_key_id:
        logger.info("Deleting previous IAM access key %s", old_access_key_id)
        delete_access_key_if_present(os.environ["IAM_USER_NAME"], old_access_key_id)
    else:
        logger.info("No previous IAM access key found to delete")


def get_secret_json(arn, stage, version_id=None):
    logger.info("Reading secret stage %s", stage)
    args = {"SecretId": arn, "VersionStage": stage}
    if version_id:
        args["VersionId"] = version_id
    value = secretsmanager.get_secret_value(**args)
    logger.info("Read secret stage %s", stage)
    return json.loads(value["SecretString"])


def make_space_for_new_key(user_name, current_access_key_id):
    logger.info("Listing existing access keys for user %s", user_name)
    keys = sorted(
        iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"],
        key=lambda key: key["CreateDate"],
    )
    logger.info("IAM user %s has %d access keys", user_name, len(keys))
    if len(keys) < 2:
        return

    removable_keys = [
        key for key in keys if key["AccessKeyId"] != current_access_key_id
    ]
    if not removable_keys:
        raise ValueError("Cannot create a new access key because both existing keys are current")

    logger.info("Deleting stale IAM access key %s to make room", removable_keys[0]["AccessKeyId"])
    delete_access_key_if_present(user_name, removable_keys[0]["AccessKeyId"])


def delete_access_key_if_present(user_name, access_key_id):
    logger.info("Checking whether access key %s exists for user %s", access_key_id, user_name)
    keys = iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"]
    if any(key["AccessKeyId"] == access_key_id for key in keys):
        iam.delete_access_key(UserName=user_name, AccessKeyId=access_key_id)
        logger.info("Deleted access key %s", access_key_id)
    else:
        logger.info("Access key %s is already absent", access_key_id)
