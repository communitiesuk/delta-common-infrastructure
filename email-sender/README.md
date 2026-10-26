# Shared email sender

Delta and CPM publish version 1 notification requests.
The shared processor runs behind Lambda in AWS. Local MarkLogic logs directly.
Additional types can be added to the processor's notification registry.

| Environment | Backend | Outcome |
|---|---|---|
| Local | XQuery `email-transport=log` | Sanitised `email_would_send` event; no queue/network |
| Test | `log` | Sanitised log in Lambda; no outbound email |
| Staging | `notify` | Submit to GOV.UK Notify using staging configuration |
| Production | `notify` | Submit to GOV.UK Notify |

MailHog remains separate for auth/account-creation emails. This service has no
SMTP backend, content renderer, template snapshots or export tooling. All email
wording is managed in Notify. Local/test require no template IDs or Notify keys.

## Request contract

```json
{
  "schema_version": 1,
  "application": "delta",
  "notification_type": "large_download_ready",
  "correlation_id": "SEARCH_ID",
  "email_address": "recipient@example.test",
  "personalisation": {
    "first_name": "Alex",
    "download_url": "https://delta.example/submissions/data-store/download-zip/SEARCH_ID?dataSource=master",
    "download_type": "CSV"
  }
}
```

Collection-instance-release requests add up to three attachment descriptors:

```json
{
  "notification_type": "collection_instance_release",
  "attachments": [
    {
      "url": "s3://ATTACHMENT_BUCKET/notifications/OPAQUE_ID",
      "filename": "guidance.pdf"
    }
  ]
}
```

Their scalar personalisation fields are `collection_name`, `collection_url`,
`deadline`, `first_name`, and `start_date`.

CPM approved-transactions-summary requests contain one PDF attachment and no
scalar personalisation. The Notify template must define `attachment_1`.

MarkLogic writes each recipient's filtered attachments before publishing the
request. Lambda accepts only its configured private bucket. It skips unsupported
types and files of 2MB or more for collection emails. The CPM report fails rather
than sending without its required PDF. Lambda uploads valid files using
`prepare_upload`, and deletes all staged objects after Notify accepts the email.
The bucket lifecycle expires remaining objects after one day. Notify templates
must define `attachment_1`, `attachment_2`, and `attachment_3` placeholders.

In AWS, the queue request carries the data needed by Notify. Test validates and
acknowledges it without sending email; staging and production submit to Notify.
Locally, the XQuery publisher logs directly before any queue access or AWS
credential retrieval; no additional containers, Python worker or sibling checkout
are required. `email-transport=log` is the local default; AWS deployment property
files explicitly set `email-transport=sqs`. Local queue settings are empty.
Restrict queue/DLQ access because the original payload contains personal data.
Only registered application/type pairs are accepted. Backend and template
selection are trusted deployment configuration, never controlled by a message.

## Configuration and rollout

1. Build the Python 3.12 x86_64 package using Docker:
   `python3 email-sender/build.py` from the repository root. The output is
   `email-sender/dist/email-sender.zip`. Plan workflows also build this package.
2. In `terraform/test`, enable `email_sender_enabled=true`. Test uses `log` and
   needs no Notify configuration or MailHog/VPC connectivity.
3. Apply common infrastructure before deploying Delta's publishing changes.
   Its `email_queue_url` output must match Delta's `email-queue-url` setting.
   Verify IMDSv2 credentials and AWS4 signing on the installed MarkLogic build.
4. In staging and production, also set `email_notify_api_key_secret_arn` and
   `email_notify_template_ids`, for example
   `{ "delta/large_download_ready" = "YOUR_TEMPLATE_ID" }`.
   Store the raw Notify API key as SecretString in Secrets Manager, not in
   Terraform variables/state. The secret should use the default Secrets Manager
   key; a custom KMS key additionally requires scoped decrypt permission.
5. Configure each environment's Notify template with `((first_name))`,
   `((download_url))`, and `((download_type))`. Manage the subject, service desk
   details and all other wording there. Verify its download link before rollout.
   Add a separate `delta/collection_instance_release` template mapping before
   setting Delta's `collection-instance-release-notify-enabled=true`. That
   template must include the release personalisation fields documented in the
   request contract plus the three attachment placeholders.

The environment modules are disabled until explicitly enabled. Staging and
production require their own secret ARN and template mapping before activation. Keep the service enabled in the environment configuration/tfvars
once rolled out. No resources are applied by the build/test commands.

The main deployment workflow saves the Lambda ZIP with the Terraform plan and
restores that same artifact for apply. No content export step is needed.

## Operations and privacy

Lambda/SQS maximum concurrency is two, batch size one. This limits concurrent
sends, not requests per second. Confirm Notify's allowance before increasing
volume. Notify success means API acceptance, not delivery.

Source visibility is 180 seconds (six times Lambda's 30-second timeout).
Failures use exponential visibility backoff with jitter: initially 30 seconds,
or 300 seconds for HTTP 429, capped at approximately one hour. Five failed
receives lead to the DLQ. Source retention is four days; DLQ retention is fourteen
days. Daily quota failures require investigation rather than immediate replay.

Lambda log-only success events contain **only** event, registered application/type,
attempt count and duration. The direct local XQuery event contains only the event
and registered application/type. They omit recipients, names, URLs, message bodies,
credentials, correlation IDs and queue message IDs. Invalid requests likewise
log only sanitised error category/status and operational counts. Neither
Notify nor Secrets Manager is called in log mode. MarkLogic's publisher email
events omit identifying IDs too; existing general export diagnostics are outside
this email logger's scope.

Production logs retain tracing IDs and the Notify notification ID, while still
excluding personalisation and provider exception text. Logs retain thirty days.
Alarms cover DLQ entries, source age above fifteen minutes and Lambda crashes.

Investigate dead-letter requests under restricted access, fix the cause, then
redrive to the source queue. Replays/timeouts may cause duplicates. Publishing
failures surface as `email_publish_failed`; explicitly rerun the ready-email task
after recovery. There is no outbox, sent-state lookup, delivery callback or SMTP
fallback. Existing notification types outside this pilot are unchanged.

## Checks

```bash
cd email-sender
python3 -m venv .venv
.venv/bin/pip install -r requirements.lock pytest==9.1.1
.venv/bin/python -m pytest tests -q
```

MarkLogic tests in Delta cover the local logging branch and ensure that event
fields exclude personalisation and identifying IDs. A running MarkLogic instance
is required to execute those tests. Existing auth emails, MailHog configuration
and account-creation Playwright tests are unchanged.
