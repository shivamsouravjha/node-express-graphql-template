curl --silent -O -L https://keploy.io/ent/install.sh 
echo "Current directory: $(pwd)"

sudo docker compose -f keploy-docker-compose.yml build
export KEPLOY_API_KEY=Iba1IAlh+GKnXPzYeA==
curl --silent -o keployE --location "https://keploy-enterprise.s3.us-west-2.amazonaws.com/releases/latest/enterprise_linux_amd64"
sudo chmod a+x keployE && sudo mkdir -p /usr/local/bin && sudo mv keployE /usr/local/bin


# Build the project locally
echo "Project built successfully"


sudo -E env PATH="$PATH" /usr/local/bin/keployE test -c "sudo docker compose -f keploy-docker-compose.yml up" --containerName "custom_app" --delay 30 --apiTimeout 300 --generateGithubActions=false --coverage=false
echo "Keploy started in test mode"

all_passed=true

# Loop through test sets 1 to 4
# for i in {4}
# do
    # Define the report file for each test set
    report_file="./keploy/reports/test-run-0/test-set-4-report.yaml"

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
# done

# Check the overall test status and exit accordingly
if [ "$all_passed" = true ]; then
    ls -l
    echo $(sudo docker ps -a)
    docker cp custom_app:$(pwd)/.nyc_output $(pwd)/.nyc_output
    echo "Files at the current layer after copying .nyc_output:"
    ls -a
    npx nyc report --reporter=html --reporter=text --temp-dir=./.nyc_output --report-dir=./coverage/summary

    echo "All tests passed"

    echo "All tests passed"
    exit 0
else
    exit 1
fi