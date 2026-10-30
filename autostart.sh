#!/bin/bash
# autostart.sh - init, format, validate, plan and apply the VM stack

set -e -u -o pipefail

E_XCD=65
E_INIT=66
E_VALIDATE=67
E_APPLY=68

cd "$(dirname "$0")" || exit $E_XCD

# Optional: load config file with variables (secrets or API keys)
# eg. export TF_VAR_password_hash='$6$...'
if [ -f tofu.config ]; then
    # shellcheck disable=SC1091
    source tofu.config
fi

# .terraform/terraform.tfstate holds the backend config, a bare .terraform/
# (eg. from 'tofu init -backend=false') is not enough
if [ -f .terraform/terraform.tfstate ]; then
    echo "Tofu already initialized."
else
    echo "Initializing Tofu..."
    tofu init -input=false || exit $E_INIT
fi

tofu fmt -recursive

tofu validate || exit $E_VALIDATE

# Only apply if plan succeeds
tofu plan -input=false -out tofu.out || exit $E_APPLY
tofu apply -auto-approve tofu.out || exit $E_APPLY
