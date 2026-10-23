import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


@pytest.fixture
def record():
    return {"messageId": "message-1", "receiptHandle": "receipt-1",
            "attributes": {"ApproximateReceiveCount": "2"},
            "body": json.dumps({"schema_version": 1, "application": "delta", "notification_type": "large_download_ready",
                                "correlation_id": "search-123", "email_address": "private@example.test",
                                "personalisation": {"first_name": "Private Name", "download_type": "CSV", "extra": "yes",
                                                    "download_url": "https://example.test/download?secret=private"}})}


@pytest.fixture(autouse=True)
def backend(monkeypatch):
    monkeypatch.setenv("EMAIL_BACKEND", "log")
