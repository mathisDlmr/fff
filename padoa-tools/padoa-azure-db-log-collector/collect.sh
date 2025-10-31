#!/bin/bash

set -e

## EXAMPLES ENV VARS
########################################
# PG_SERVERS="resource_group1.server1 resource_group1.server2 resource_group2.server1"
# SP_USER="http://filebeat"
# SP_PASSWORD="My5up3rp4Ss!"
# SP_TENANT="555'
########################################

az login --service-principal -u "$SP_USER" -p "$SP_PASSWORD" --tenant "$SP_TENANT"


while true; do
    for RG_SERVER in $PG_SERVERS; do

        RG_SERV=()
        readarray -d '.' -t RG_SERV < <(printf '%s' "$RG_SERVER")

        RESOURCE_GROUP=${RG_SERV[0]}
        SERVER=${RG_SERV[1]}

        LOGFILES=$(az postgres flexible-server server-logs list --resource-group "$RESOURCE_GROUP" --server "$SERVER"  --file-last-written 3 | jq -c '.[]')

        for FILEINFO in $LOGFILES; do

            FILENAME=$(echo "$FILEINFO" | jq -r '.name');
            FILESIZE=$(echo "$FILEINFO" | jq -r '.sizeInKb');

            if ([ ! -f /tmp/"$SERVER"."$FILENAME" ] || [ $(du /tmp/"$SERVER"."$FILENAME" | awk '{print $1}') -lt "$FILESIZE" ]); then

                echo "Downloading $FILENAME..."

                az postgres flexible-server server-logs download --name "$FILENAME" --resource-group "$RESOURCE_GROUP" --server "$SERVER" &
                pid=$!
                sleep 30

                if kill $pid > /dev/null 2>&1; then
                    echo "[ERROR] Download failed $FILENAME: timed out"
                    continue
                fi


                if [ ! -f /tmp/"$SERVER"."$FILENAME" ]; then
                    mv "$FILENAME" /tmp/"$SERVER"."$FILENAME"
                else
                    comm -23 "$FILENAME" /tmp/"$SERVER"."$FILENAME" >> /tmp/"$SERVER"."$FILENAME"
                    rm "$FILENAME"
                fi

                echo "Download finished"
            fi
        done
    done
    find /tmp -name '*.log' -mtime +3 | xargs rm -f || true
    sleep 5;
done
