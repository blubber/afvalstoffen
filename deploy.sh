#!/bin/bash

set -eux

git fetch
git reset --hard origin/main

MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release --overwrite

sudo systemctl restart afvalstoffen.service