#!/bin/bash

# Change current directory to the script's folder.
cd `dirname ${BASH_SOURCE[0]}`

# Pull and display the latest version.
docker run -ti --rm --pull=always -v /var/run/docker.sock:/var/run/docker.sock -v ~/.cache:/root/.cache aquasec/trivy --version

projects=("myproject-simple" "myproject-level2")

# Run the trivy scan on each project.
# No issues found in myproject-level2 because of 2nd-level dependencies are not scanned.
for project in "${projects[@]}"
do
    cd ${project}
    echo ""
    echo ""
    echo "===================================================="
    echo "trivy on project ${project}"
    echo "===================================================="
    # Run the trivy scan on the local filesystem where the script is run.
    # Share local ~/.m2
    docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v ~/.cache:/root/.cache \
        -v ${PWD}:/root/myproject \
        -v ~/.m2:/root/.m2 \
        --env NO_COLOR=1 \
        --network=host aquasec/trivy fs --debug --timeout 30m /root/myproject
    cd - >> /dev/null
done

# Test workaround on project myproject-level2
project="myproject-level2"
echo ""
echo ""
echo "===================================================="
echo "Test workaround on project ${project}"
echo "===================================================="
cd myproject-level2

# Build the effective pom to flatten all dependencies
mvn -B help:effective-pom -Doutput=pom_flatten.xml -Dverbose=true

# Backup the original pom.xml
mv pom.xml pom_origin.xml

# Use the flatten pom.xml
mv pom_flatten.xml pom.xml

# Run the trivy scan
# As 2nd-level dependencies are now in the 1st-level, they are scanned and vulnerabilities are found.
echo ""
echo "----------------------------------------------------"
echo "trivy on workaround ${project}"
docker run --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v ~/.cache:/root/.cache \
     -v ${PWD}:/root/myproject \
     -v ~/.m2:/root/.m2 \
     --network=host aquasec/trivy fs --no-progress --debug --timeout 30m /root/myproject

# Restore the original pom.xml
mv pom_origin.xml pom.xml

exit 0





