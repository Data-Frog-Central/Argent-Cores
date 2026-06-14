#!/bin/bash

# Exit immediately if any command fails
set -e

JSON_FILE="cores.json"

# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo "❌ Error: $JSON_FILE not found."
    exit 1
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is required to run this script. Please install it."
    exit 1
fi

if [ ! -d "libretro-common" ]; then
    git clone https://github.com/Data-Frog-Central/libretro-common
    sed -i 's|CFLAGS += -I\.\./\.\.|CFLAGS += -I../include|g' libretro-common/Makefile
fi

if [ "$#" -gt 0 ]; then
    CORES=""
    for TARGET in "$@"; do
        CORE_EXISTS=$(jq -e "has(\"$TARGET\")" "$JSON_FILE" 2>/dev/null || echo "false")
        if [ "$CORE_EXISTS" != "true" ]; then
            echo "Error: Core '$TARGET' not found in $JSON_FILE."
            echo "Available cores: $(jq -r 'keys | join(", ")' "$JSON_FILE")"
            exit 1
        fi
        CORES="$CORES $TARGET"
    done
    echo "Targets set to: $CORES"
else
    CORES=$(jq -r 'keys[]' "$JSON_FILE")
    echo "No targets specified. Processing all configured cores..."
fi

for CORE in $CORES; do
    echo "========================================="
    echo " Processing: $CORE"
    echo "========================================="

    # 1. Extract Mandatory Keys (with fallback to empty string if missing)
    SOURCE=$(jq -r ".\"$CORE\".source // \"\"" "$JSON_FILE")
    DIRECTORY=$(jq -r ".\"$CORE\".directory // \"\"" "$JSON_FILE")
    MAKEFILE_DIRECTORY=$(jq -r ".\"$CORE\".makefile_directory // \"\"" "$JSON_FILE")
    BRANCH=$(jq -r ".\"$CORE\".branch // \"master\"" "$JSON_FILE") # defaults to master
    OUTPUT=$(jq -r ".\"$CORE\".output // \"\"" "$JSON_FILE")

    # Guard Clause: Validation for required fields
    if [ -z "$SOURCE" ] || [ -z "$DIRECTORY" ]; then
        echo "Error: '$CORE' is missing required fields ('source' or 'directory'). Skipping..."
        continue
    fi

    MAKEFILE_DIRECTORY=${MAKEFILE_DIRECTORY:-$DIRECTORY}

    # 2. Git Clone and Checkout Setup
    if [ ! -d "$DIRECTORY" ]; then
        echo "--> Cloning repository..."
        git clone --recursive --shallow-submodules "$SOURCE" "$DIRECTORY"

        # Navigate into the target directory
        pushd "$DIRECTORY" > /dev/null

        echo "--> Checking out branch/commit: $BRANCH"
        git checkout "$BRANCH"

        # 3. Run Pre-Make Commands
        # The '// []' fallback guarantees jq returns an array format even if the 'commands' key is completely missing
        PRE_CMD_COUNT=$(jq ".\"$CORE\".commands.\"pre-make\" // [] | length" "../../$JSON_FILE")
        if [ "$PRE_CMD_COUNT" -gt 0 ]; then
            for ((i=0; i<PRE_CMD_COUNT; i++)); do
                CMD=$(jq -r ".\"$CORE\".commands.\"pre-make\"[$i]" "../../$JSON_FILE")
                echo "--> Running pre-make: $CMD"
                eval "$CMD"
            done
        fi
    else 
        # Navigate into the target directory
        pushd "$DIRECTORY" > /dev/null
    fi

    # 4. Parse Makefile config (using defaults if keys are missing)
    MAKEFILE=$(jq -r ".\"$CORE\".make.file // \"Makefile\"" "../../$JSON_FILE")
    MAKE_ARGS=$(jq -r ".\"$CORE\".make.args // \"\"" "../../$JSON_FILE")

    # Build the make execution string cleanly
    MAKE_CMD="cd ../../ && make CORE=$MAKEFILE_DIRECTORY MAKEFILE=-f$MAKEFILE"
    [ -n "$MAKE_ARGS" ] && MAKE_CMD="$MAKE_CMD $MAKE_ARGS"

    echo "--> Executing build: $MAKE_CMD"
    eval "$MAKE_CMD"

    # 5. Run Post-Make Commands
    POST_CMD_COUNT=$(jq ".\"$CORE\".commands.\"post-make\" // [] | length" "$JSON_FILE")
    if [ "$POST_CMD_COUNT" -gt 0 ]; then
        for ((i=0; i<POST_CMD_COUNT; i++)); do
            CMD=$(jq -r ".\"$CORE\".commands.\"post-make\"[$i]" "$JSON_FILE")
            echo "--> Running post-make: $CMD"
            eval "$CMD"
        done
    fi
    
    if [ -n "core.hcrtos" ] && ([ -f "core.hcrtos" ] || [ -n "$(find . -name "core.hcrtos" -print -quit)" ]); then
        diff -q "core.hcrtos" "output/$OUTPUT" || { rm -rf "output/$OUTPUT" && mkdir -p "$(dirname "output/$OUTPUT")" && cp "core.hcrtos" "output/$OUTPUT"; }
    fi

    if [ -n "$OUTPUT" ] && ([ -f "$OUTPUT" ] || [ -n "$(find . -name "$OUTPUT" -print -quit)" ]); then
        echo "Successfully built: $OUTPUT"
    else
        echo "Build step finished. Output tracking skipped or file not found."
    fi

    # Return to starting folder
    popd > /dev/null
done
