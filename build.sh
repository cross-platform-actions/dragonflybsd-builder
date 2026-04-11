#!/usr/bin/env sh

set -eux

OS_VERSION="$1"; shift
ARCHITECTURE="$1"; shift

packer init main.pkr.hcl || packer init .

packer build \
  -var os_version="$OS_VERSION" \
  -var-file "var_files/$ARCHITECTURE.pkrvars.hcl" \
  -var-file "var_files/$OS_VERSION/$ARCHITECTURE.pkrvars.hcl" \
  -var-file "var_files/$OS_VERSION/common.pkrvars.hcl" \
  "$@" \
  main.pkr.hcl
