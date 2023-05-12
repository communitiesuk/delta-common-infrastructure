# Sourced from https://github.com/aws-samples/communication-developer-services-reference-architectures/blob/master/cloudformation/ses_bounce_logging_blog.yml
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
log_level = str(os.getenv('log_level')).upper()
event_types = event_type.split(",")

def lambda_handler(event, context):
    global log_level
    if log_level not in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']:
        log_level = 'ERROR'
    logging.getLogger().setLevel(log_level)
    logging.info(event)
    for record in event['Records']:
        logs = record['Sns']['Message']
        logs_data = json.loads(logs)
        notification_type = logs_data['notificationType']
        if not(notification_type in event_types):
            logging.debug("Ignoring event " + notification_type)
            sys.exit()
        log_stream = time.strftime('%Y/%m/%d') + "-" + notification_type
        try:
            client.create_log_stream(logGroupName=log_group, logStreamName=log_stream)
            logging.debug("Created log stream " + log_stream)
        except client.exceptions.ResourceAlreadyExistsException:
            logging.debug("Log stream already exists " + log_stream)
        event_log = {
            'logGroupName': log_group,
            'logStreamName': log_stream,
            'logEvents': [
                {
                    'timestamp': int(round(time.time() * 1000)),
                    'message': logs
                }
            ],
        }
        response = client.put_log_events(**event_log)
        logging.info(response)
