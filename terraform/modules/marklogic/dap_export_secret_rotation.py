import json
import os

import boto3

iam = boto3.client("iam")
secretsmanager = boto3.client("secretsmanager")


def lambda_handler(event, context):
    arn = event["SecretId"]
    token = event["ClientRequestToken"]
    step = event["Step"]

    metadata = secretsmanager.describe_secret(SecretId=arn)
    if not metadata.get("RotationEnabled"):
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    version_stages = metadata["VersionIdsToStages"].get(token)
    if version_stages is None:
        raise ValueError(f"Secret version {token} has no stage for {arn}")
    if "AWSCURRENT" in version_stages:
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


def create_secret(arn, token):
    try:
        secretsmanager.get_secret_value(
            SecretId=arn,
            VersionId=token,
            VersionStage="AWSPENDING",
        )
        return
    except secretsmanager.exceptions.ResourceNotFoundException:
        pass

    user_name = os.environ["IAM_USER_NAME"]
    current_secret = get_secret_json(arn, "AWSCURRENT")
    current_access_key_id = current_secret.get("access_key_id")

    make_space_for_new_key(user_name, current_access_key_id)
    new_key = iam.create_access_key(UserName=user_name)["AccessKey"]

    pending_secret = {
        "access_key_id": new_key["AccessKeyId"],
        "secret_access_key": new_key["SecretAccessKey"],
        "region": os.environ["AWS_REGION_NAME"],
        "bucket": os.environ["DAP_EXPORT_BUCKET"],
        "prefix": os.environ["DAP_EXPORT_PREFIX"],
    }

    secretsmanager.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(pending_secret),
        VersionStages=["AWSPENDING"],
    )


def test_secret(arn, token):
    pending_secret = get_secret_json(arn, "AWSPENDING", token)
    access_key_id = pending_secret["access_key_id"]
    user_name = os.environ["IAM_USER_NAME"]

    keys = iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"]
    matching_keys = [key for key in keys if key["AccessKeyId"] == access_key_id]
    if len(matching_keys) != 1:
        raise ValueError("Pending access key was not found on the IAM user")
    if matching_keys[0]["Status"] != "Active":
        raise ValueError("Pending access key is not active")


def finish_secret(arn, token, metadata):
    current_version = None
    for version, stages in metadata["VersionIdsToStages"].items():
        if "AWSCURRENT" in stages:
            current_version = version
            break

    if current_version == token:
        return

    secretsmanager.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )

    old_access_key_id = get_secret_json(arn, "AWSPREVIOUS").get("access_key_id")
    if old_access_key_id:
        delete_access_key_if_present(os.environ["IAM_USER_NAME"], old_access_key_id)


def get_secret_json(arn, stage, version_id=None):
    args = {"SecretId": arn, "VersionStage": stage}
    if version_id:
        args["VersionId"] = version_id
    value = secretsmanager.get_secret_value(**args)
    return json.loads(value["SecretString"])


def make_space_for_new_key(user_name, current_access_key_id):
    keys = sorted(
        iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"],
        key=lambda key: key["CreateDate"],
    )
    if len(keys) < 2:
        return

    removable_keys = [
        key for key in keys if key["AccessKeyId"] != current_access_key_id
    ]
    if not removable_keys:
        raise ValueError("Cannot create a new access key because both existing keys are current")

    delete_access_key_if_present(user_name, removable_keys[0]["AccessKeyId"])


def delete_access_key_if_present(user_name, access_key_id):
    keys = iam.list_access_keys(UserName=user_name)["AccessKeyMetadata"]
    if any(key["AccessKeyId"] == access_key_id for key in keys):
        iam.delete_access_key(UserName=user_name, AccessKeyId=access_key_id)
