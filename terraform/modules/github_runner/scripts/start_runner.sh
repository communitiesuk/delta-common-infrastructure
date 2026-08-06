environment=${environment}

chown -R $user_name .

echo "Configure GH Runner as user $user_name"
# Do not write the short-lived registration token to user-data or console logs.
set +x
if ! sudo --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$user_name" -- ./config.sh --unattended --name "delta-$environment" \
  --work "_work" --url https://github.com/communitiesuk/delta-marklogic-deploy \
  --token '${github_token}' --labels "self-hosted,$environment"; then
  set -x
  echo "GitHub Actions runner registration failed"
  exit 1
fi
set -x

## Start the runner
echo "Starting the runner as user $user_name"
echo "Installing the runner as a service"
./svc.sh install "$user_name"
echo "Starting the runner in persistent mode"
./svc.sh start

# Logging must not prevent an otherwise healthy runner from registering or starting.
echo "Enable CloudWatch"
if ! amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:${ssm_parameter_name}"; then
  echo "Warning: CloudWatch agent configuration failed; runner remains registered and running"
fi
