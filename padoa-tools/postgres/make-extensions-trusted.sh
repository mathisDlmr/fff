#!/bin/sh

set -e

# List of extensions to make trusted
EXTENSIONS="pg_stat_statements postgis postgis_topology postgis_tiger_geocoder fuzzystrmatch plpgsql uuid-ossp unaccent pg_trgm"

for EXTENSION in $EXTENSIONS; do
    echo "Making $EXTENSION trusted..."

    # Find the control file
    CONTROL_FILE=$(find /usr/share/postgresql -name "${EXTENSION}.control" | head -n 1)

    if [ -z "$CONTROL_FILE" ]; then
        echo "Error: Could not find ${EXTENSION}.control file"
        exit 1
    fi

    echo "Found control file at: $CONTROL_FILE"

    # Backup the original file
    cp "$CONTROL_FILE" "${CONTROL_FILE}.bak"

    # Modify the control file to make it trusted
    sed -i 's/^#trusted = false/trusted = true/' "$CONTROL_FILE"
    if ! grep -q "trusted = true" "$CONTROL_FILE"; then
        echo "trusted = true" >> "$CONTROL_FILE"
    fi

    # Verify the change
    if grep -q "trusted = true" "$CONTROL_FILE"; then
        echo "Successfully made $EXTENSION trusted"
    else
        echo "Error: Failed to modify control file for $EXTENSION"
        # Restore backup
        mv "${CONTROL_FILE}.bak" "$CONTROL_FILE"
        exit 1
    fi
done

echo "All extensions have been made trusted!" 