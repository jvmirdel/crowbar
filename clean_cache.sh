#!/bin/bash
# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: VictorLowther
#

# This script expects to be able to run certian commands as root.
# Either run it as a user who can sudo to root, or give the user
# you are running it as the following sudo rights:
# crowbar-tester ALL = NOPASSWD: /bin/mount, /bin/umount, /usr/sbin/debootstrap, /bin/cp, /usr/sbin/chroot

# When running this script for the first time, it will automatically create a
# cache directory and try to populate it with all the build dependencies.
# After that, if you need to pull in new dependencies, you will need to
# call the script with the --update-cache parameter.  If you are going to
# develop on Crowbar, it is a good idea to put the build cache in its own git
# repository, and create a branching structure for the packages that mirrors
# the branching structure in the crowbar repository -- if you do that, then
# this build script can be smarter about what packages it should pull in
# whenever you invoke it to build an iso.

# We always use the C language and locale
export LANG="C"
export LC_ALL="C"

GEM_RE='([^0-9].*)-([0-9].*)'

readonly currdir="$PWD"
export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"

# Source our config file if we have one
[[ -f $HOME/.build-crowbar.conf ]] && \
    . "$HOME/.build-crowbar.conf"

# Look for a local one.
[[ -f build-crowbar.conf ]] && \
    . "build-crowbar.conf"

# Always run in verbose mode for now.
VERBOSE=true

# Set up our proxies if we were asked to.
if [[ $USE_PROXY = "1" && $PROXY_HOST ]]; then
    proxy_str="http://"
    if [[ $PROXY_PASSWORD && $PROXY_USER ]]; then
        proxy_str+="$PROXY_USER:$PROXY_PASSWORD@"
    elif [[ $PROXY_USER ]]; then
        proxy_str+="$PROXY_USER@"
    fi
    proxy_str+="$PROXY_HOST"
    [[ $PROXY_PORT ]] && proxy_str+=":$PROXY_PORT"
    [[ $no_proxy ]] || no_proxy="localhost,localhost.localdomain,127.0.0.0/8,$PROXY_HOST"
    [[ $http_proxy ]] || http_proxy="$proxy_str/"
    [[ $https_proxy ]] || https_proxy="$http_proxy"
    export no_proxy http_proxy https_proxy
else
    unset no_proxy http_proxy https_proxy
fi

# Barclamps to include.  By default, start with jsut crowbar and let
# the dependency machinery and the command line pull in the rest.
# Note that BARCLAMPS is an array, not a string!
[[ $BARCLAMPS ]] || BARCLAMPS=()

[[ $ALLOW_CACHE_UPDATE ]] || ALLOW_CACHE_UPDATE=true

# Location for caches that should not be erased between runs
[[ $CACHE_DIR ]] || CACHE_DIR="$HOME/.crowbar-build-cache"

