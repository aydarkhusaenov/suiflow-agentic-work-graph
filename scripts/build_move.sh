#!/bin/bash
set -euo pipefail

export PATH="$HOME/.suiup/bin:$HOME/.local/bin:$PATH"
cd "$(dirname "$0")/../contracts/suiflow"
sui move build
