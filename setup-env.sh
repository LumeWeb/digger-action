#!/bin/bash

# Function to validate environment variable name
is_valid_env_name() {
    local name="$1"
    # Environment variables must start with letter/underscore and contain only alphanumeric chars and underscores
    [[ $name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# Function to parse JSON and convert to env vars
parse_json_to_env() {
    local json_var="$1"
    local json_content

    # Get the JSON content from environment variable
    json_content="${!json_var}"

    if [ -n "$json_content" ]; then
        # Use jq to parse JSON and convert to env vars
        while IFS='=' read -r key value; do
            # Skip if key is empty
            if [ -z "$key" ]; then
                continue
            fi

            # Validate the key is a valid environment variable name
            if ! is_valid_env_name "$key"; then
                echo "Warning: Skipping invalid environment variable name: $key" >&2
                continue
            fi

            # Remove quotes from the value
            value="${value%\"}"
            value="${value#\"}"

            if [ -n "$key" ]; then
                export "$key=$value"
            fi
        done < <(echo "$json_content" | jq -r 'to_entries | .[] | select(.key != null and .key != "") | .key + "=" + (.value | tostring)')
    fi
}

# Process existing environment variables from other actions
if [ -n "$ENV_CONTEXT" ]; then
    parse_json_to_env "ENV_CONTEXT"
fi

# Process SECRETS_CONTEXT
if [ -n "$SECRETS_CONTEXT" ]; then
    parse_json_to_env "SECRETS_CONTEXT"
fi

# Process VARIABLES_CONTEXT
if [ -n "$VARIABLES_CONTEXT" ]; then
    parse_json_to_env "VARIABLES_CONTEXT"
fi

# Handle TF_VAR_ environment variables
# Get all current environment variables
while IFS='=' read -r key value; do
    if [[ $key == TF_VAR_* ]]; then
        # Extract the variable name part after TF_VAR_
        var_name="${key#TF_VAR_}"
        # Create lowercase version
        lowercase_key="TF_VAR_${var_name,,}"

        # Validate the key
        if ! is_valid_env_name "$lowercase_key"; then
            echo "Warning: Skipping invalid TF_VAR name: $lowercase_key" >&2
            continue
        fi

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