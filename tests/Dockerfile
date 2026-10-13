ARG BASE=ubuntu:24.04
FROM ${BASE}
ENV DEBIAN_FRONTEND=noninteractive
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server openssh-client ufw fail2ban unattended-upgrades python3 python3-systemd iproute2 mariadb-server mariadb-client gnupg gzip tar coreutils util-linux && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd && ssh-keygen -A && useradd -m -s /bin/bash auditor
