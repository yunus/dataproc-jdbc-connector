# JDBC Connector for Apache Hive on Cloud Dataproc
DataprocDriver provides a secure, easily accessible way to connect to [Apache Hive][hive] on [Dataproc][dataproc] cluster from everywhere via Java Database Connection through [Component Gateway][CG].

[hive]: https://hive.apache.org/
[dataproc]: https://cloud.google.com/dataproc
[CG]: https://cloud.google.com/dataproc/docs/concepts/accessing/dataproc-gateways

Supported Java Version: 1.8

## Before you begin
In order to use this library, you first need to go through the following steps:

1. [Set up a Cloud project][set up a project]
2. [Setup Authentication][authentication] <br />
    Note that we recommend using service account login rather than end user login.
3. If you plan to use internal IPs only, follow [this guide](https://cloud.google.com/vpc-service-controls/docs/set-up-private-connectivity) to setup your VPC network.
4. Make sure [Component Gateway is enabled][create cluster with CG] for the cluster(s) you are trying to connect to within the project
5. Make sure [Hive is running in HTTP mode][http mode] for the cluster(s). To achieve that create the cluster with the following cluster properties:
```json
override_properties = {
  "hive:hive.server2.transport.mode"   = "http",
  "hive:hive.server2.thrift.http.port" = "10000",
  "hive:hive.server2.thrift.http.path" = "cliservice",
}
```
5. Make sure that Knox is configured to use port 1000. To do that we have an example initialization action [knox-config.sh](knox-config.sh)

[set up a project]: [https://cloud.google.com/dataproc/docs/guides/setup-project]
[authentication]: https://cloud.google.com/docs/authentication/getting-started#auth-cloud-implicit-python
[create cluster with CG]: https://cloud.google.com/dataproc/docs/concepts/accessing/dataproc-gateways#creating_a_cluster_with_component_gateway
[http mode]: https://cwiki.apache.org/confluence/display/Hive/Setting+Up+HiveServer2#SettingUpHiveServer2-RunninginHTTPMode

## How to use Dataproc Driver
1. The Dataproc JDBC driver is an add-on for Hive JDBC driver. We add google authentication to Hive JDBC but 
for that to happen Hive JDBC should allow HTTP interceptors. You should re-compile Hive with the changes from [this commit](https://github.com/yunus/hive/commit/ae598d2f75fc59c9ba8a99af28ea521a50200f02).
The commit is only for 2.3.x release but the changes are simple to be ported to other Hive versions.
 
2. After having Hive JDBC, Clone this repo
    ```bash
    git clone https://github.com/GoogleCloudDataproc/dataproc-jdbc-connector.git
    cd dataproc-jdbc-connector
    ``` 
3. Build Dataproc Driver JAR by placing the Hive JDBC driver under hive folder or change [hive/build.gradle](hive/build.gradle) to point the correct location.
    ```bash
   # To create fat-jar run below. You may use the fat-jar with beeline
    ./gradlew -p jdbc-driver shadowJar
   # To have a slim-jar with fewer dependencies baked in, run
   ./gradlew -p jdbc-driver jar
    ```
    Note that this step might take around 45 minutes. <br />
    Compiled Dataproc Driver JAR will be at `dataproc-jdbc-connector/jdbc-driver/build/libs/jdbc-driver-1.0-SNAPSHOT-all.jar`.

4. Build example-client JAR
    ```bash
    ./gradlew -p example-client shadowJar
    ```

### Connection URL format
* Dataproc Driver for Hive accepts JDBC URL string with prefix `jdbc:dataproc://hive/`
* Client can pass in database name or leave it as empty to use default database <br>
  `jdbc:dataproc://hive/;` or `jdbc:dataproc://hive/dbName;`
* `projectId` and `region` are required parameters. To find your project and region, refer back to [Set up a Cloud project](https://cloud.google.com/dataproc/docs/guides/setup-project) in the **Before you begin** section above <br>
  `jdbc:dataproc://hive/;projectId={pid};region={region}`
* Cluster specific parameters: `clusterName` or `clusterPoolLabel` <br>
Client can set parameters to pick a particular cluster by setting either one of `clusterName` or `clusterPoolLabel` <br>
Note that `clusterName` has a higher priority than `clusterPoolLabel`, if you pass in both parameters, the DataprocDriver will only look for the cluster by name.

    * `clusterName` is an optional parameter that allows client to specify the name of the cluster to connect to <br>
    `jdbc:dataproc://hive/;projectId={pid};region={region};clusterName={cluster-name}`
    * `clusterPoolLabel` is an optional parameter that supports submitting to a cluster pool <br> 
    Client can pass in cluster pool labels and the Dataproc Driver will pick a healthy cluster (cluster with `status.state = ACTIVE`) within the pool to connect to. Please do not put `status.state` as one of the cluster pool label. 
 
    Labels can be specified in the format `clusterPoolLabel=label1=value1[:label2=value2]`
       
    Example: 
    ```bash
    jdbc:dataproc://hive/;projectId={pid};region={region};clusterPoolLabel=com=google:team=dataproc`
    ```   
* DataprocDriver also accepts other semicolon separated list of session variables, Hive configuration variables or Hive variables that [Hive supports](https://cwiki.apache.org/confluence/display/Hive/HiveServer2+Clients#HiveServer2Clients-ConnectionURLFormat)

    ```bash
    jdbc:dataproc://hive/{dbName};projectId={pid};region={region};clusterName={name};sess_var_list?hive_conf_list#hive_var_list
    ```
    
### Connecting to Dataproc through Component Gateway
DataprocDriver uses Google OAuth 2.0 APIs for authentication and authorization.

To connect to Dataproc cluster through Component Gateway, the Dataproc JDBC Driver will include an authentication token. For security reasons, it puts the token in the `Proxy-Authorization:Bearer` header.

To get the access token set in <strong> Before you begin step 2 </strong> section above, DataprocDriver will use the [Application Default](https://cloud.google.com/sdk/gcloud/reference/auth/application-default) Credentials.
   
### Use with Beeline
```bash
# update the HADOOP_CLASSPATH to include the Dataproc JDBC Driver JARs
export HADOOP_CLASSPATH=`hadoop classpath`:{path-to-driver-jar}jdbc-driver-1.0-SNAPSHOT-all.jar

# tell beeline the class name for the driver using “-d” option
beeline -d "com.google.cloud.dataproc.jdbc.DataprocDriver" -u "jdbc:dataproc://hive/;projectId={pid};region={region};{other-parameters}"
```
Example:
```bash
export HADOOP_CLASSPATH=`hadoop classpath`:/usr/local/home/Downloads/dataproc-jdbc-connector/jdbc-driver/build/libs/jdbc-driver-1.0-SNAPSHOT-all.jar
beeline -d "com.google.cloud.dataproc.jdbc.DataprocDriver" -u "jdbc:dataproc://hive/;projectId=demo-dataproc;region=us-central1;clusterName=demo-cluster"
```

### Use with example client
We have provided an example client -- an example usage of the JDBC driver from Java that connects to Hive using our Dataproc Driver.
```java
Connection connection = DriverManager.getConnection("jdbc:dataproc://hive/default;projectId=pid;region=us-central1;clusterName=my-cluster");
try (Statement stmt = connection.createStatement()) {
  ResultSet res = stmt.executeQuery("SHOW TABLES");
  while (res.hasNext()) {
    System.out.println(res.getString(1));
  }
}
```

To run the example client:
```bash
# build example client JAR
./gradlew -p example-client shadowJar

# run the JAR, it will prompt you to enter the JDBC URL string
java -jar example-client/build/libs/example-client-1.0-SNAPSHOT-all.jar
```

## Running the tests
* To run all unit tests, use `./gradlew test`

* To run specific unit test, use 
    ```bash
    ./gradlew test --tests="com.google.cloud.dataproc.jdbc.{test name}"
    ```

* To run system test, use
    ```bash
    ./gradlew systemTest --tests="com.google.cloud.dataproc.jdbc.DataprocSystemTest" -DprojectId="{projectId}" -Dregion="{region}" -Duser="{user}"
    ```
    Note that projectId and region are the parameters for the specific project you are working on; user can be an arbitrary username, used as a prefix for the cluster name to create, delete and avoid cluster conflict during testing.
