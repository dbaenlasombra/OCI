###############################################################################################################
# DAVID SANZ MACIAS
#     Parameters:
#              $1 IP SOURCE
#              $2 PDB NAME SOURCE
#              $3 PASS TDE
###############################################################################################################
#!/bin/bash


if [ "$#" -ne 3 ]; then
  echo " $0 <SOURCE_IP> <PDB_NAME> <PASS_TDE>"
  exit 1
fi

SOURCE=$1
PDB_NAME=$2
PASS_TDE=$3
RUTA=/home/oracle

. ${RUTA}/.bashrc

START_TIME_SH=$(date +%s)

gen_name(){
  tr -dc 'A-Za-z' </dev/urandom | head -c 5 | tr '[:lower:]' '[:upper:]'
}

gen_pass() {
  PASS=$(tr -dc 'a-z' </dev/urandom | head -c 5)$(tr -dc 'A-Z' </dev/urandom | head -c 2)
  NUM=$(tr -dc '0-9' </dev/urandom | head -c 2)
  SPEC=$(tr -dc '!@#$%' </dev/urandom | head -c 2)
  echo "${PASS}${NUM}${SPEC}"
}

drop_user(){
START_TIME=$(date +%s)
## Drop User in Source
OUTPUT=$(ssh -Ti "${RUTA}/.ssh/id_rsa" "oracle@${SOURCE}" <<EOF
sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
set heading off feedback off pagesize 0
Drop user ${USER_CLONE} cascade;
exit;
SQL
EOF
)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if [ $? -ne 0 ]; then
  echo "❌ Failed to drop common user ${USER_CLONE}"
  echo "$OUTPUT"
  exit 1
else
  echo "✅  common user ${USER_CLONE} dropped successfull"
  echo "    Elap ${ELAPSED} seg"
fi

}

drop_dblink(){

START_TIME=$(date +%s)
## Generate DBLink in Target
OUTPUT=$(sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
set heading off feedback off pagesize 0
drop database link ${DB_NAME};
exit;
SQL
)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if echo "$OUTPUT" | grep -q "ORA-"; then
  echo "❌ Failed to drop DBLink ${DB_NAME}"
  echo "$OUTPUT"
  exit 1
else
  echo "✅  DBLink ${DB_NAME} dropped successfull"
  echo "    Elap ${ELAPSED} seg"
fi
}

USER_CLONE="C##TMPC"$(gen_name)
PASS_CLONE=$(gen_pass)
DB_NAME="SOURCE_"$(gen_name)

echo ${USER_CLONE}
echo ${PASS_CLONE}

START_TIME=$(date +%s)
## Generate User in Source
OUTPUT=$(ssh -Ti "${RUTA}/.ssh/id_rsa" "oracle@${SOURCE}" <<EOF
sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
set heading off feedback off pagesize 0
Create user ${USER_CLONE} identified by "${PASS_CLONE}";
GRANT CREATE SESSION, RESOURCE, CREATE ANY TABLE, UNLIMITED TABLESPACE TO ${USER_CLONE} CONTAINER=ALL;
GRANT CREATE PLUGGABLE DATABASE TO ${USER_CLONE} CONTAINER=ALL;
GRANT SYSOPER TO ${USER_CLONE} CONTAINER=ALL;
exit;
SQL
EOF
)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if echo "$OUTPUT" | grep -q "ORA-"; then
  echo "❌ Failed to create common user ${USER_CLONE}"
  echo "$OUTPUT"
  exit 1
else
  echo "✅  common user ${USER_CLONE} successfull"
  echo "    Elap ${ELAPSED} seg"
fi

START_TIME=$(date +%s)
## Generate DBLink in Target
OUTPUT=$(sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
set heading off feedback off pagesize 0
create database link ${DB_NAME} connect to ${USER_CLONE} identified by "${PASS_CLONE}" using 'SOURCE';
exit;
SQL
)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if echo "$OUTPUT" | grep -q "ORA-"; then
  echo "❌ Failed to create DBLink ${DB_NAME}"
  echo "$OUTPUT"
  exit 1
else
  echo "✅  DBLink ${DB_NAME} created successfull"
  echo "    Elap ${ELAPSED} seg"
fi

## Create PDB in Target
OUTPUT=$(sqlplus -s / as sysdba <<SQL
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
set heading off feedback off pagesize 0
 CREATE PLUGGABLE DATABASE ${PDB_NAME} FROM ${PDB_NAME}@${DB_NAME}  keystore identified by "${PASS_TDE}" including shared key ;
exit;
SQL
)
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

if echo "$OUTPUT" | grep -q "ORA-"; then
  echo "❌ Failed to create PDB ${PDB_NAME}"
  echo $OUTPUT
  drop_user
  drop_dblink
  exit 1
else
  echo "✅  PDB ${PDB_NAME} created successfull"
  echo "    Elap ${ELAPSED} seg"
fi

drop_user
drop_dblink


END_TIME_SH=$(date +%s)
ELAPSED=$((END_TIME_SH - START_TIME_SH))

echo "   sh Elap ${ELAPSED} seg"
