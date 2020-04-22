#!/bin/bash
# Setup BTE server
#

# Set variable to generate a basic McMyAdmin server.
#IS_NEW_SERVER=yes

# Helper functions
msg(){ echo -e "\033[32m ==>\033[m\033[1m $1\033[m" ;}
msg2(){ echo -e "\033[34m   ->\033[m\033[1m $1\033[m" ;}
warning(){ echo -e "\033[33m ==>\033[m\033[1m $1\033[m" >&2 ;}
error(){ echo -e "\033[31m ==>\033[m\033[1m $1\033[m" >&2 ;}


# Core functions
function setup_users() {
    msg 'Setting up users'
    msg2 'Setting up minecraft user'
    if ! id minecraft; then
        msg2 'Creating minecraft user'
        if ! useradd -ms /bin/bash minecraft; then
            warning 'Failed to create user'
            exit 1
        fi
    fi

    msg2 'Setting up admin user'
    if ! id admin; then
        msg2 'Creating admin user'
        if ! apt-get install zsh; then
            error 'Failed to install packages'
            exit 1
        fi
        if ! useradd -mG minecraft -s /bin/zsh admin; then
            warning 'Failed to create user'
            exit 1
        fi
    fi

    msg2 'Setting up sftp user'
    if ! id sftp; then
        msg2 'Creating sftp user'
        if ! apt-get install rssh; then
            error 'Failed to install packages'
            exit 1
        fi
        if ! useradd -mG minecraft -s /bin/rssh sftp; then
            warning 'Failed to create user'
            exit 1
        fi
    fi
}

function setup_mcmyadmin() {

    msg 'Setting up McMyAdmin'

    msg2 'Installing needed packages'
    if ! apt-get install \
            python3-software-properties \
            openjdk-8-jre \
            unzip\
            mono-complete; then
        error 'Failed to install packages'
        exit 1
    fi

    msg2 'Installing MCMA2'
    MCMYADMIN_URL='https://mcmyadmin.com'
    MCMA2_EXEC='MCMA2_Linux_x86_64'
    mkdir -p /home/minecraft/server
    chown minecraft:minecraft /home/minecraft/server
    cd /home/minecraft/server
    download_and_unzip "$MCMYADMIN_URL/Downloads/MCMA2_glibc26_2.zip" 'MCMA2_glibc26_2.zip'
    chown minecraft:minecraft "$MCMA2_EXEC"

    msg2 'Installing mono'
    cd /usr/local
    download_and_unzip "$MCMYADMIN_URL/Downloads/etc.zip" 'etc.zip'

    if [ -z ${IS_NEW_SERVER+x} ]; then
        msg2 'Setting up MCMA2'
        cd /home/minecraft/server
        echo -n 'Please provide a password: '
        read -s password
        if ! su -c "./$MCMA2_EXEC -setpass $password -configonly" minecraft; then
            error 'Failed setting up MCMA2'
            exit 1
        fi
        msg2 'Disabling login shell for minecraft user'
        chsh -s /usr/sbin/nologin minecraft
    else
        warning 'Please do not forget to disable the login shell of the minecraft user'
    fi

    msg2 'Setting up service'
    tee /lib/systemd/system/mcmyadmin.service <<EOF
[Unit]
Description=Minecraft MyAdmin Panel
Requires=network.target
After=network.target

[Service]
User=minecraft
Group=minecraft
WorkingDirectory=/home/minecraft/server
ExecStart=/home/minecraft/server/MCMA2_Linux_x86_64

[Install]
Alias=mcmyadmin.service
EOF
    systemctl enable mcmyadmin.service

    if [ ! -z ${IS_NEW_SERVER+x} ]; then
        msg2 'Starting service'
        systemctl start mcmyadmin.service
    fi
}

function download_and_unzip() {
    if ! wget "$1"; then
        error 'Failed to download the zip file'
        exit 1
    fi
    if ! unzip "$2"; then
        error 'Failed to unzip the file'
        exit 1
    fi
    rm "$2"
}

function setup_ufw() {
    msg 'Setting up UFW'

    ufw default deny
    ufw limit ssh
    ufw allow from 127.0.0.1
    # Website
    ufw allow http
    ufw allow https
    # Minecraft
    ufw allow 25565
    # McMyAdmin Panel
    ufw allow 8080

    msg2 'Enabling UFW'
    ufw enable
    ufw status
}

function setup_mariadb() {
    msg 'Setting up MariaDB'

    if ! apt-get install mariadb-server; then
        error 'Failed to install packages'
        exit 1
    fi
    mysql_secure_installation
}

setup_users
setup_mcmyadmin
setup_ufw
setup_mariadb
