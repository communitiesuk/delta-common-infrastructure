runner_version="2.337.0"
runner_sha256="70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613"
file_name="actions-runner-linux-x64-$runner_version.tar.gz"
runner_url="https://github.com/actions/runner/releases/download/v$runner_version/$file_name"

echo "Setting up GH Actions runner tool cache"
# Required for various */setup-* actions to work, location is also know by various environment
# variable names in the actions/runner software : RUNNER_TOOL_CACHE / RUNNER_TOOLSDIRECTORY / AGENT_TOOLSDIRECTORY
# Warning, not all setup actions support the env vars and so this specific path must be created regardless
mkdir -p /opt/hostedtoolcache

echo "Creating actions-runner directory for the GH Action installation"
cd /opt/
mkdir -p actions-runner && cd actions-runner


echo "Downloading GitHub Actions runner v$runner_version to $file_name"
# Keep in sync with https://github.com/actions/runner/releases (required for modern actions, e.g. setup-java@v5)
curl --fail --show-error --location --output "$file_name" "$runner_url"

echo "Verifying GitHub Actions runner checksum"
echo "$runner_sha256  $file_name" | sha256sum --check --strict

echo "Un-tar action runner"
tar xzf "./$file_name"
echo "Delete tar file"
rm -f "$file_name"

yum install -y libicu

echo "Set file ownership of action runner"
chown -R "$user_name":"$user_name" .
chown -R "$user_name":"$user_name" /opt/hostedtoolcache
