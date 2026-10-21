#!/usr/bin/env bash
set -euo pipefail

export MIX_ENV=prod

mix deps.get --only prod
mix compile --warnings-as-errors
mix assets.setup
mix assets.deploy
mix release --overwrite
