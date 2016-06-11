#!/bin/bash -ex

#Detect OS. If Linux, determine distribution.

OS=`uname -s`
REV=`uname -r`
MACH=`uname -m`

GetVersionFromFile()
{
        VERSION=`cat $1 | tr "\n" ' ' | sed s/.*VERSION.*=\ // `
}


if [ "${OS}" = "Linux" ] ; then
        KERNEL=`uname -r`
        if [ -f /etc/redhat-release ] ; then
                DIST='RedHat'
                INSTALLFOR='RedHat'
                PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
                REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
                DIST="Debian `cat /etc/debian_version`"
                INSTALLFOR='Debian'
                REV=""
        elif [ -f /etc/lsb-release ] ; then
                DIST="Ubuntu"
                INSTALLFOR='Ubuntu'
        elif [ -f /etc/system-release ] ; then
                DIST="LinuxAMI"
                INSTALLFOR='LinuxAMI'
        fi

        OSSTR="${OS} ${DIST} ${REV}(${PSUEDONAME} ${KERNEL} ${MACH})"

fi

INSTALLFOR="Ubuntu"
echo "${INSTALLFOR}"

#Install Cassandra for the Linux distribution identified.

if [ "${INSTALLFOR}" = "Ubuntu" -o "${INSTALLFOR}" = "Debian" ] ; then

	apt-get -y update > /dev/null
	apt-get -y install git > /dev/null
	apt-get -y install wget > /dev/null

#install Java in silent mode
cat - <<-EOF >> /etc/apt/sources.list.d/webupd8team-java.list
	# webupd8team repository list 
	deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
EOF

	apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xEEA14886

	echo debconf shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
	echo debconf shared/accepted-oracle-license-v1-1 seen true | /usr/bin/debconf-set-selections

	apt-get -y update > /dev/null
	apt-get -y install oracle-java8-installer > /dev/null

	#setup the Cassandra repo
	echo "deb http://www.apache.org/dist/cassandra/debian 21x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
	echo "deb-src http://www.apache.org/dist/cassandra/debian 21x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list

	gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D
	gpg --export --armor F758CE318D77295D | sudo apt-key add -

	gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00
	gpg --export --armor 2B5C1B00 | sudo apt-key add -

	gpg --keyserver pgp.mit.edu --recv-keys 0353B12C
	gpg --export --armor 0353B12C | sudo apt-key add -

	apt-get update > /dev/null

        apt-get -y install cassandra > /dev/null

	#Setup and install Tomcat 8
	wget http://mirror.nexcess.net/apache/tomcat/tomcat-8/v8.0.35/bin/apache-tomcat-8.0.35.tar.gz
	groupadd tomcat
	useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat
	mkdir /opt/tomcat
	tar xvf apache-tomcat-8*tar.gz -C /opt/tomcat --strip-components=1

	cd /opt/tomcat
	chgrp -R tomcat conf
	chmod g+rwx conf
	chmod g+r conf/*

	chown -R tomcat work/ temp/ logs/
	
cat << 'TOMCATCONFIG' > /etc/init/tomcat.conf
description "Tomcat Server"

  start on runlevel [2345]
  stop on runlevel [!2345]
  respawn
  respawn limit 10 5

  setuid tomcat
  setgid tomcat

  env JAVA_HOME=/usr/lib/jvm/java-8-oracle
  env CATALINA_HOME=/opt/tomcat

  # Modify these options as needed
  env JAVA_OPTS="-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
  env CATALINA_OPTS="-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

  exec $CATALINA_HOME/bin/catalina.sh run
  # cleanup temp directory after stop
  post-stop script
    rm -rf $CATALINA_HOME/temp/*
  end script
TOMCATCONFIG

initctl reload-configuration
initctl start tomcat

	rm ~/apache-tomcat-8.0.35.tar.gz
	
	cd ~

	#Install Priam 3.x
	git clone https://github.com/Netflix/Priam.git
	cd ~/Priam
	git checkout 3.x
	
	./gradlew build

	#Copy the Priam cass extension to the Cassandra libs dir
	cp ~/Priam/priam-cass-extensions/build/libs/priam-cass-extensions-3.2.0-SNAPSHOT.jar /usr/share/cassandra/lib

	#Copy priam war to the Tomcat container
	cp ~/Priam/priam-web/build/libs/priam-web-3.2.0-SNAPSHOT.war /opt/tomcat/webapps/Priam.war
	
	#add the priam javaagent

cat <<CRED > /etc/awscredential.properties
#This will be replaced by IAM roles
AWSACCESSID=YOUR_AWS_ACCESS_ID
AWSKEY=YOUR_AWS_SECRET
CRED

cat <<JAVAAGENT >> /etc/cassandra/cassandra-env.sh 
JVM_OPTS="$JVM_OPTS -javaagent:$CASSANDRA_HOME/lib/priam-cass-extensions-3.2.0-SNAPSHOT.jar"
JAVAAGENT

	#Do this to save yourself a few days worth of debugging
	cp /opt/tomcat/webapps/Priam/WEB-INF/lib/snappy-java-1.0.5.jar /opt/tomcat/lib/

elif [ "${INSTALLFOR}" = "RedHat" -o "${INSTALLFOR}" = "LinuxAMI" ] ; then

	echo "Coming soon..."
fi
