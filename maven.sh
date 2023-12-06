#!/bin/bash

# Change current directory to the script's folder.
cd `dirname ${BASH_SOURCE[0]}`

# Install the custom BOM to be usable by project myproject-level2.
mvn install -f myproject-bom/pom.xml

projects=("myproject-simple" "myproject-level2")

for project in "${projects[@]}"
do
    cd ${project}

    # Build project to get dependencies in the local Maven repository.
    echo ""
    echo "mvn package project: ${project}"
    mvn package

    cd - >> /dev/null
done

exit 0
