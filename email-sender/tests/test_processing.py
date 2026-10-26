import json
from io import BytesIO
from unittest.mock import MagicMock

import pytest

from email_sender import processing as p
from email_sender import lambda_handler as handler


def test_log_backend_never_calls_notify_and_omits_identifiers(monkeypatch, record, caplog):
    client = MagicMock(side_effect=AssertionError("Notify must not be used"))
    monkeypatch.setattr(p, "notify_client", client)
    p.process_record(record)
    client.assert_not_called()
    entries = [json.loads(r.message) for r in caplog.records if r.name == "email_sender"]
    assert entries[0]["event"] == "email_would_send"
    assert set(entries[0]) == {"event", "application", "notification_type", "attempt", "duration_ms"}
    for value in ("private", "Private Name", "search-123", "message-1", "receipt-1"):
        assert value not in caplog.text


def test_log_failure_does_not_leak_untrusted_labels(record, caplog):
    message = json.loads(record["body"])
    message["application"] = "private@example.test"
    assert handler.handle_batch([{**record, "body": json.dumps(message)}])["batchItemFailures"]
    for value in ("private", "search-123", "message-1", "receipt-1"):
        assert value not in caplog.text


def test_notify_mapping_and_reference(monkeypatch, record, caplog):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.setenv("NOTIFY_TEMPLATE_IDS", '{"delta/large_download_ready":"production-template"}')
    client = MagicMock()
    client.send_email_notification.return_value = {"id": "notify-123"}
    monkeypatch.setattr(p, "notify_client", lambda: client)
    p.process_record(record)
    args = client.send_email_notification.call_args.kwargs
    assert args["template_id"] == "production-template"
    assert args["reference"] == "delta:large_download_ready:search-123"
    assert "notify-123" in caplog.text
    assert "private" not in caplog.text.lower()


def test_notify_prepares_supported_attachments_and_skips_invalid(monkeypatch, record, caplog):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.setenv("ATTACHMENT_BUCKET", "email-attachments")
    monkeypatch.setenv("NOTIFY_TEMPLATE_IDS", '{"delta/collection_instance_release":"release-template"}')
    message = json.loads(record["body"])
    message.update({
        "notification_type": "collection_instance_release",
        "attachments": [
            {"url": "s3://email-attachments/notifications/one", "filename": "guide.pdf"},
            {"url": "s3://email-attachments/notifications/two", "filename": "unsafe.exe"},
            {"url": "s3://email-attachments/notifications/three", "filename": "large.csv"},
        ],
        "personalisation": {
            "first_name": "Private Name",
            "collection_name": "Test collection",
            "start_date": "26 October 2026",
            "deadline": "30 November 2026 5:00pm",
            "collection_url": "https://example.test/form",
        },
    })
    client = MagicMock()
    client.send_email_notification.return_value = {"id": "notify-123"}
    s3 = MagicMock()
    s3.get_object.side_effect = [
        {"ContentLength": 4, "Body": BytesIO(b"%PDF")},
        {"ContentLength": p.MAX_ATTACHMENT_BYTES + 1, "Body": BytesIO()},
    ]
    monkeypatch.setattr(p, "notify_client", lambda: client)
    monkeypatch.setattr(p, "attachment_client", lambda: s3)
    monkeypatch.setattr(p, "prepare_notify_upload",
                        lambda body, filename: {"filename": filename, "content": body.read()})

    p.process_record({**record, "body": json.dumps(message)})

    personalisation = client.send_email_notification.call_args.kwargs["personalisation"]
    assert personalisation["attachment_1"] == {"filename": "guide.pdf", "content": b"%PDF"}
    assert personalisation["attachment_2"] == ""
    assert personalisation["attachment_3"] == ""
    assert set(personalisation) == {
        "attachment_1", "attachment_2", "attachment_3", "collection_name",
        "collection_url", "deadline", "first_name", "start_date",
    }
    assert s3.get_object.call_count == 2
    assert s3.delete_objects.call_args.kwargs["Delete"]["Objects"] == [
        {"Key": "notifications/one"},
        {"Key": "notifications/two"},
        {"Key": "notifications/three"},
    ]
    assert "attachment_skipped" in caplog.text
    for value in ("guide.pdf", "unsafe.exe", "large.csv", "email-attachments"):
        assert value not in caplog.text


def test_notify_sends_cpm_approved_transactions_pdf(monkeypatch, record):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.setenv("ATTACHMENT_BUCKET", "email-attachments")
    monkeypatch.setenv(
        "NOTIFY_TEMPLATE_IDS",
        '{"cpm/approved_transactions_summary":"summary-template"}',
    )
    message = json.loads(record["body"])
    message.update({
        "application": "cpm",
        "notification_type": "approved_transactions_summary",
        "personalisation": {},
        "attachments": [{
            "url": "s3://email-attachments/notifications/report",
            "filename": "approved-transactions-summary.pdf",
        }],
    })
    client = MagicMock()
    client.send_email_notification.return_value = {"id": "notify-123"}
    s3 = MagicMock()
    s3.get_object.return_value = {
        "ContentLength": 4,
        "Body": BytesIO(b"%PDF"),
    }
    monkeypatch.setattr(p, "notify_client", lambda: client)
    monkeypatch.setattr(p, "attachment_client", lambda: s3)
    monkeypatch.setattr(
        p,
        "prepare_notify_upload",
        lambda body, filename: {"filename": filename, "content": body.read()},
    )

    p.process_record({**record, "body": json.dumps(message)})

    args = client.send_email_notification.call_args.kwargs
    assert args["template_id"] == "summary-template"
    assert args["personalisation"] == {
        "attachment_1": {
            "filename": "approved-transactions-summary.pdf",
            "content": b"%PDF",
        },
    }
    s3.delete_objects.assert_called_once()


def test_cpm_approved_transactions_rejects_oversized_pdf(monkeypatch, record):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.setenv("ATTACHMENT_BUCKET", "email-attachments")
    monkeypatch.setenv(
        "NOTIFY_TEMPLATE_IDS",
        '{"cpm/approved_transactions_summary":"summary-template"}',
    )
    message = json.loads(record["body"])
    message.update({
        "application": "cpm",
        "notification_type": "approved_transactions_summary",
        "personalisation": {},
        "attachments": [{
            "url": "s3://email-attachments/notifications/report",
            "filename": "approved-transactions-summary.pdf",
        }],
    })
    s3 = MagicMock()
    s3.get_object.return_value = {
        "ContentLength": p.MAX_ATTACHMENT_BYTES,
        "Body": BytesIO(),
    }
    monkeypatch.setattr(p, "attachment_client", lambda: s3)

    with pytest.raises(p.SendFailure, match="invalid_attachments"):
        p.process_record({**record, "body": json.dumps(message)})


@pytest.mark.parametrize("attachments", [[], [
    {
        "url": "s3://email-attachments/notifications/report",
        "filename": "approved-transactions-summary.csv",
    },
]])
def test_cpm_approved_transactions_requires_one_pdf(record, attachments):
    message = json.loads(record["body"])
    message.update({
        "application": "cpm",
        "notification_type": "approved_transactions_summary",
        "personalisation": {},
        "attachments": attachments,
    })

    with pytest.raises(p.SendFailure, match="invalid_attachments"):
        p.validate(message)


def test_provider_error_is_sanitised_and_only_failed_record_retried(monkeypatch, record, caplog):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.setenv("NOTIFY_TEMPLATE_IDS", '{"delta/large_download_ready":"production-template"}')
    class ProviderError(Exception):
        status_code = 429
    client = MagicMock()
    client.send_email_notification.side_effect = [ProviderError("private@example.test APIKEY secret"), {"id": "ok"}]
    monkeypatch.setattr(p, "notify_client", lambda: client)
    second = {**record, "messageId": "message-2"}
    retry = MagicMock()
    result = handler.handle_batch([record, second], retry)
    assert result == {"batchItemFailures": [{"itemIdentifier": "message-1"}]}
    assert retry.call_args.args[0] == "receipt-1"
    assert retry.call_args.args[1] >= 600
    assert "rate_limited" in caplog.text
    for secret in ("private", "APIKEY", "secret"):
        assert secret not in caplog.text


@pytest.mark.parametrize("body", ["not-json", "[]", '{"schema_version":true}', '{"schema_version":2}'])
def test_invalid_messages_are_failed_without_body_logging(record, body, caplog):
    result = handler.handle_batch([{**record, "body": body}])
    assert result["batchItemFailures"] == [{"itemIdentifier": "message-1"}]
    assert body not in caplog.text


def test_unknown_backend_never_falls_back(monkeypatch, record):
    monkeypatch.setenv("EMAIL_BACKEND", "unknown")
    with pytest.raises(p.SendFailure, match="invalid_backend_configuration"):
        p.process_record(record)


def test_missing_notify_template_is_a_failure(monkeypatch, record):
    monkeypatch.setenv("EMAIL_BACKEND", "notify")
    monkeypatch.delenv("NOTIFY_TEMPLATE_IDS", raising=False)
    with pytest.raises(p.SendFailure, match="missing_template_configuration"):
        p.process_record(record)


def test_visibility_failure_does_not_acknowledge(record, monkeypatch):
    def fail(_):
        raise p.SendFailure("connection_error")
    monkeypatch.setattr(handler, "process_record", fail)
    retry = MagicMock(side_effect=RuntimeError("queue down"))
    assert handler.handle_batch([record], retry)["batchItemFailures"]


def test_backoff_is_bounded():
    assert 30 <= handler.retry_delay(1) <= 40
    assert 300 <= handler.retry_delay(1, 429) <= 310
    assert handler.retry_delay(100, 429) <= 3610
