# Swagger UI

## Current State

The API Swagger docs are served via a 'docs' app which provides static files for access to the Swagger UI and forwards requests to `/swagger.json` and `/swagger.yml` to MarkLogic unaltered.
There is also a "Gateway" app which handles the rest of the API requests (to `/rest-api/*`), authenticating them with OAuth, exchanging for a SAML token and then forwarding the requests to MarkLogic.

## Aims

Remove the need to patch and maintain a server and deploy a Java app just to serve static files.

## Design

Host the static files in an AWS S3 bucket rather than in a dedicated app. Add the S3 bucket as a CloudFront origin and routing the `/swagger.json` requests (now `/rest-api/swagger.json`) using load balancer rules.
Keep the API Gateway app, again routing to it with load balancer rules.

This will reduce maintenance requirements and marginally improve performance.
