#!/bin/zsh
# Build Quicklook Anything from this checkout and install it on this Mac, the
# same way friends install a release (install.sh), but from the local zip.
#
# Usage: LocalBuild/build-install.sh
set -euo pipefail

cd "${0:A:h}/.."
LocalBuild/build.sh
zsh install.sh --zip LocalBuild/dist/QuicklookAnything.zip
