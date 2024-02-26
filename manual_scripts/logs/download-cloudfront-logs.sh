#!/bin/bash

set -euxo pipefail

# Script to download CloudFront logs from S3

DLUHC_ENV=staging
APP=cpm
ACCOUNT_ID=486283582667
PREFIX="ECFDSITRIBUTIONIDHERE.2024-02-16-1"

FOLDER="logs/${APP}-${DLUHC_ENV}-cf-logs"

mkdir -p "${FOLDER}"

aws s3 cp --recursive "s3://dluhc-cloudfront-access-logs-${DLUHC_ENV}/${APP}/" "${FOLDER}/" --exclude '*' --include "${PREFIX}*"

find "${FOLDER}/" -type f -name '*.gz' | xargs gunzip

# Optionally combine them
rm -f "logs/${APP}-${DLUHC_ENV}-cf-combined.log"
find "${FOLDER}/" -type f -not -name '*.gz' -exec cat {} \; > "logs/${APP}-${DLUHC_ENV}-cf-combined.log"
