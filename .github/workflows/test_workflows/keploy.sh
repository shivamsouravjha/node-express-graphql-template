curl --silent -O -L https://keploy.io/ent/install.sh 


sudo docker compose build
export KEPLOY_API_KEY=Iba1IAlh+GKnXPzYeA==
curl --silent -o keployE --location "https://keploy-enterprise.s3.us-west-2.amazonaws.com/releases/latest/enterprise_linux_amd64"
sudo chmod a+x keployE && sudo mkdir -p /usr/local/bin && sudo mv keployE /usr/local/bin


# curl --silent --location "https://github.com/keploy/keploy/releases/latest/download/keploy_linux_amd64.tar.gz" | tar xz -C /tmp

# sudo mkdir -p /usr/local/bin && sudo mv /tmp/keploy /usr/local/bin/keploybin
# Clone the specific branch from the Keploy repository
# git clone --branch shivam/clifix https://github.com/keploy/keploy.git /tmp/keploy_repo
# cd /tmp/keploy_repo

# # # Build the binary
# go build  -tags=viper_bind_struct -o keploybin .
# # # Move the binary to /usr/local/bin
# sudo mkdir -p /usr/local/bin && sudo mv keploybin /usr/local/bin/keploybin

# sudo docker build -t ghcr.io/keploy/keploy:v2-dev .

# cd -


# Run the Keploy installation script

# Install the required node dependencies
# yarn install

export ENVIRONMENT_NAME=local
# Build the project locally
echo "Project built successfully"

# Start keploy in test mode
sudo -E env PATH="$PATH" /usr/local/bin/keployE test -c "sudo docker compose --env-file .env.local up" --containerName "custom_app" --delay 250 --buildDelay 150 --apiTimeout 300 --generateGithubActions=false --coverage=false
echo "Keploy started in test mode"

# Initialize a flag to track the overall test status
all_passed=true

# Loop through test sets 1 to 4
for i in {1..4}
do
    # Define the report file for each test set
    report_file="./keploy/reports/test-run-0/test-set-$i-report.yaml"

    # Extract the test status
    test_status=$(grep 'status:' "$report_file" | head -n 1 | awk '{print $2}')

    # Print the status for debugging
    echo "Test status for test-set-$i: $test_status"

    # Check if any test set did not pass
    if [ "$test_status" != "PASSED" ]; then
        all_passed=false
        echo "Test-set-$i did not pass."
        break # Exit the loop early as all tests need to pass
    fi
done

# Check the overall test status and exit accordingly
if [ "$all_passed" = true ]; then
    echo "All tests passed"
    exit 0
else
    exit 1
fi