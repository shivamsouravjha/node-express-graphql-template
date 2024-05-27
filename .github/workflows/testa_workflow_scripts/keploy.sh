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
export KEPLOY_API_KEY=${GITHUB_TOKEN}

curl --silent -o keployE --location "https://keploy-enterprise.s3.us-west-2.amazonaws.com/releases/latest/enterprise_linux_amd64"

sudo chmod a+x keployE && sudo mkdir -p /usr/local/bin && sudo mv keployE /usr/local/bin

# Run the Keploy installation script
# bash ./install.sh
source ~/.bashrc

# Install the required node dependencies
yarn install

export ENVIRONMENT_NAME=local

# Build the project locally
sudo -E env PATH="$PATH" yarn build:local
echo "Project built successfully"

# Start keploy in test mode
sudo -E env PATH="$PATH" keployE test -c 'sh ./scripts/migrate-and-run.sh' --delay 50 --generateGithubActions=false
echo "Keploy started in test mode"

# Optionally, run tests with coverage (commented out)
# sudo -E env PATH=$PATH keploy test -c "npm test" --delay 5 --coverage

# # Run specific test sets
# sudo -E env PATH="$PATH" keployE test -c 'sh ./scripts/migrate-and-run.sh' --delay 50 --testsets test-set-0 --generateGithubActions=false

# # Run final test with apiTimeout and delay
# sudo -E env PATH="$PATH" keployE test -c 'sh ./scripts/migrate-and-run.sh' --apiTimeout 50 --delay 10 --generateGithubActions=false

# Check the test status variables and exit accordingly
if [ "$test_status1" = "PASSED" ]; then
    echo "All tests passed"
    exit 0
else
    echo "Some tests failed"
    exit 1
fi
