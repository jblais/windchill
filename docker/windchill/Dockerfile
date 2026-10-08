# syntax=docker/dockerfile:1
# Image de base Windchill : prérequis système uniquement.
# Le logiciel PTC (plusieurs Go, sous licence) n'est PAS copié dans l'image :
# il est installé au premier démarrage depuis le média monté dans /opt/ptc-media.
FROM rockylinux/rockylinux:9

# ARG JAVA_PACKAGE=java-17-openjdk-devel
ARG CORRETTO_ARCH=x64
ARG WC_UID=1000
ARG WC_GID=1000

# Install locale support early to avoid warnings
RUN dnf -y install glibc-langpack-en glibc-langpack-fr tzdata && dnf clean all

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TZ=Europe/Paris \
    DISPLAY=:0

RUN curl -fsSL -o /tmp/corretto.tgz \
    "https://corretto.aws/downloads/resources/21.0.8.9.1/amazon-corretto-21.0.8.9.1-linux-x64.tar.gz" && \
    mkdir -p /usr/lib/jvm/corretto-21 && \
    tar -xzf /tmp/corretto.tgz -C /usr/lib/jvm/corretto-21 --strip-components=1 && \
    rm /tmp/corretto.tgz

ENV JAVA_HOME=/usr/lib/jvm/corretto-21
ENV PATH="${JAVA_HOME}/bin:${PATH}"

RUN dnf -y update && \
    dnf -y install --allowerasing \
        epel-release \
        which unzip zip tar gzip findutils procps-ng hostname iproute \
        net-tools bind-utils nc curl \
        fontconfig freetype dejavu-sans-fonts \
        libXtst libXrender libXi libX11 libXext libXrandr \
        ncurses tcsh \
        perl \
        xorg-x11-server-Xvfb xterm sudo openssh-server nano unzip sed \
        xorg-x11-fonts-* xorg-x11-utils xorg-x11-xauth dbus-x11 xrdb \
    && dnf clean all && rm -rf /var/cache/dnf


RUN dnf install -y 'dnf-command(config-manager)'
RUN dnf config-manager --set-enabled crb
# Install X11 dependencies (minimal)
RUN dnf install -y xorg-x11-xinit xauth

ARG RHEL_RELEASE=10.0

RUN rm -f /etc/redhat-release /etc/system-release /etc/os-release /usr/lib/os-release && \
    echo "Red Hat Enterprise Linux release ${RHEL_RELEASE} (Coughlan)" > /etc/redhat-release && \
    ln -s redhat-release /etc/system-release && \
    printf '%s\n' \
      'NAME="Red Hat Enterprise Linux"' \
      "VERSION=\"${RHEL_RELEASE} (Coughlan)\"" \
      'ID="rhel"' \
      'ID_LIKE="centos fedora"' \
      "VERSION_ID=\"${RHEL_RELEASE}\"" \
      'PLATFORM_ID="platform:el10"' \
      "PRETTY_NAME=\"Red Hat Enterprise Linux ${RHEL_RELEASE} (Coughlan)\"" \
      'ANSI_COLOR="0;31"' \
      'LOGO="fedora-logo-icon"' \
      'CPE_NAME="cpe:/o:redhat:enterprise_linux:10::baseos"' \
      'HOME_URL="https://www.redhat.com/"' \
      'BUG_REPORT_URL="https://issues.redhat.com/"' \
      'REDHAT_SUPPORT_PRODUCT="Red Hat Enterprise Linux 10"' \
      "REDHAT_SUPPORT_PRODUCT_VERSION=${RHEL_RELEASE}" \
      > /usr/lib/os-release && \
    ln -s ../usr/lib/os-release /etc/os-release

# Utilisateur applicatif (Windchill ne doit pas tourner en root)
RUN groupadd -g ${WC_GID} wind && \
    useradd -m -u ${WC_UID} -g wind -s /bin/bash wind && \
    echo 'wind:WIND' | chpasswd && echo 'root:WIND' | chpasswd && \
    mkdir -p /run/sshd /opt/ptc /opt/ptc-media /opt/ptc-scripts/hooks && \
    chown wind:wind /run/sshd && chmod 755 /run/sshd && \
    chown -R wind:wind /opt/ptc /opt/ptc-scripts
    #/home/wind/.Xauthority

# Add xauth to allowed sudo commands for wind
RUN echo 'wind ALL=(ALL) NOPASSWD: SETENV: ALL' > /etc/sudoers.d/wind && \
    chmod 0440 /etc/sudoers.d/wind

RUN printf 'windchill soft nofile 65536\nwindchill hard nofile 65536\nwindchill soft nproc 65536\nwindchill hard nproc 65536\n' \
    > /etc/security/limits.d/99-windchill.conf

COPY --chown=wind:wind entrypoint.sh /opt/ptc-scripts/entrypoint.sh
RUN chmod +x /opt/ptc-scripts/entrypoint.sh
COPY --chown=wind:wind entrypointNone.sh /opt/ptc-scripts/entrypointNone.sh
RUN chmod +x /opt/ptc-scripts/entrypointNone.sh

# Set up SSH configuration and generate keys
RUN mkdir -p /etc/ssh /var/run/sshd && \
    ssh-keygen -A && \
    chmod 600 /etc/ssh/ssh_host_* && \
    chmod 644 /etc/ssh/ssh_host_*.pub && \
    chmod 755 /etc/ssh && \
    chmod 644 /etc/ssh/sshd_config && \
    sed -i 's|#PidFile /var/run/sshd.pid|PidFile /tmp/sshd.pid|g' /etc/ssh/sshd_config && \
    chmod 777 /var/run/sshd && \
    chown -R wind:wind /etc/ssh/

# Remove nologin file to allow SSH access
RUN rm -f /run/nologin

RUN touch /home/wind/.Xauthority && \
    chown wind:wind /home/wind/.Xauthority && chmod 600 /home/wind/.Xauthority && \
    touch ~/.Xauthority && chmod 600 ~/.Xauthority && \
    touch /etc/fstab && chmod 600 /etc/fstab

# https://www.ptc.com/en/support/article/cs178146
RUN mkdir -p /var/tmp && chmod 1777 /var/tmp

USER wind
WORKDIR /opt/ptc
EXPOSE 8080 4443 22

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ps aux | grep sshd || exit 1


# Start SSH service
CMD ["/usr/sbin/sshd", "-D", "-e"]

ENTRYPOINT ["/opt/ptc-scripts/entrypointNone.sh"]