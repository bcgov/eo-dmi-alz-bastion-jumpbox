#!/usr/bin/env bash
# extract-import-target.sh
# Extracts Terraform import target information from Terraform "already exists" errors.
#
# Usage:
#   extract-import-target.sh <terraform_output_file>
#   echo "<terraform_output>" | extract-import-target.sh -
#
# Output (on success):
#   <resource_address>\t<azure_resource_id>
#
# Exit codes:
#   0 - Import target found and printed
#   1 - No importable "already exists" error found
#
# Example:
#   $ ./extract-import-target.sh /tmp/terraform-apply.log
#   module.frontend[0].azurerm_linux_web_app.frontend	/subscriptions/.../providers/Microsoft.Web/sites/myapp

set -euo pipefail

extract_import_target() {
    local input="$1"

    local content
    if [[ "$input" == "-" ]]; then
        content="$(cat)"
    elif [[ -f "$input" ]]; then
        content="$(cat "$input")"
    else
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Terraform error output often includes box-drawing characters such as
    # "│", "╷", and "╵". Strip non-ASCII bytes and CR characters first so the
    # matching logic only sees the stable textual content.
    local normalized_content
    normalized_content="$({
        printf '%s' "$content" |
            tr -d '\r' |
            LC_ALL=C tr -cd '\11\12\40-\176'
    })"

    # Check if this is an "already exists" error
    if ! grep -q "already exists" <<<"$normalized_content"; then
        return 1
    fi

    # Extract the Terraform resource address from "with <address>," line
    # Example: │   with module.frontend[0].azurerm_linux_web_app.frontend,
    local resource_addr
    resource_addr="$({
        grep -m1 -oE 'with [^,]+,' <<<"$normalized_content" |
            sed 's/^with //; s/,$//'
    } || true)"

    # Extract the Azure resource ID from the importable "already exists" error,
    # supporting both the single-line and multiline Terraform output variants.
    local resource_id
    resource_id="$(awk '
        BEGIN {
            awaiting_id = 0
            pending_id = ""
        }

        {
            if ($0 ~ /a resource with the ID/) {
                awaiting_id = 1
                if (match($0, /\/subscriptions\/[^"[:space:]]+/)) {
                    pending_id = substr($0, RSTART, RLENGTH)
                    awaiting_id = 0
                } else {
                    pending_id = ""
                }

                if ($0 ~ /already exists/ && pending_id != "") {
                    print pending_id
                    exit 0
                }
                next
            }

            if (awaiting_id || pending_id != "") {
                if (pending_id == "" && match($0, /\/subscriptions\/[^"[:space:]]+/)) {
                    pending_id = substr($0, RSTART, RLENGTH)
                    awaiting_id = 0
                }

                if ($0 ~ /already exists/ && pending_id != "") {
                    print pending_id
                    exit 0
                }
                next
            }

            if ($0 ~ /already exists/ && match($0, /\/subscriptions\/[^"[:space:]]+/)) {
                print substr($0, RSTART, RLENGTH)
                exit 0
            }
        }
    ' <<<"$normalized_content")"

    if [[ -n "$resource_addr" && -n "$resource_id" ]]; then
        printf '%s\t%s\n' "$resource_addr" "$resource_id"
        return 0
    fi

    return 1
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <terraform_output_file>" >&2
        echo "       $0 -    (read from stdin)" >&2
        exit 1
    fi
    extract_import_target "$1"
fi
