#!/bin/bash

# Function to parse JSON and convert to env vars
parse_json_to_env() {
    local json_var="$1"
    local json_content

    # Get the JSON content from environment variable
    json_content="${!json_var}"

    if [ -n "$json_content" ]; then
        # Use jq to parse JSON and convert to env vars
        while IFS='=' read -r key value; do
            # Remove quotes from the value and export
            value="${value%\"}"
            value="${value#\"}"
            export "$key=$value"
        done < <(echo "$json_content" | jq -r 'to_entries | .[] | .key + "=" + (.value | tostring)')
    fi
}

# Process SECRETS_CONTEXT
parse_json_to_env "SECRETS_CONTEXT"

# Process VARIABLES_CONTEXT
parse_json_to_env "VARIABLES_CONTEXT"

# Handle TF_VAR_ environment variables
# Get all current environment variables
while IFS='=' read -r key value; do
    if [[ $key == TF_VAR_* ]]; then
        # Extract the variable name part after TF_VAR_
        var_name="${key#TF_VAR_}"
        # Create lowercase version
        lowercase_key="TF_VAR_${var_name,,}"

        # Only set if lowercase version doesn't exist
        if [ -z "${!lowercase_key}" ]; then
            export "$lowercase_key=$value"
        fi
    fi
done < <(env)

# If digger-spec is provided, export it
if [ -n "$INPUT_DIGGER_SPEC" ]; then
    export DIGGER_RUN_SPEC="$INPUT_DIGGER_SPEC"
fi

# Execute the command passed as arguments
exec "$@"