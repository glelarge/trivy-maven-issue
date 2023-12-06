# Trivy does not manage 2nd level Maven BOM (or BOM inside another BOM)

This repository is to demonstrate these issues on trivy [#5748](https://github.com/aquasecurity/trivy/discussions/5748) and go-dep-parser [#279](https://github.com/aquasecurity/go-dep-parser/issues/279).

# Context
Context is pretty much common, multiple projects, written in Java, built with Maven, some common jar files used in business applications (web, CLI).

trivy (through its [Docker image](https://hub.docker.com/r/aquasec/trivy), currently v0.48) is used to detect vulnerabilities.

In the Maven terminology, a BOM (Bill Of Materials) is a specific kind of POM, read [Maven documentation](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html#bill-of-materials-bom-poms) for more details.


# Issue

Let's define:
- a **first-level BOM**
  - it is a BOM that references direct dependencies
  - <span style="color: green">==> well detected by trivy</span>
- a **second-level BOM**
  - it is a BOM referenced by another BOM
  - <span style="color: red">==> not detected by trivy</span>


# Reproduction

Tests are using **Camunda 7.17.0** :
- the BOM provided by Camunda 
  - https://mvnrepository.com/artifact/org.camunda.bpm/camunda-bom/7.17.0
- the dependency to **camunda-engine:7.17.0** that comes with vulnerabilities
    - https://mvnrepository.com/artifact/org.camunda.bpm/camunda-engine/7.17.0


This repository contains 3 Maven projects :
- myproject-bom
  - custom BOM
  - set the Camunda BOM in the &lt;dependencyManagement&gt; section
  - requires `mvn install` to be installed in the local Maven repository
- myproject-simple
  - build a simple Jar file
  - set the Camunda BOM in the &lt;dependencyManagement&gt; section
  - <span style="color:green">==> the Camunda BOM is used as first-level BOM</span>
  - import the camunda-engine in the &lt;dependencies&gt; section
- myproject-level2
  - build a simple Jar file
  - set myproject-bom in the &lt;dependencyManagement&gt; section
  - <span style="color:red">==> the Camunda BOM is used as second-level BOM</span>
  - import the camunda-engine in the &lt;dependencies&gt; section

The script `trivy.sh` runs the following operations:
- install locally the custom BOM : `mvn install -f myproject-bom/pom.xml`
- build myproject-simple and myproject-level2 to download dependencies locally :
  - `mvn package -f myproject-simple/pom.xml`
  - `mvn package -f myproject-level2/pom.xml`
- run the trivy tool through its Docker image on both projects myproject-simple and myproject-level2.


# Results

In myproject-simple, vulnerabilities are <span style="color:green">found</span> because Camunda is set as first-level BOM.

In myproject-level2, vulnerabilities are <span style="color:red">not found</span> because Camunda BOM is set as second-level BOM.

Check the [full results](results.txt) from the output of `trivy.sh` script.

# Workaround

It is possible to get trivy working on myproject-level2 by flattening all dependencies, but requires multiple operations on CI, that's not ideal...

```bash
# Build the effective pom to flatten all dependencies
mvn help:effective-pom -Doutput=pom_flatten.xml -Dverbose=true

# Backup the original pom.xml
mv pom.xml pom_origin.xml

# Use the flatten pom.xml
mv pom_flatten.xml pom.xml

# Run the trivy scan
docker run -ti --rm \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v ~/.cache:/root/.cache \
     -v ${PWD}:/root/myproject \
     -v ~/.m2:/root/.m2 \
     --network=host aquasec/trivy fs --debug --timeout 30m /root/myproject

# Restore the original pom.xml
mv pom_origin.xml pom.xml
```