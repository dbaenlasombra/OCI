#!/bin/bash

. /home/oracle/.bashrc

AUX_CONN=$1
TARGET_CONN=$2
LOG_FILE_NAME=/tmp/duplicate_pdb_`date +%d_%m_%Y`.log
PDB_NAME=$3
DB_NAME=$4

START_TIME=$(date +%s)

OUTPUT=$(rman auxiliary=$AUX_CONN target=$TARGET_CONN  log=$LOG_FILE_NAME << EOF
  run
    {
    DUPLICATE PLUGGABLE DATABASE ${PDB_NAME} AS ${PDB_NAME} TO ${DB_NAME} FROM ACTIVE DATABASE;
    }
EOF
)
RMAN_STATUS=$?
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $RMAN_STATUS -eq 0 ]; then
  echo "✅  PDB created successfull"
else
  echo "❌ Failed to create PDB"
  echo $OUTPUT
fi

echo "    Elap ${ELAPSED} seg"
exit 1
