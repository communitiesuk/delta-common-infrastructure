import boto3
import time
import json
import sys
import secrets
import os
import logging
client = boto3.client('logs')
log_group = os.getenv("group_name")
event_type = os.getenv("event_type")
def lambda_handler(event, context):
    global log_level
    log_level = str(os.environ.get('LOG_LEVEL')).upper()
    if log_level not in [
                              'DEBUG', 'INFO',
                              'WARNING', 'ERROR',
                              'CRITICAL'
                          ]:
        log_level = 'ERROR'
    logging.getLogger().setLevel(log_level)
    logging.info(event)
    for record in event['Records']:
      logs = record['Sns']['Message']
      logs_data = json.loads(logs)
      notification_type=logs_data['notificationType']
      if(notification_type==event_type):
          LOG_GROUP= log_group
      else:
          sys.exit()
      LOG_STREAM= '{}{}{}'.format(time.strftime('%Y/%m/%d'),'[$LATEST]',secrets.token_hex(16))
      try:
          client.create_log_group(logGroupName=LOG_GROUP)
      except client.exceptions.ResourceAlreadyExistsException:
          pass
      try:
          client.create_log_stream(logGroupName=LOG_GROUP, logStreamName=LOG_STREAM)
      except client.exceptions.ResourceAlreadyExistsException:
          pass
      response = client.describe_log_streams(
          logGroupName=LOG_GROUP,
          logStreamNamePrefix=LOG_STREAM
      )
      event_log = {
          'logGroupName': LOG_GROUP,
          'logStreamName': LOG_STREAM,
          'logEvents': [
              {
                  'timestamp': int(round(time.time() * 1000)),
                  'message': logs
              }
          ],
      }
      if 'uploadSequenceToken' in response['logStreams'][0]:
          event_log.update({'sequenceToken': response['logStreams'][0] ['uploadSequenceToken']})
      response = client.put_log_events(**event_log)
      logging.info(response)
