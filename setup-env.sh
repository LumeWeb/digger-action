#!/bin/bash

# Function to validate environment variable name
is_valid_env_name() {
    local name="$1"
    [[ $name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

# Function to parse context JSON
# $1: variable name
# $2: should_parse flag (true/false)
parse_context_json() {
    local json_var="$1"
    local should_parse="$2"
    local json_content="${!json_var}"

    if [ -n "$json_content" ]; then
        # Check if content is valid JSON
        if echo "$json_content" | jq empty 2>/dev/null; then
            if [ "$should_parse" = "true" ]; then
                # Parse JSON into individual env vars
                while IFS='=' read -r key value; do
                    if [ -n "$key" ] && is_valid_env_name "$key"; then
                        # Remove quotes from value
                        value="${value%\"}"
                        value="${value#\"}"
                        export "$key=$value"
                    fi
                done < <(echo "$json_content" | jq -r 'to_entries | .[] | .key + "=" + (.value | tostring)')
            else
                # Pass through JSON as-is
                if is_valid_env_name "$json_var"; then
                    export "$json_var=$json_content"
                fi
            fi
        else
            # Not JSON, export as-is
            if is_valid_env_name "$json_var"; then
                export "$json_var=$json_content"
            fi
        fi
    fi
}

# Process SECRETS_CONTEXT - parse into individual vars
parse_context_json "SECRETS_CONTEXT" "true"

# Process VARIABLES_CONTEXT - parse into individual vars
parse_context_json "VARIABLES_CONTEXT" "true"

# Export all regular environment variables
while IFS='=' read -r key value; do
    if [[ "$key" != "SECRETS_CONTEXT" && "$key" != "VARIABLES_CONTEXT" ]]; then
        if is_valid_env_name "$key"; then
            # Pass through all other environment variables
            parse_context_json "$key" "false"
        fi
    fi
done < <(env)

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

# Execute the command passed as arguments
exec "$@"