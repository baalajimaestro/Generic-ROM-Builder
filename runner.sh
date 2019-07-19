#!/bin/bash
# Copyright (C) 2019 baalajimaestro
#
# Licensed under the Raphielscape Public License, Version 1.b (the "License");
# you may not use this file except in compliance with the License.
#
# CI Runner Script for Building a ROM

# We need this directive
# shellcheck disable=1090

echo "***BuildBot***"
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
echo $TELEGRAM_TOKEN > /tmp/tg_token
echo $GH_PERSONAL_TOKEN > /tmp/gh_token
echo $GH_REPO_NAME > /tmp/gh_repo
echo $DRONE_BUILD_NUMBER > /tmp/build_no
echo $TELEGRAM_CHAT > /tmp/tg_chat
echo `pwd` > /tmp/loc
apt install sudo git lsb-core apt-utils -y > /dev/null 2>&1
echo 'Initial Dependencies Installed......'
sudo echo "ci ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
useradd -m -d /home/ci ci
useradd -g ci wheel
echo `pwd` > /tmp/loc
sudo -Hu ci bash -c "bash build.sh -i rr -U https://github.com/ResurrectionRemix/platform_manifest.git -B pie -b xiaomi -d whyred -r"
