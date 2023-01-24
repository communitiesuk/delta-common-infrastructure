# Swagger UI

## Current State

The API is served via a 'docs' app which provides static files for access to the Swagger UI and otherwise forwards requests to MarkLogic.

## Aims

Remove the need to patch and maintain a server and deploy a Java app just to serve static files.

## Design

Host the static files in an AWS S3 bucket rather than in a dedicated app. Handle request forwarding via CloudFront and load balancer rules.

This will reduce maintenance requirements and marginally improve performance.
