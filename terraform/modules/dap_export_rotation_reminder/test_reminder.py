import threading
import unittest
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from unittest.mock import Mock

from reminder import check_rotation


class AlreadyClaimed(Exception):
    pass


class RotationReminderTest(unittest.TestCase):
    def setUp(self):
        self.secrets = Mock()
        self.dynamodb = Mock()
        self.dynamodb.exceptions.ConditionalCheckFailedException = AlreadyClaimed
        self.ses = Mock()
        self.ses.send_email.return_value = {"MessageId": "message"}
        self.recipients = ["ops@example.com", "support@example.com"]
        self.metadata = {
            "Name": "tf-dap-export-azure-dap-export-staging",
            "RotationEnabled": True,
            "NextRotationDate": datetime(2026, 12, 14, 23, tzinfo=timezone.utc),
            "VersionIdsToStages": {"v1": ["AWSCURRENT"], "v2": ["AWSPENDING"]},
        }
        self.secrets.describe_secret.return_value = self.metadata
        self.claims = set()
        self.lock = threading.Lock()
        self.dynamodb.put_item.side_effect = self.claim

    def claim(self, *, TableName, Item, ConditionExpression):
        self.assertEqual("attribute_not_exists(cycle)", ConditionExpression)
        with self.lock:
            cycle = Item["cycle"]["S"]
            if cycle in self.claims:
                raise AlreadyClaimed
            self.claims.add(cycle)

    def check(self, today=date(2026, 11, 30)):
        check_rotation(
            self.secrets,
            self.dynamodb,
            self.ses,
            secret_arn="secret-arn",
            table="claims",
            from_address="reminders@example.com",
            to_addresses=self.recipients,
            environment="production",
            today=today,
        )

    def test_sends_on_the_14_day_utc_boundary_only(self):
        self.metadata["NextRotationDate"] = self.metadata["NextRotationDate"].astimezone(
            timezone(timedelta(hours=2))
        )
        for today in (date(2026, 11, 29), date(2026, 12, 1), date(2026, 12, 15)):
            self.check(today)
        self.dynamodb.put_item.assert_not_called()
        self.ses.send_email.assert_not_called()

        self.check()
        self.ses.send_email.assert_called_once()
        request = self.ses.send_email.call_args.kwargs
        self.assertEqual({"ToAddresses": self.recipients}, request["Destination"])
        self.assertEqual("reminders@example.com", request["Source"])
        self.assertIn("2026-12-14 (UTC)", request["Message"]["Body"]["Text"]["Data"])
        self.dynamodb.update_item.assert_called_once_with(
            TableName="claims",
            Key={"cycle": {"S": "secret-arn#v1"}},
            UpdateExpression="SET ses_message_id = :id",
            ExpressionAttributeValues={":id": {"S": "message"}},
        )

    def test_concurrent_checks_send_one_reminder(self):
        barrier = threading.Barrier(2)

        def claim_together(**kwargs):
            barrier.wait(timeout=5)
            self.claim(**kwargs)

        self.dynamodb.put_item.side_effect = claim_together
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(self.check) for _ in range(2)]
            for future in futures:
                future.result()
        self.ses.send_email.assert_called_once()

    def test_reschedule_does_not_send_again_until_the_version_changes(self):
        self.check()
        self.check()
        self.metadata["NextRotationDate"] += timedelta(days=1)
        self.check(date(2026, 12, 1))
        self.ses.send_email.assert_called_once()

        self.metadata["VersionIdsToStages"] = {
            "v1": ["AWSPREVIOUS"], "v2": ["AWSCURRENT"]
        }
        self.metadata["NextRotationDate"] += timedelta(days=90)
        self.check(date(2026, 12, 1) + timedelta(days=90))
        self.assertEqual(2, self.ses.send_email.call_count)
        self.assertEqual({"secret-arn#v1", "secret-arn#v2"}, self.claims)

    def test_skips_disabled_rotation_or_missing_date(self):
        self.metadata["RotationEnabled"] = False
        self.check()
        self.metadata["RotationEnabled"] = True
        del self.metadata["NextRotationDate"]
        self.check()
        self.dynamodb.put_item.assert_not_called()
        self.ses.send_email.assert_not_called()

    def test_due_reminder_requires_exactly_one_current_version(self):
        for stages in ({}, {"v1": ["AWSCURRENT"], "v2": ["AWSCURRENT"]}):
            self.metadata["VersionIdsToStages"] = stages
            with self.assertRaisesRegex(ValueError, "exactly one AWSCURRENT"):
                self.check()
        self.dynamodb.put_item.assert_not_called()
        self.ses.send_email.assert_not_called()

    def test_send_failure_retains_the_claim(self):
        self.ses.send_email.side_effect = TimeoutError("SES outcome unknown")
        with self.assertLogs("reminder", "ERROR"):
            with self.assertRaises(TimeoutError):
                self.check()
        self.check()
        self.ses.send_email.assert_called_once()
        self.dynamodb.update_item.assert_not_called()
