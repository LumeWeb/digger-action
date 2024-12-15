#!/bin/bash

# Function to validate environment variable name
is_valid_env_name() {
    local name="$1"
    [[ $name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# Function to parse JSON string and attempt to extract key-value pairs
parse_json_to_env() {
    local var_name="$1"
    local json_content="${!var_name}"

    if [ -n "$json_content" ]; then
        # First, try to parse as JSON
        if echo "$json_content" | jq empty 2>/dev/null; then
            # It's valid JSON, export it as a whole
            export "$var_name=$json_content"
            echo "Processed JSON: $var_name"
        else
            # Not JSON, process as regular key=value pairs
            echo "$json_content" | while IFS='=' read -r key value; do
                if [ -n "$key" ] && is_valid_env_name "$key"; then
                    export "$key=$value"
                    echo "Processed key: $key"
                fi
            done
        fi
    fi
}

# Process SECRETS_CONTEXT
if [ -n "$SECRETS_CONTEXT" ]; then
    parse_json_to_env "SECRETS_CONTEXT"
fi

# Process VARIABLES_CONTEXT
if [ -n "$VARIABLES_CONTEXT" ]; then
    parse_json_to_env "VARIABLES_CONTEXT"
fi

# Handle TF_VAR_ environment variables
while IFS='=' read -r key value; do
    if [[ $key == TF_VAR_* ]]; then
        var_name="${key#TF_VAR_}"
        lowercase_key="TF_VAR_${var_name,,}"

        if [ -z "${!lowercase_key}" ] && is_valid_env_name "$lowercase_key"; then
            export "$lowercase_key=$value"
        fi
    fi
done < <(env)

# If digger-spec is provided, export it
if [ -n "$INPUT_DIGGER_SPEC" ]; then
    export DIGGER_RUN_SPEC="$INPUT_DIGGER_SPEC"
fi

# Export all environment variables from env
while IFS='=' read -r key value; do
    if is_valid_env_name "$key"; then
        export "$key=$value"
    fi
done < <(env)

# Execute the command passed as arguments
exec "$@"