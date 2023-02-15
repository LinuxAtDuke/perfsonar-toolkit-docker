# perfSONAR Toolkit

FROM centos:centos7
MAINTAINER perfSONAR <perfsonar-user@perfsonar.net>

RUN yum -y install \
    epel-release \
    http://software.internet2.edu/rpms/el7/x86_64/latest/packages/perfSONAR-repo-0.10-1.noarch.rpm \
    && yum -y install \
    supervisor \
    rsyslog \
    openssh-server \
    openssh-clients \
    net-tools \
    sysstat \
    iproute \
    bind-utils \
    tcpdump \
    less \
    perfsonar-toolkit \
    && yum clean all \
    && rm -rf /var/cache/yum

# -----------------------------------------------------------------------

#
# PostgreSQL Server
#
# Based on a Dockerfile at
# https://raw.githubusercontent.com/zokeber/docker-postgresql/master/Dockerfile

# Postgresql version
ENV PG_VERSION 10
ENV PGVERSION 10

# Set the environment variables
ENV PGDATA /var/lib/pgsql/10/data

# Initialize the database
RUN rm -rf $PGDATA && mkdir $PGDATA && chown -R postgres:postgres $PGDATA && \
su - postgres -c "/usr/pgsql-10/bin/pg_ctl init"

# Overlay the configuration files
COPY postgresql/postgresql.conf /var/lib/pgsql/$PG_VERSION/data/postgresql.conf
COPY postgresql/pg_hba.conf /var/lib/pgsql/$PG_VERSION/data/pg_hba.conf

# Add post-container-start configuration utility
# Right now, it just updates the password at container start.
COPY postgresql/container-pgsql-boot-setup /usr/bin/container-pgsql-boot-setup

# Change owning user
RUN chown -R postgres:postgres /var/lib/pgsql/$PG_VERSION/data/*

# End PostgreSQL Setup


# -----------------------------------------------------------------------------

#
# pScheduler Database
#
# Initialize pscheduler database.  This needs to happen as one command
# because each RUN happens in an interim container.

COPY postgresql/perfSonar-build-database /tmp/perfSonar-build-database
RUN /tmp/perfSonar-build-database && rm -f /tmp/pscheduler-build-database


# -----------------------------------------------------------------------------

# Rsyslog
# Note: need to modify default CentOS7 rsyslog configuration to work with Docker, 
# as described here: http://www.projectatomic.io/blog/2014/09/running-syslog-within-a-docker-container/
COPY rsyslog/rsyslog.conf /etc/rsyslog.conf
COPY rsyslog/listen.conf /etc/rsyslog.d/listen.conf
COPY rsyslog/python-pscheduler.conf /etc/rsyslog.d/python-pscheduler.conf
COPY rsyslog/owamp-syslog.conf /etc/rsyslog.d/owamp-syslog.conf


# -----------------------------------------------------------------------------

# Disable prompting about perfSonar sudo user
RUN chmod -x /usr/lib/perfsonar/scripts/add_pssudo_user

# Create directories for pScheduler pid files
RUN mkdir -p /var/run/pscheduler-server/scheduler \
    && mkdir -p /var/run/pscheduler-server/runner \
    && mkdir -p /var/run/pscheduler-server/archiver \
    && mkdir -p /var/run/pscheduler-server/ticker

# Configure sshd
RUN mkdir -p /var/run/sshd \
    mkdir -p /etc/ssh/local
ADD sshd_config /etc/ssh/sshd_config
ADD sshd_exec /usr/sbin/sshd_exec

RUN mkdir -p /var/log/supervisor 
ADD supervisord.conf /etc/supervisord.conf

# The following ports are used:
# pScheduler: 443
# owamp:861, 8760-9960
# twamp: 862, 18760-19960
# simplestream: 5890-5900
# nuttcp: 5000, 5101
# iperf2: 5001
# iperf3: 5201
# sshd: 4022
EXPOSE 443 861 862 5000-5001 5101 5201 8760-9960 18760-19960 4022

# Add directories for PID files, logging,
# httpd, PKI, postgresql, cassandra, and perfsonar state.
VOLUME [ "/run", "/var/log", "/etc/rsyslog.d", \
"/etc/httpd", "/etc/pki", \
"/var/lib/pgsql", "/var/lib/cassandra", \
"/etc/perfsonar", "/var/lib/perfsonar", "/etc/ssh" ]

CMD /usr/bin/supervisord -c /etc/supervisord.conf
