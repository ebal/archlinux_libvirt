#!/bin/bash
# cleanup.sh - Script to remove unnecessary packages and caches

# Remove orphaned packages
pacman -Qdtq | pacman -Rns --noconfirm - || true

# Clean up pacman cache (--noconfirm would answer the default "N")
yes | pacman -Scc
rm -rf /usr/share/doc/*

# cloud-init cleanup, keep it from running again on next boots
cloud-init clean --logs
touch /etc/cloud/cloud-init.disabled
