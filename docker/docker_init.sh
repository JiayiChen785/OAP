#!/bin/bash

cd thirdparty/
yum -y groupinstall "Development Tools"
yum -y install wget
yum -y install java-1.8.0-openjdk
yum -y install java-1.8.0-openjdk-devel.x86_64
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.252.b09-2.el7_8.x86_64/jre" >> ~/.bashrc
echo "export PATH=$PATH:/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.252.b09-2.el7_8.x86_64/jre/bin:/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.252.b09-2.el7_8.x86_64/bin" >> ~/.bashrc
wget https://mirrors.bfsu.edu.cn/apache/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
tar xzvf apache-maven-3.6.3-bin.tar.gz
echo "export PATH=/root/thirdparty/apache-maven-3.6.3/bin:$PATH" >> ~/.bashrc
source ~/.bashrc
mvn -v
echo '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
	               http://maven.apache.org/xsd/settings-1.0.0.xsd">
	<proxies>
	 <proxy>
	   <active>true</active>
	   <protocol>http</protocol>
	   <host>child-prc.intel.com</host>
	   <port>913</port>
	   <nonProxyHosts>*intel.com</nonProxyHosts>
	 </proxy>
	</proxies>
	<mirrors>
	 <mirror>
	 	<id>nexus-163</id>
	 	<mirrorOf>*</mirrorOf>
	 	<name>Nexus 163</name>
	 	<url>http://maven.aliyun.com/nexus/content/groups/public</url>
	 </mirror>
	</mirrors>
</settings>
' > ~/.m2/settings.xml
mv ~/thirdparty/maven/* ~/.m2/repository/com/google/errorprone/javac/9+181-r4173-1/

#install gcc
yum -y install gmp-devel
yum -y install mpfr-devel
yum -y install libmpc-devel

wget https://bigsearcher.com/mirrors/gcc/releases/gcc-7.3.0/gcc-7.3.0.tar.xz
tar -xvf gcc-7.3.0.tar
cd gcc-7.3.0/
./configure --prefix=/usr --disable-multilib
make -j
make install
cd ..

#install conda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
source ~/.bashrc
cd ..

#install spark
wget http://archive.apache.org/dist/spark/spark-3.0.0/spark-3.0.0-bin-hadoop2.7.tgz
tar -xf ./spark-3.0.0-bin-hadoop2.7.tgz
echo "export SPARK_HOME=`pwd`/spark-3.0.0-bin-hadoop2.7" >> ~/.bashrc
source ~/.bashrc

#install hadoop
git clone https://github.com/apache/hadoop.git
cd hadoop
git checkout rel/release-3.2.0
mvn clean install -Pdist -DskipTests -Dtar
echo "export HADOOP_HOME=${HADOOP_PATH}/hadoop-dist/target/hadoop-3.2.0/" >> ~/.bashrc
source ~/.bashrc

#install arrow
git clone https://github.com/Intel-bigdata/arrow
cd arrow
git checkout origin/native-sql-engine-clean
conda create -y -n pyarrow-dev -c conda-forge \
    --file ci/conda_env_unix.yml \
    --file ci/conda_env_cpp.yml \
    --file ci/conda_env_python.yml \
    --file ci/conda_env_gandiva.yml \
    compilers \
    python=3.7 \
    pandas
conda activate pyarrow-dev
 
cd cpp && mkdir release-build
cd release-build
cmake .. -DARROW_JNI=ON -DARROW_GANDIVA_JAVA=ON -DARROW_GANDIVA=ON -DARROW_PARQUET=ON -DARROW_HDFS=ON -DARROW_FILESYSTEM=ON -DARROW_WITH_SNAPPY=ON -DARROW_JSON=ON -DARROW_DATASET=ON && make -j10  && make install
cd ~/arrow/java
mvn clean install -P arrow-jni -am -Darrow.cpp.build.dir=/root/arrow/cpp/release-build/release/ -DskipTests -Dcheckstyle.skip
cd ~

#build nativesql
git clone https://github.com/Intel-bigdata/OAP.git
cd OAP/oap-native-sql/core
echo 'export CFLAGS="-I/usr/local/include -I/root/miniconda3/envs/pyarrow-dev/include/"' >> ~/.bashrc
echo 'export CXXFLAGS="-I/usr/local/include -I/root/miniconda3/envs/pyarrow-dev/include/"' >> ~/.bashrc
echo 'export LDFLAGS="-L/usr/local/lib64"' >> ~/.bashrc
source ~/.bashrc
mvn clean package -DskipTests
cd ../../oap-data-source/arrow
mvn clean package -DskipTests

echo "spark.sql.join.preferSortMergeJoin  false
spark.sql.autoBroadcastJoinThreshold  1
spark.sql.catalogImplementation hive
spark.sql.sources.useV1SourceList avro
spark.sql.columnVector.arrow.enabled true
spark.sql.extensions com.intel.sparkColumnarPlugin.ColumnarPlugin
spark.driver.extraClassPath ~/arrow/java/dataset/target/arrow-dataset-0.17.0.jar:~/OAP/oap-native-sql/core/target/spark-columnar-core-0.9.0-jar-with-dependencies.jar:~/OAP/oap-data-source/arrow/target/spark-arrow-datasource-0.1.0-SNAPSHOT.jar
spark.executor.extraClassPath ~/arrow/java/dataset/target/arrow-dataset-0.17.0.jar:~/OAP/oap-native-sql/core/target/spark-columnar-core-0.9.0-jar-with-dependencies.jar:~/OAP/oap-data-source/arrow/target/spark-arrow-datasource-0.1.0-SNAPSHOT.jar
" > $SPARK_HOME/conf/spark-defaults.conf