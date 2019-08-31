FROM ubuntu:bionic-20190807
LABEL maintainer="Jeff Geerling"

ENV pip_upgrade_packages "pip setuptools"
ENV pip_packages "ansible"
ENV ca_bundle "/etc/ssl/certs/ca-certificates.crt"
ENV ca_cert_location "/usr/local/share/ca-certificates"
ENV ca_cert_file "Cromwell-ROOT-CA.crt"

# Install dependencies.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    apt-utils \
    locales \
    python3-setuptools \
    python3-pip \
    software-properties-common \
    rsyslog systemd systemd-cron sudo iproute2 \
    && rm -Rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean
RUN sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf

# Fix potential UTF-8 errors with ansible-test.
RUN locale-gen en_US.UTF-8

# Install company root certificate
COPY --chown=0:0 ./${ca_cert_file} ${ca_cert_location}/${ca_cert_file}
RUN chmod 0644 ${ca_cert_location}/${ca_cert_file} \
    && /usr/sbin/update-ca-certificates

# Upgrade Python dependencies packages
copy --chown=0:0 ./python-dependencies/requirements.txt ./python-dependencies/requirements.txt
RUN cat ./python-dependencies/requirements.txt && pip3 install --cert=${ca_bundle} --upgrade --requirement ./python-dependencies/requirements.txt

# Set pip to use system ca-bundle
RUN pip3 config set global.cert ${ca_bundle}

# Install Ansible via Pip.
copy --chown=0:0 ./python/requirements.txt ./python/requirements.txt
RUN cat ./python/requirements.txt && pip3 install --requirement ./python/requirements.txt

COPY initctl_faker .
RUN chmod +x initctl_faker && rm -fr /sbin/initctl && ln -s /initctl_faker /sbin/initctl

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts

# Remove unnecessary getty and udev targets that result in high CPU usage when using
# multiple containers with Molecule (https://github.com/ansible/molecule/issues/1104)
RUN rm -f /lib/systemd/system/systemd*udev* \
    && rm -f /lib/systemd/system/getty.target

# Create `ansible` user with sudo permissions
ENV ANSIBLE_USER=ansible SUDO_GROUP=sudo
RUN set -xe \
    && groupadd -r ${ANSIBLE_USER} \
    && useradd -m -g ${ANSIBLE_USER} ${ANSIBLE_USER} \
    && usermod -aG ${SUDO_GROUP} ${ANSIBLE_USER} \
    && sed -i "/^%${SUDO_GROUP}/s/ALL\$/NOPASSWD:ALL/g" /etc/sudoers

VOLUME ["/sys/fs/cgroup", "/tmp", "/run"]
CMD ["/lib/systemd/systemd"]
