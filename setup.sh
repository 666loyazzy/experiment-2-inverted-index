#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
  printf 'Run with sudo bash setup.sh\n' >&2
  exit 1
fi
install_root=/opt/hadoop-lab2
state_root=/var/lib/hadoop-lab2
if [ -e "$install_root/env.sh" ]; then
  printf 'Lab environment already exists at %s\n' "$install_root"
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
apt-get update
apt-get install -y openjdk-11-jdk-headless curl ca-certificates python3
id hadoop-lab >/dev/null 2>&1 || useradd --system --create-home --home-dir "$state_root" --shell /usr/sbin/nologin hadoop-lab
mkdir -p "$install_root" "$state_root"/hdfs/{name,data} "$state_root"/{logs,pids,tmp,yarn-local,yarn-logs}
cd "$install_root"
if [ ! -s hadoop-3.4.3.tar.gz ]; then
  curl -fL --retry 2 --connect-timeout 15 https://mirrors.huaweicloud.com/apache/hadoop/common/hadoop-3.4.3/hadoop-3.4.3.tar.gz -o hadoop-3.4.3.tar.gz
fi
printf 'e25be7e57b4d3c5bfe83895844321a21d6cf7331266d524d8983c27cf484e576c3d79b3b60d590f8cddecf16229d0e232de2491b1b61b362ee7d67072c7290e1\n' > hadoop-3.4.3.tar.gz.sha512
python3 - <<'PY'
import hashlib
import pathlib
import re
p = pathlib.Path('hadoop-3.4.3.tar.gz')
text = pathlib.Path('hadoop-3.4.3.tar.gz.sha512').read_text()
hashes = re.findall(r'[a-fA-F0-9]{128}', text)
assert hashes, 'SHA-512 checksum not found'
h = hashlib.sha512()
with p.open('rb') as stream:
    for block in iter(lambda: stream.read(1048576), b''):
        h.update(block)
assert h.hexdigest().lower() == hashes[0].lower(), 'Hadoop checksum mismatch'
print('Hadoop SHA-512 verified', h.hexdigest())
PY
tar -xzf hadoop-3.4.3.tar.gz
java_home="$(dirname "$(dirname "$(readlink -f /usr/lib/jvm/java-11-openjdk-amd64/bin/java)")")"
test -x "$java_home/bin/javac"
cat > env.sh <<EOF
export JAVA_HOME=$java_home
export HADOOP_HOME=$install_root/hadoop-3.4.3
export HADOOP_CONF_DIR=$install_root/hadoop-3.4.3/etc/hadoop
export HADOOP_LOG_DIR=$state_root/logs
export HADOOP_PID_DIR=$state_root/pids
export HADOOP_HEAPSIZE_MAX=256
export PATH=$install_root/hadoop-3.4.3/bin:\$JAVA_HOME/bin:\$PATH
EOF
source env.sh
cat > "$HADOOP_CONF_DIR/core-site.xml" <<EOF
<configuration>
<property><name>fs.defaultFS</name><value>hdfs://localhost:19000</value></property>
<property><name>hadoop.tmp.dir</name><value>$state_root/tmp</value></property>
</configuration>
EOF
cat > "$HADOOP_CONF_DIR/hdfs-site.xml" <<EOF
<configuration>
<property><name>dfs.replication</name><value>1</value></property>
<property><name>dfs.namenode.name.dir</name><value>file://$state_root/hdfs/name</value></property>
<property><name>dfs.datanode.data.dir</name><value>file://$state_root/hdfs/data</value></property>
<property><name>dfs.namenode.rpc-bind-host</name><value>127.0.0.1</value></property>
<property><name>dfs.namenode.http-address</name><value>127.0.0.1:19870</value></property>
<property><name>dfs.namenode.secondary.http-address</name><value>127.0.0.1:19868</value></property>
<property><name>dfs.datanode.address</name><value>127.0.0.1:19866</value></property>
<property><name>dfs.datanode.http.address</name><value>127.0.0.1:19864</value></property>
<property><name>dfs.datanode.ipc.address</name><value>127.0.0.1:19867</value></property>
<property><name>dfs.datanode.hostname</name><value>localhost</value></property>
<property><name>dfs.client.use.datanode.hostname</name><value>true</value></property>
</configuration>
EOF
cat > "$HADOOP_CONF_DIR/mapred-site.xml" <<EOF
<configuration>
<property><name>mapreduce.framework.name</name><value>yarn</value></property>
<property><name>mapreduce.application.classpath</name><value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value></property>
<property><name>mapreduce.map.memory.mb</name><value>512</value></property>
<property><name>mapreduce.map.java.opts</name><value>-Xmx384m</value></property>
<property><name>mapreduce.reduce.memory.mb</name><value>512</value></property>
<property><name>mapreduce.reduce.java.opts</name><value>-Xmx384m</value></property>
<property><name>yarn.app.mapreduce.am.resource.mb</name><value>512</value></property>
<property><name>yarn.app.mapreduce.am.command-opts</name><value>-Xmx384m</value></property>
</configuration>
EOF
cat > "$HADOOP_CONF_DIR/yarn-site.xml" <<EOF
<configuration>
<property><name>yarn.resourcemanager.hostname</name><value>localhost</value></property>
<property><name>yarn.resourcemanager.bind-host</name><value>127.0.0.1</value></property>
<property><name>yarn.nodemanager.hostname</name><value>localhost</value></property>
<property><name>yarn.nodemanager.bind-host</name><value>127.0.0.1</value></property>
<property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
<property><name>yarn.nodemanager.resource.memory-mb</name><value>1536</value></property>
<property><name>yarn.nodemanager.resource.cpu-vcores</name><value>2</value></property>
<property><name>yarn.scheduler.minimum-allocation-mb</name><value>512</value></property>
<property><name>yarn.scheduler.maximum-allocation-mb</name><value>1536</value></property>
<property><name>yarn.nodemanager.vmem-check-enabled</name><value>false</value></property>
<property><name>yarn.nodemanager.local-dirs</name><value>$state_root/yarn-local</value></property>
<property><name>yarn.nodemanager.log-dirs</name><value>$state_root/yarn-logs</value></property>
<property><name>yarn.log-aggregation-enable</name><value>true</value></property>
<property><name>yarn.nodemanager.env-whitelist</name><value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME,HADOOP_LOG_DIR,HADOOP_PID_DIR</value></property>
</configuration>
EOF
cat > "$HADOOP_CONF_DIR/capacity-scheduler.xml" <<'EOF'
<configuration>
<property><name>yarn.scheduler.capacity.root.queues</name><value>default</value></property>
<property><name>yarn.scheduler.capacity.root.default.capacity</name><value>100</value></property>
<property><name>yarn.scheduler.capacity.maximum-am-resource-percent</name><value>0.5</value></property>
</configuration>
EOF
printf '\nexport JAVA_HOME=%s\nexport HADOOP_LOG_DIR=%s/logs\nexport HADOOP_PID_DIR=%s/pids\nexport HADOOP_HEAPSIZE_MAX=256\n' "$java_home" "$state_root" "$state_root" >> "$HADOOP_CONF_DIR/hadoop-env.sh"
chown -R hadoop-lab:hadoop-lab "$install_root" "$state_root"
if [ ! -f "$state_root/hdfs/name/current/VERSION" ]; then
  runuser -u hadoop-lab -- bash -c "source $install_root/env.sh; hdfs namenode -format -nonInteractive"
fi
runuser -u hadoop-lab -- bash -c "source $install_root/env.sh; hdfs --daemon start namenode; hdfs --daemon start datanode; yarn --daemon start resourcemanager; yarn --daemon start nodemanager"
printf 'Environment ready at %s\n' "$install_root"
