environment=${environment}

echo "Enable Cloudwatch"
amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "ssm:${ssm_parameter_name}"

chown -R $user_name .

echo "Configure GH Runner as user $user_name"
sudo --preserve-env=RUNNER_ALLOW_RUNASROOT -u "$user_name" -- ./config.sh --unattended --name "delta-$environment" \
  --work "_work" --url https://github.com/communitiesuk/delta-marklogic-deploy \
  --token ${github_token} --labels self-hosted,$environment

## Start the runner
echo "Starting the runner as user $user_name"
echo "Installing the runner as a service"
./svc.sh install "$user_name"
echo "Starting the runner in persistent mode"
./svc.sh start
