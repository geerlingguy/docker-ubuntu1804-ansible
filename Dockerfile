FROM ubuntu:18.04
LABEL maintainer="Jeff Geerling"

# Install dependencies.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python-setuptools \
       python-pip \
       software-properties-common \
       rsyslog systemd systemd-cron sudo \
    && rm -Rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean
RUN sed -i 's/^\($ModLoad imklog\)/#\1/' /etc/rsyslog.conf
#ADD etc/rsyslog.d/50-default.conf /etc/rsyslog.d/50-default.conf

# Install Ansible via Pip.
RUN pip install ansible

# TODO: Once Ansible adds Bionic to it's PPA, switch back to package install.
# RUN add-apt-repository -y ppa:ansible/ansible \
#   && apt-get update \
#   && apt-get install -y --no-install-recommends \
#      ansible \
#   && rm -rf /var/lib/apt/lists/* \
#   && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
#   && apt-get clean

COPY initctl_faker .
RUN chmod +x initctl_faker && rm -fr /sbin/initctl && ln -s /initctl_faker /sbin/initctl

# Install Ansible inventory file.
RUN mkdir -p /etc/ansible
RUN echo "[local]\nlocalhost ansible_connection=local" > /etc/ansible/hosts
