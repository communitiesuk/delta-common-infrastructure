#!/bin/bash

# Script to download ALB logs from S3

DLUHC_ENV=staging
APP=cpm
ACCOUNT_ID=486283582667

FOLDER="${APP}-${DLUHC_ENV}-alb-logs"

mkdir -p "${APP}-alb-logs"

# Change the date in the S3 URI
aws s3 cp --recursive "s3://${DLUHC_ENV}-${APP}-alb-access-logs/${DLUHC_ENV}-${APP}-alb/AWSLogs/${ACCOUNT_ID}/elasticloadbalancing/eu-west-1/2023/06/" "${FOLDER}/"

find "${FOLDER}/" -type f -name '*.gz' | xargs gunzip

# Optionally combine them
# rm -f "${APP}-${DLUHC_ENV}-alb-combined.log"
# find "${FOLDER}/" -type f -name '*.log' -exec cat {} \; > "${APP}-${DLUHC_ENV}-alb-combined.log"
