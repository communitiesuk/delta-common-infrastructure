"""Process notification requests without logging recipient data or provider bodies."""
import json
import logging
import os
import time

LOG = logging.getLogger("email_sender")
LOG.setLevel(logging.INFO)
NOTIFICATION_TYPES = {("delta", "large_download_ready")}


class SendFailure(Exception):
    def __init__(self, category, status=None):
        super().__init__(category)
        self.category = category
        self.status = status


def event(name, **fields):
    LOG.info(json.dumps({"event": name, **fields}, separators=(",", ":")))


def validate(message):
    if not isinstance(message, dict) or type(message.get("schema_version")) is not int or message["schema_version"] != 1:
        raise SendFailure("invalid_message")
    for key in ("application", "notification_type", "correlation_id", "email_address"):
        value = message.get(key)
        if not isinstance(value, str) or not value or len(value) > 320 or any(ord(c) < 32 for c in value):
            raise SendFailure("invalid_message")
    if "@" not in message["email_address"]:
        raise SendFailure("invalid_recipient")
    values = message.get("personalisation")
    if not isinstance(values, dict) or any(not isinstance(k, str) or not isinstance(v, (str, int, float, bool)) for k, v in values.items()):
        raise SendFailure("invalid_personalisation")
    if message["application"] == "delta" and message["notification_type"] == "large_download_ready":
        if not all(isinstance(values.get(k), str) and values[k] for k in ("first_name", "download_url", "download_type")):
            raise SendFailure("invalid_personalisation")
        if not values["download_url"].startswith(("https://", "http://")):
            raise SendFailure("invalid_download_url")


_notify = None
_notify_expires = 0


def notify_client():
    global _notify, _notify_expires
    if _notify is None or time.monotonic() >= _notify_expires:
        import boto3
        from notifications_python_client.notifications import NotificationsAPIClient
        # SecretString is the raw API key, never passed via Terraform state.
        key = boto3.client("secretsmanager").get_secret_value(SecretId=os.environ["NOTIFY_API_KEY_SECRET_ARN"])["SecretString"]
        _notify = NotificationsAPIClient(key)
        _notify_expires = time.monotonic() + 300
    return _notify


def notify_send(message):
    mappings = json.loads(os.environ.get("NOTIFY_TEMPLATE_IDS", "{}"))
    template_id = mappings.get(f"{message['application']}/{message['notification_type']}")
    if not template_id:
        raise SendFailure("missing_template_configuration")
    response = notify_client().send_email_notification(
        email_address=message["email_address"], template_id=template_id,
        personalisation=message["personalisation"],
        reference=f"{message['application']}:{message['notification_type']}:{message['correlation_id']}",
    )
    return response["id"]


def failure_details(error):
    if isinstance(error, SendFailure):
        return error.category, error.status
    status = getattr(error, "status_code", None)
    if status == 429:
        return "rate_limited", status
    if isinstance(error, (TimeoutError, ConnectionError, OSError)):
        return "connection_error", status
    return "processing_error", status if isinstance(status, int) else None


def process_record(record):
    start = time.monotonic()
    backend = os.environ.get("EMAIL_BACKEND", "")
    fields = {"attempt": int(record.get("attributes", {}).get("ApproximateReceiveCount", "1"))}
    # Log-only environments omit even correlation/message IDs. Allowlist all
    # message-derived labels before adding them so malformed input cannot leak.
    if backend == "notify":
        fields["sqs_message_id"] = record["messageId"]
    try:
        message = json.loads(record["body"])
        validate(message)
        if (message["application"], message["notification_type"]) not in NOTIFICATION_TYPES:
            raise SendFailure("unknown_notification_type")
        fields.update({k: message[k] for k in ("application", "notification_type")})
        if backend == "log":
            name = "email_would_send"
        elif backend == "notify":
            fields["correlation_id"] = message["correlation_id"]
            fields["notify_notification_id"] = notify_send(message)
            name = "email_accepted"
        else:
            raise SendFailure("invalid_backend_configuration")
        event(name, **fields, duration_ms=round((time.monotonic() - start) * 1000))
    except Exception as error:
        category, status = failure_details(error)
        event("email_failed", **fields, category=category, http_status=status,
              duration_ms=round((time.monotonic() - start) * 1000))
        # Never propagate provider exception text: it may contain addresses/content.
        raise SendFailure(category, status) from None
