import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


os.environ.setdefault("DAP_EXPORT_BUCKET", "dap-bucket")
sys.path.insert(0, str(Path(__file__).parent))

try:
    import boto3  # noqa: F401
except ModuleNotFoundError:
    boto3_module = types.ModuleType("boto3")
    boto3_module.client = lambda service: MagicMock()
    sys.modules["boto3"] = boto3_module

    class ClientError(Exception):
        def __init__(self, response, operation_name):
            super().__init__(response["Error"]["Message"])
            self.response = response
            self.operation_name = operation_name

    botocore_module = types.ModuleType("botocore")
    botocore_exceptions_module = types.ModuleType("botocore.exceptions")
    botocore_exceptions_module.ClientError = ClientError
    sys.modules["botocore"] = botocore_module
    sys.modules["botocore.exceptions"] = botocore_exceptions_module

import dap_export_promoter as promoter


class DapExportPromoterTest(unittest.TestCase):
    def setUp(self):
        promoter.s3 = MagicMock()
        promoter.cloudwatch = MagicMock()

    def test_archive_key_maps_to_latest_relative_path(self):
        self.assertEqual(
            ("2026-08-11", "testing-centre/schema/schema.zip"),
            promoter.archive_key_parts(
                "archive/2026-08-11/testing-centre/schema/schema.zip"
            ),
        )

    def test_small_object_is_copied_with_source_version(self):
        missing = promoter.ClientError(
            {"Error": {"Code": "404", "Message": "missing"}},
            "HeadObject",
        )
        promoter.s3.head_object.side_effect = [
            missing,
            {
                "ContentLength": 1024,
                "ContentType": "application/zip",
                "Metadata": {},
            },
        ]

        record = self.record()
        self.assertEqual("promoted", promoter.promote_record(record))

        promoter.s3.copy_object.assert_called_once()
        arguments = promoter.s3.copy_object.call_args.kwargs
        self.assertEqual("latest/forms/export.zip", arguments["Key"])
        self.assertEqual(
            {
                "Bucket": "dap-bucket",
                "Key": "archive/2026-08-11/forms/export.zip",
                "VersionId": "source-version",
            },
            arguments["CopySource"],
        )
        self.assertEqual(
            "2026-08-11", arguments["Metadata"]["dap-source-date"]
        )

    def test_older_archive_event_does_not_replace_latest(self):
        promoter.s3.head_object.return_value = {
            "Metadata": {
                "dap-source-date": "2026-08-12",
                "dap-source-sequencer": "10",
            }
        }

        self.assertEqual("skipped", promoter.promote_record(self.record()))
        promoter.s3.copy_object.assert_not_called()

    def test_failed_multipart_copy_is_aborted(self):
        promoter.s3.create_multipart_upload.return_value = {
            "UploadId": "upload-id"
        }
        promoter.s3.upload_part_copy.side_effect = RuntimeError("copy failed")

        with patch.object(promoter, "DEFAULT_PART_SIZE", 10):
            with self.assertRaisesRegex(RuntimeError, "copy failed"):
                promoter.copy_large_object(
                    {"Bucket": "dap-bucket", "Key": "archive/source"},
                    "latest/destination",
                    {"ContentType": "application/zip"},
                    {},
                    20,
                )

        promoter.s3.abort_multipart_upload.assert_called_once_with(
            Bucket="dap-bucket",
            Key="latest/destination",
            UploadId="upload-id",
        )

    @staticmethod
    def record():
        return {
            "eventTime": "2026-08-11T02:15:00.000Z",
            "s3": {
                "bucket": {"name": "dap-bucket"},
                "object": {
                    "key": "archive/2026-08-11/forms/export.zip",
                    "size": 1024,
                    "versionId": "source-version",
                    "sequencer": "000A",
                },
            },
        }


if __name__ == "__main__":
    unittest.main()
