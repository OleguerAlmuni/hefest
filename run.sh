#!/bin/bash
# Run the testbed application.
# The testbed is linked with -Wl,-rpath,. so libengine.so is resolved relative
# to the current working directory -- hence we cd into bin before launching.
set -e

cd "$(dirname "$0")/bin"
./testbed "$@"
