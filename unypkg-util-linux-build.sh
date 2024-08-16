#!/usr/bin/env bash
# shellcheck disable=SC2034,SC1091,SC2154

set -vx

######################################################################################################################
### Setup Build System and GitHub

#apt install -y

wget -qO- uny.nu/pkg | bash -s buildsys
mkdir /uny/tmp

### Installing build dependencies
#unyp install

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

source /uny/git/unypkg/fn
uny_auto_github_conf

######################################################################################################################
### Timestamp & Download

uny_build_date

mkdir -pv /uny/sources
cd /uny/sources || exit

pkgname="util-linux"
pkggit="https://github.com/util-linux/util-linux.git refs/tags/v[0-9.]*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9]([.0-9]+)+$" | tail -n 1)"
latest_ver="$(echo "$latest_head" | cut --delimiter='/' --fields=3 | sed "s|v||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

version_details

# Release package no matter what:
echo "newer" >release-"$pkgname"

git_clone_source_repo

#cd "$pkg_git_repo_dir" || exit
#cd /uny/sources || exit

archiving_source

######################################################################################################################
### Build

# unyc - run commands in uny's chroot environment
# shellcheck disable=SC2154
unyc <<"UNYEOF"
set -vx
source /uny/git/unypkg/fn

pkgname="util-linux"

version_verbose_log_clean_unpack_cd
get_env_var_values
get_include_paths

####################################################
### Start of individual build script

unset LD_RUN_PATH

./autogen.sh

#sed -i '/test_mkfds/s/^/#/' tests/helpers/Makemodule.am

./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --prefix=/uny/pkg/"$pkgname"/"$pkgver" \
    --runstatedir=/run \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-liblastlog2 \
    --disable-static \
    --without-python \
    --without-systemd \
    --without-systemdsystemunitdir \
    --docdir=/uny/pkg/"$pkgname"/"$pkgver"/share/doc/util-linux

make -j"$(nproc)"

touch /etc/fstab
chown -R tester .
su tester -c "make -k -j$(nproc) check"

chown -R root:root .
make install

####################################################
### End of individual build script

add_to_paths_files
dependencies_file_and_unset_vars
cleanup_verbose_off_timing_end
UNYEOF

######################################################################################################################
### Packaging

package_unypkg
