#!/bin/bash
# destroy.sh - destroy the VM stack and remove local tofu files

set -e -u -o pipefail

E_XCD=65
E_DESTROY=69

cd "$(dirname "$0")" || exit $E_XCD

# Optional: load config file with variables (secrets or API keys)
if [ -f tofu.config ]; then
    # shellcheck disable=SC1091
    source tofu.config
fi

if ! tofu destroy -auto-approve; then
    echo "Tofu destroy failed."
    exit $E_DESTROY
fi

# State lives in the consul backend, only local files are removed.
# Keep .terraform.lock.hcl, it is tracked in git.
rm -rf .terraform
rm -f tofu.out
