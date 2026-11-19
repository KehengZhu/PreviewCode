#!/bin/zsh
# Build Quicklook Anything from this checkout and install it on this Mac, the
# same way friends install a release (install.sh), but from the local zip.
#
# Usage: Scripts/build-install.sh
set -euo pipefail

cd "${0:A:h}/.."
Scripts/build.sh
zsh install.sh --zip build/dist/QuicklookAnything.zip
