#!/bin/bash

# Script to download ALB logs from S3

DLUHC_ENV=staging
APP=cpm
ACCOUNT_ID=486283582667
# The last part of the S3 prefix which is the date in yyyy/MM/dd/ format
# Can specify a day or use e.g. "2023/06/" to download all logs for that month
S3_FOLDER_DATE="2023/06/20/"

FOLDER="${APP}-${DLUHC_ENV}-alb-logs"

mkdir -p "${APP}-alb-logs"

aws s3 cp --recursive "s3://${DLUHC_ENV}-${APP}-alb-access-logs/${DLUHC_ENV}-${APP}-alb/AWSLogs/${ACCOUNT_ID}/elasticloadbalancing/eu-west-1/${S3_FOLDER_DATE}" "${FOLDER}/"

find "${FOLDER}/" -type f -name '*.gz' | xargs gunzip

# Optionally combine them
# rm -f "${APP}-${DLUHC_ENV}-alb-combined.log"
# find "${FOLDER}/" -type f -name '*.log' -exec cat {} \; > "${APP}-${DLUHC_ENV}-alb-combined.log"
