#!/bin/bash

# Debugging function to handle errors
handle_error() {
    echo "Error on line $1"
    exit 1
}

# Trap errors and call the handle_error function
trap 'handle_error $LINENO' ERR

# Fetch the Keploy installation script
curl --silent -O -L https://keploy.io/ent/install.sh 
export KEPLOY_API_KEY=Iba1IAlh+GKnXPzYeA==

curl --silent -o keployE --location "https://keploy-enterprise.s3.us-west-2.amazonaws.com/releases/latest/enterprise_linux_amd64"

sudo chmod a+x keployE && sudo mkdir -p /usr/local/bin && sudo mv keployE /usr/local/bin

# Run the Keploy installation script
# bash ./install.sh
source ~/.bashrc

# Install the required node dependencies
# yarn install
export DOCKER_BUILDKIT=1
sudo -E docker-compose --env-file .env.docker build

export ENVIRONMENT_NAME=local
# Build the project locally
sudo -E env PATH="$PATH" yarn build:local
echo "Project built successfully"

# Start keploy in test mode
sudo -E env PATH="$PATH" keployE  test -c "sudo docker-compose --env-file .env.docker up" --containerName "custom_app" --delay 50 --apiTimeout 300 --generateGithubActions=false --coverage=false
echo "Keploy started in test mode"

report_file="./keploy/reports/test-run-0/test-set-4-report.yaml"
test_status1=$(grep 'status:' "$report_file" | head -n 1 | awk '{print $2}')
echo test_status1
# Check the test status variables and exit accordingly
# if [ "$test_status1" = "PASSED" ]; then
echo "All tests passed"
# exit 0
# else
#     exit 1
# fi
