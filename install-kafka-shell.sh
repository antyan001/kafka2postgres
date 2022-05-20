#!/bin/sh -e

#source "${pwd}versions.sh"
. ./versions.sh
. ./load.env.sh

cnt_service_files=`ls -lrt -d /etc/systemd/system/* | grep -E ".*/system/.?[zookeeper|kafka]+.service.*$" | awk "{print $9}" | wc -l`
if [ $cnt_service_files -ge 1 ]; then
    rm_service_files=$(ls -lrt -d /etc/systemd/system/* | grep -E ".*/system/.?[zookeeper|kafka]+.service.*$" | awk '{print $9}' | xargs)
    IFS=$' '
    for file in $rm_service_files; do
      echo "removing file: $file"
      rm -f $file
    done
    IFS=$ORIG_IFS
else
    echo "Cannot find service files" >/dev/null
fi

rm -f /etc/.hosts.swp
rm -f -r $KAFKA_LOG_DIRS/*

if grep -E -q ".*127.0.0.1.*localhost.*" /etc/hosts; then
    sed -i -e "/.*127.0.0.1.*localhost.*/d" /etc/hosts
    sed -i -e "/.*::1.*/d" /etc/hosts
    echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >> /etc/hosts
    echo "::1         ip6-localhost ip6-localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
else
    echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >> /etc/hosts
    echo "::1         ip6-localhost ip6-localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
fi

while netstat -lnt | awk '{if ($4 ~ /:'"$KAFKA_PORT"'$/) {exit 1} else {exit 0}}'; do
  echo "Killing Runing Kafka Server..."
  sudo systemctl stop kafka
  lsof_check=`sudo lsof -t -i:"$KAFKA_PORT" | wc -l`
  if [ $lsof_check -ge 1 ]; then
      sudo kill $(sudo lsof -t -i:"$KAFKA_PORT") 2>&1>/dev/null
  fi
  break
done

while netstat -lnt | awk '{if ($4 ~ /:'"$KAFKA_ZOOKEEPER_PORT"'$/) {exit 1} else {exit 0}}'; do
  echo "Killing Runing Zookeeper Server..."
  sudo systemctl stop zookeeper
  lsof_check=`sudo lsof -t -i:"$KAFKA_ZOOKEEPER_PORT" | wc -l`
  if [ $lsof_check -ge 1 ]; then
      sudo kill $(sudo lsof -t -i:"$KAFKA_ZOOKEEPER_PORT") 2>&1>/dev/null
  fi
  break
done

result=`ps -aux | grep -E "kafka*|zookeeper*" | grep -v "install-kafka*" | awk '{print $1}' | wc -l`
if [ $result -ge 1 ]; then
    process_id=$( ps -a | grep -E "kafka*|zookeeper*" | grep -v "install-kafka*" | awk '{print $1}')
    # 		echo 'Killing'
    for pid in $process_id; do
        echo "##KILL##: $pid"
        kill -9 $pid
        sleep 1
    done
else
    echo "Kafka is not running" >/dev/null
fi

echo "Configuring --> $KAFKA_HOME/config/server.properties"

if grep -E -q ".*log.dirs=.*" $KAFKA_HOME/config/server.properties; then
  sed -i -e "/.*log.dirs=.*/d" $KAFKA_HOME/config/server.properties
  sed -i -e "/.*delete.topic.enable=.*/d" $KAFKA_HOME/config/server.properties
  echo -e "delete.topic.enable = true" >> $KAFKA_HOME/config/server.properties
  echo -e "log.dirs=${KAFKA_LOG_DIRS}" >> $KAFKA_HOME/config/server.properties
fi

echo "Configuring --> /etc/systemd/system/zookeeper.service"

echo -e "[Unit]\nRequires=network.target remote-fs.target\nAfter=network.target remote-fs.target\n" >> /etc/systemd/system/zookeeper.service
echo -e "[Service]\nType=simple\nUser=root\nExecStart=$KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties\nExecStop=$KAFKA_HOME/bin/zookeeper-server-stop.sh\nRestart=on-abnormal\n" >> /etc/systemd/system/zookeeper.service
echo -e "[Install]\nWantedBy=multi-user.target" >> /etc/systemd/system/zookeeper.service

echo "Configuring --> /etc/systemd/system/kafka.service"

echo -e "[Unit]\nRequires=zookeeper.service\nAfter=zookeeper.service\n" >> /etc/systemd/system/kafka.service
echo -e "[Service]\nType=simple\nUser=root\nEnvironment=\"JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64\"\nExecStart=/bin/sh -c '$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > $KAFKA_LOG_DIRS/kafka.log 2>&1'\nExecStop=$KAFKA_HOME/bin/kafka-server-stop.sh\nRestart=on-abnormal\n" >> /etc/systemd/system/kafka.service
echo -e "[Install]\nWantedBy=multi-user.target" >> /etc/systemd/system/kafka.service

#exec "$KAFKA_HOME/bin/kafka-server-start.sh" "$KAFKA_HOME/config/server.properties"

echo "Starting services..."

sudo systemctl daemon-reload
sudo systemctl start kafka
sudo systemctl enable zookeeper
sudo systemctl enable kafka
sudo systemctl status kafka

#./create-topics.sh
#unset KAFKA_CREATE_TOPICS