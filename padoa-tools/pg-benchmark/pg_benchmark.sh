#!/bin/bash

#
# Data Bene - PostgreSQL & Linux Data Colector, Analyzer and Reporter
# 
# This tool is intended for use by our customers.
# Please read man pg_benchmark for further details
#
#

# FROM PADOA
# Run script from directory where the script is stored.
cd "$( dirname "${BASH_SOURCE[0]}" )"
# END FROM PADOA

VERSION=0.1


# TODO: version management
# TODO: unit testing
# TODO: doc man page
# TODO: pg system identification

#set -ex


EXIT_OK=0
EXIT_FATAL=1
EXIT_PGFATAL=2


RUN_TS=`date '+%s'`
RUN_HMS=`date --date @$RUN_TS '+%Y%m%d%H%M%S'`


# TODO: version management

#
# Print Version
#

PrintVersion() {
   echo "pg_benchmark version $VERSION"
}

#
# Usage
#

PrintUsage() {
   echo "Please consult the pg_benchmark man page (man pg_benchmark) for further explanations"
}


PrintMessage() {

   echo -e "$1\t$2" > /dev/stderr

}




###-------------------------------------------------------------------------###
### TEST ZONE                                                               ###



###############################################################################
# LINUX PROBES ################################################################
###############################################################################


#
# Collect OS Version
# Requirements: COLLECT_SYSTEM=true
# Modificators:
#

collect_linux_os_version() {


   local title='Collecting Linux OS Information'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      os_release=$(grep 'PRETTY_NAME=' /etc/*-release | tr -d '"' | cut -d '=' -f2)
      echo "linux.os.name.pretty=$os_release" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.os.name.pretty=$os_release"

      os_kernel=$(uname -r)
      echo "linux.os.kernel=$os_kernel" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.os.kernel=$os_kernel"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}
   


#
# Collect Linux CPU Information
# Requirements: COLLECT_SYSTEM=true
# Modificators:
#

collect_linux_cpu() {

   local title='Collecting CPU Information'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local info=`grep '^model name' /proc/cpuinfo`
      local model=`echo "$info" | head -n 1 | cut -d ':' -f2`
      local count=`echo "$info" | wc -l`

      echo "linux.cpu.count=$count" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.cpu.count=$count"
      echo "linux.cpu.model=${model:1}" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.cpu.model=${model:1}"

      governor="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
      [ "$governor" == '' ] && governor='virtualized'
      echo "linux.cpu.governor=$governor" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.cpu.governor=$governor"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Collect Linux Memory Information
# Requirements: COLLECT_SYSTEM=true
# Modificators:
#

collect_linux_mem() {

   local title='Collecting Memory Information'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

#      cat /proc/meminfo | \
#          tr ':' '='| tr -d ' ' | sed 's/kB$//' | \
#          sed 's/^/linux\.meminfo\./' >> $METRICS_OUTPUT

      # Higly inefficient due to Verbose mode support
      while read line
      do
         local key='linux.meminfo.'$(echo "$line" | cut -d '=' -f1)
         local val=$(echo "$line" | cut -d '=' -f2)
         [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "$key=$val"
         echo "$key=$val" >> $METRICS_OUTPUT
      done < <(cat /proc/meminfo | tr ':' '='| tr -d ' ' | sed 's/kB$//')


      # Transparent huge pages
      info=`cat /sys/kernel/mm/transparent_hugepage/enabled | cut -d '[' -f2 | cut -d ']' -f1`
      echo "linux.other.mm.transparent_hugepage.enabled=$info" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.other.mm.transparent_hugepage.enabled=$info"


   else 
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Collect Linux sysctl Information
# Requirements: COLLECT_SYSTEM=true
# Modificators:
#

collect_linux_sysctl() {

   local title='Collecting Kernel Parameters'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

#      sysctl -a 2>/dev/null | \
#             tr -d ' ' | grep -E '^kernel|^vm' |\
#             sed 's/^/linux\.sysctl\./' >> $METRICS_OUTPUT

      # Higly inefficient due to Verbose mode support
      while read line
      do
         local key='linux.sysctl.'$(echo "$line" | cut -d '=' -f1)
         local val=$(echo "$line" | cut -d '=' -f2)
         [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "$key=$val"
         echo "$key=$val" >> $METRICS_OUTPUT
      done < <(sysctl -a 2>/dev/null | tr -d ' ' | grep -E '^kernel|^vm')

   else 
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi



}


   
#
# Collect Linux Disk Information
# Requirements: COLLECT_SYSTEM=true
# Modificators:
#

collect_linux_disks() {

   local title='Collecting Disk Information'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      while read entry
      do

         local dev=`echo "$entry"| tr -s ' ' | cut -d ' ' -f1`
         local siz=`echo "$entry"| tr -s ' ' | cut -d ' ' -f4`
         echo "benchmark.meta.linux.host.disk.""$dev""=""$siz" >> $METRICS_OUTPUT
         [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "benchmark.meta.linux.host.disk.""$dev""=""$siz"

      done < <(lsblk | grep '^[hs]d[a-z]')


      # Get read_ahead for each disk unit
      while read entry
      do

         local ra=$(sudo blockdev --getra $entry)
         local dev=$(echo "$entry" | cut -d '/' -f3)
         echo "benchmark.meta.linux.host.disk.""$dev"".read_ahead=""$ra" >> $METRICS_OUTPUT
         [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "benchmark.meta.linux.host.disk.""$dev"".read_ahead=""$ra"


      done < <(ls -1 /dev/[hs]d*)




      nobarrier_count=$(mount -l | grep 'nobarrier' | wc -l)
      echo "linux.fs.nobarrier.count=$nobarrier_count" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'COLLECT' "linux.fs.nobarrier.count=$nobarrier_count"


   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



###############################################################################
# POSTGRES PROBES #############################################################
###############################################################################

#$1 datname

function collect_postgres_definitions() {

  [ "$#" != 1 ] && echo 'collect_postgres_definitions: ERROR wrong number of args' && exit 1

  local rc=
  local output=

  # How to reach PostgreSQL
  local  PSQL_SUDO=
  local  PSQL_CONNINFO=
  local cmd=

  if [ "$PG_HOST" == "" ]; then

      # Local Unix Connection
      PSQL_SUDO='sudo -iu postgres'
      PSQL_SUDO=''
      PSQL_CONNINFO="--dbname=$1 --port=$PG_PORT"

   else

      # Remote Connection (RDS like)
      PSQL_CONNINFO="--host=$PG_HOST --port=$PG_PORT --username=$PG_USER --dbname=$1"

   fi

   cmd="$PSQL_SUDO pg_dump --schema-only $PSQL_CONNINFO"

  [ "$VERBOSE" -gt 2 ] && PrintMessage 'DEBUG' "QueryExec >> $cmd"

  output=$(eval "$cmd > $METRICS_FOLDER/$1.sql")
  rc=$?

  [ "$VERBOSE" -gt 2 ] && PrintMessage 'DEBUG' "QueryExec >> Return Code = $rc, Result = $output"

  [ "$rc" != 0 ] && exit $EXIT_PGFATAL

}


#$1 datname
#$2 query

function QueryExec() {

  [ "$#" != 2 ] && echo 'QueryExec: ERROR wrong number of args' && exit 1

  local rc=
  local output=

  # How to reach PostgreSQL
  local  PSQL_SUDO=
  local  PSQL_CONNINFO=
  local  PSQL_OPTIONS="-qAtc"
  local cmd=

  if [ "$PG_HOST" == "" ]; then

      # Local Unix Connection
      PSQL_SUDO='sudo -iu postgres'
      PSQL_SUDO=''
      PSQL_CONNINFO="'dbname=$1 port=$PG_PORT'"

   else

      # Remote Connection (RDS like)
      PSQL_CONNINFO="'host=$PG_HOST port=$PG_PORT user=$PG_USER dbname=$1'"

   fi

   cmd="$PSQL_SUDO psql $PSQL_CONNINFO $PSQL_OPTIONS \"$2\""

  [ "$VERBOSE" -gt 2 ] && PrintMessage 'DEBUG' "QueryExec >> $cmd"

  output=$(eval "$cmd")
  rc=$?

  [ "$VERBOSE" -gt 2 ] && PrintMessage 'DEBUG' "QueryExec >> Return Code = $rc, Result = $output"

  [ "$rc" != 0 ] && exit $EXIT_PGFATAL

  echo "$output"

}




###--- Query Factory -------------------------------------------------------###

#
# Queries are static so build once use many times
# Modify QUERY_* vars
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#


function QueryFactory() {

   local server_version="$1"
   local query=''


   ###--- Cluster Level Information Queries --------------------------------###

   # Cluster Description
   query="
   SELECT 
      '$(hostname)' AS hostname,
      pg_catalog.version(),
      pg_catalog.current_setting('port') AS port,
      current_setting('data_directory') AS data_directory,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE txid_current() END) AS txid_current,
      txid_current_snapshot() AS txid_current_snapshot,
      txid_snapshot_xmin(txid_current_snapshot()) AS txid_snapshot_xmin,
      txid_snapshot_xmax(txid_current_snapshot()) AS txid_snapshot_xmax,
      current_timestamp AS current_timestamp,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_lsn() END) AS wal_lsn,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_insert_lsn() END) AS wal_insert_lsn,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_flush_lsn() END) AS wal_flush_lsn,
      pg_catalog.pg_postmaster_start_time() AS postmaster_start_time,
      pg_conf_load_time() AS conf_load_time,
      pg_is_in_recovery() AS is_in_recovery,
      false AS is_rds"

   if [ $server_version -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_wal_lsn/pg_current_xlog_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_insert_lsn/pg_current_xlog_insert_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_flush_lsn/pg_current_xlog_flush_location/g')

   fi

   if [ $server_version -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_xlog_flush_location()/NULL/g')

   fi

   QUERY_CLUSTER_GENERAL_INFO="$query"



   # Tablespaces
   query="
   SELECT 
      oid,
      spcname,
      spcowner,
      spcacl,
      spcoptions AS spcoptions,
      CASE pg_tablespace_location(oid)
           WHEN '' THEN current_setting('data_directory')
           ELSE pg_tablespace_location(oid)
      END AS spclocation,
      pg_catalog.pg_tablespace_size(oid) AS spcsize
   FROM pg_catalog.pg_tablespace"

   QUERY_TABLESPACES="$query"



   # Settings
   query="
   SELECT 
      name,
      current_setting(name),
      source,
      setting,
      boot_val AS boot_val,
      reset_val AS reset_val,
      sourcefile AS sourcefile,
      sourceline AS sourceline,
      pending_restart AS pending_restart
   FROM pg_catalog.pg_settings "

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/pending_restart/NULL/g')

   fi

   QUERY_SETTINGS="$query"



   # Roles
   query="
   SELECT 
      oid,
      rolname,
      rolsuper,
      rolinherit,
      rolcreaterole,
      rolcreatedb,
      true AS rolcatupdate,
      rolcanlogin,
      rolreplication AS rolreplication,
      rolconnlimit,
      rolvaliduntil,
      rolbypassrls AS rolbypassrls,
      rolconfig
   FROM pg_catalog.pg_roles "

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/rolbypassrls/NULL/g')

   fi

   QUERY_ROLES="$query"



   # Databases
   query="
   SELECT 
      oid,
      datname,
      pg_stat_get_db_numbackends(oid) AS numbackends,
      datdba,
      encoding,
      datcollate AS datcollate,
      datctype AS datctype,
      dattablespace,
      datistemplate,
      datallowconn,
      datconnlimit,
      datlastsysoid,
      CASE WHEN pg_catalog.has_database_privilege(oid, 'CONNECT')
           THEN pg_catalog.pg_database_size(oid)
           ELSE NULL
      END AS datsize,
      datfrozenxid,
      age(datfrozenxid) AS datage,
      datminmxid AS datminmxid,
      mxid_age(datminmxid) AS datminmxid_age,
      datacl,
      pg_catalog.pg_stat_get_db_xact_commit(oid) AS xact_commit,
      pg_catalog.pg_stat_get_db_xact_rollback(oid) AS xact_rollback,
      pg_catalog.pg_stat_get_db_blocks_fetched(oid) - pg_catalog.pg_stat_get_db_blocks_hit(oid) AS blks_read,
      pg_catalog.pg_stat_get_db_blocks_hit(oid) AS blks_hit,
      pg_stat_get_db_tuples_returned(oid) AS tup_returned,
      pg_stat_get_db_tuples_fetched(oid) AS tup_fetched,
      pg_stat_get_db_tuples_inserted(oid) AS tup_inserted,
      pg_stat_get_db_tuples_updated(oid) AS tup_updated,
      pg_stat_get_db_tuples_deleted(oid) AS tup_deleted,
      pg_stat_get_db_conflict_all(oid) AS conflicts,
      pg_stat_get_db_temp_files(oid) AS temp_files,
      pg_stat_get_db_temp_bytes(oid) AS temp_bytes,
      pg_stat_get_db_deadlocks(oid) AS deadlocks,
      pg_stat_get_db_blk_read_time(oid) AS blk_read_time,
      pg_stat_get_db_blk_write_time(oid) AS blk_write_time,
      pg_stat_get_db_conflict_tablespace(oid) AS confl_tablespace,
      pg_stat_get_db_conflict_lock(oid) AS confl_lock,
      pg_stat_get_db_conflict_snapshot(oid) AS confl_snapshot,
      pg_stat_get_db_conflict_bufferpin(oid) AS confl_bufferpin,
      pg_stat_get_db_conflict_startup_deadlock(oid) AS confl_deadlock,
      pg_stat_get_db_stat_reset_time(oid) AS stats_reset
     ,now() AS ts_snapshot
     ,now() - pg_stat_get_db_stat_reset_time(oid) AS elapsed_interval
     ,extract( 'epoch' from now() - pg_stat_get_db_stat_reset_time(oid) )::bigint AS elapsed_seconds 
   FROM pg_catalog.pg_database
   WHERE datname NOT IN ('template0', 'template1') "


   if [ $server_version -ge 150000 ]; then

      query=$(echo "$query" | sed -e 's/datlastsysoid/NULL/g')

   fi


   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/mxid_age(datminmxid)/NULL/g')

   fi

   if [ $server_version -lt 90300 ]; then

      query=$(echo "$query" | sed -e 's/datminmxid /NULL /g')

   fi

   QUERY_DATABASES="$query"



   # Database / Role Settings
   query="
   SELECT 
         coalesce(role.rolname, 'database wide') as role,
         coalesce(db.datname, 'cluster wide') as database,
         setconfig as what_changed
   FROM pg_db_role_setting role_setting
   LEFT JOIN pg_roles role ON role.oid = role_setting.setrole
   LEFT JOIN pg_database db ON db.oid = role_setting.setdatabase "

   QUERY_DB_ROLE_SETTINGS="$query"



   # Archiver
   QUERY_ARCHIVER=""

   if [ $server_version -ge 90400 ]; then

      query="
      SELECT 
         current_database() AS datname,
         stats_reset,
         now() AS ts_snapshot,
         now() - stats_reset AS elapsed_interval,
         extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds,
         archived_count,last_archived_wal,last_archived_time,
         failed_count, last_failed_wal, last_failed_time
      FROM pg_catalog.pg_stat_archiver "

      QUERY_ARCHIVER="$query"

   fi



   # BgWriter
   query="
   SELECT
      current_database() AS datname,
      stats_reset,
      now() AS ts_snapshot,
      now() - stats_reset AS elapsed_interval,
      extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds,
      checkpoints_timed, checkpoints_req,
      checkpoint_write_time, checkpoint_sync_time,
      buffers_checkpoint, buffers_clean, maxwritten_clean,
      buffers_backend, buffers_backend_fsync, buffers_alloc,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff( pg_current_wal_lsn(), '0/0' ) END) AS lsn_write_bytes,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff( pg_current_wal_flush_lsn(), '0/0' ) END) AS lsn_flush_bytes,
      (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff( pg_current_wal_insert_lsn(), '0/0' ) END ) AS lsn_insert_bytes,
      pg_is_in_recovery() AS recovery,
      (CASE WHEN pg_is_in_recovery() THEN pg_wal_lsn_diff( pg_last_wal_receive_lsn (), '0/0' ) ELSE NULL END ) AS last_wal_receive_bytes,
      (CASE WHEN pg_is_in_recovery() THEN pg_wal_lsn_diff( pg_last_wal_replay_lsn (), '0/0' ) ELSE NULL END ) AS last_wal_replay_bytes 
   FROM pg_catalog.pg_stat_bgwriter "

   if [ $server_version -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/pg_wal_lsn_diff/pg_xlog_location_diff/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_lsn/pg_current_xlog_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_insert_lsn/pg_current_xlog_insert_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_flush_lsn/pg_current_xlog_flush_location/g')

   fi

   if [ $server_version -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_xlog_flush_location()/NULL/g')

   fi

   QUERY_BGWRITER="$query"



   # WAL
   QUERY_WAL=""

   if [ $server_version -ge 140000 ]; then

      query="
      SELECT 
         current_database() AS datname
        ,stats_reset
        ,now() AS ts_snapshot
        ,now() - stats_reset AS elapsed_interval
        ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds
        ,wal_records
        ,wal_fpi
        ,wal_bytes
        ,wal_buffers_full
        ,wal_write
        ,wal_sync
        ,wal_write_time
        ,wal_sync_time
      FROM pg_catalog.pg_stat_wal "

      QUERY_WAL="$query"

   fi




   # Replication
   query="
   SELECT *
   FROM pg_catalog.pg_stat_replication "

   QUERY_REPLICATION="$query"



   # Replication Slots
   query=""
   if [ $server_version -ge 90400 ]; then
      query="
      SELECT 
        slot_name, plugin, slot_type
     , datoid, database, temporary, active, active_pid
     , xmin AS slot_xmin
     , catalog_xmin, restart_lsn, confirmed_flush_lsn, wal_status, safe_wal_size, two_phase 
      FROM pg_catalog.pg_replication_slots "
   fi

   if [ $server_version -lt 150000 ]; then

      query=$(echo "$query" | sed -e 's/two_phase/NULL/g')

   fi



   QUERY_REPLICATION_SLOTS="$query"


   # REPLICATION LEFT JOIN REPLICATION_SLOTS
   ###


   # Used Extensions
   query="
   SELECT
      extname
     ,extversion
     ,extowner
     ,extnamespace
     ,extrelocatable
     ,extconfig
     ,extcondition
   FROM pg_catalog.pg_extension
   ORDER BY 1"

   QUERY_EXTENSION_USED="$query"



   # Available Extensions
   query="
   SELECT
      V.name
     ,V.version
     ,E.default_version
     ,V.superuser
     ,V.relocatable
     ,V.schema
     ,V.requires
     ,V.comment
   FROM pg_catalog.pg_available_extension_versions V
   JOIN pg_catalog.pg_available_extensions E ON E.name = V.name "

   QUERY_EXTENSION_AVAILABLE="$query"



   # Schemas
   query="
   SELECT
      current_database() AS datname
     ,NULL
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds
     ,n.oid AS nspoid
     ,d.oid AS datoid
     ,n.nspname
     ,n.nspowner
     ,n.nspacl
   FROM
      pg_catalog.pg_namespace n,
      pg_catalog.pg_database d
   WHERE n.nspname <> 'information_schema'
   ORDER BY d.datname, n.nspname"

   QUERY_SCHEMAS="$query"



   ###--- Database Level Information ---------------------------------------###

   # Tables
   query="
   SELECT
      current_database() AS datname
     ,NULL as stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      c.oid AS reloid,
      d.oid AS datoid,
      n.oid AS nspoid,
      c.relname,
      c.reltablespace,
      c.relowner,
      pg_relation_filenode(c.oid) AS relfilenode,
      pg_catalog.pg_relation_size(c.oid) AS relsize,
      pg_catalog.pg_total_relation_size(c.oid) AS relsize_total,
      c.relpages,
      c.reltuples,
      c.relallvisible AS relallvisible,
      c.relhasindex,
      c.relpersistence AS relpersistence,
      c.relnatts,
      c.relchecks,
      NULL AS relhasoids,
      NULL AS relhaspkey,
      c.relhasrules,
      c.relhastriggers AS relhastriggers,
      c.relhassubclass,
      c.relrowsecurity AS relrowsecurity,
      c.relforcerowsecurity AS relforcerowsecurity,
      c.relreplident AS relreplident,
      c.relfrozenxid,
      age(c.relfrozenxid) AS relfrozenxid_age,
      c.relminmxid AS relminmxid,
      mxid_age(c.relminmxid) AS relminmxid_age,
      c.relacl,
      c.reloptions,
      s.seq_scan,
      s.seq_tup_read,
      s.idx_scan,
      s.idx_tup_fetch,
      pg_catalog.pg_stat_get_tuples_fetched(c.oid) AS n_tup_fetch,
      s.n_tup_ins,
      s.n_tup_upd,
      s.n_tup_del,
      s.n_tup_hot_upd AS n_tup_hot_upd,
      s.n_live_tup AS n_live_tup,
      s.n_dead_tup AS n_dead_tup,
      s.n_mod_since_analyze AS n_mod_since_analyze,
      s2.heap_blks_read,
      s2.heap_blks_hit,
      s2.idx_blks_read,
      s2.idx_blks_hit,
      s2.toast_blks_read,
      s2.toast_blks_hit,
      s2.tidx_blks_read,
      s2.tidx_blks_hit,
      s.last_vacuum,
      s.last_autovacuum,
      s.last_analyze,
      s.last_autoanalyze,
      s.vacuum_count AS vacuum_count,
      s.autovacuum_count AS autovacuum_count,
      s.analyze_count AS analyze_count,
      s.autoanalyze_count AS autoanalyze_count,
      c.relispartition AS relispartition,
      NULLIF(ARRAY(SELECT i.inhparent
             FROM pg_catalog.pg_inherits i
             WHERE i.inhrelid=c.oid
             ORDER BY i.inhseqno), '{}') AS inhparents
   FROM
      pg_catalog.pg_database d,
      pg_catalog.pg_class c
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_catalog.pg_stat_user_tables s ON s.relid = c.oid
      LEFT JOIN pg_catalog.pg_statio_user_tables s2 ON s2.relid = c.oid
   WHERE d.datname = current_database()
     AND (c.relkind = 'r'::char OR c.relkind = 'p'::char)
     AND n.nspname <> 'information_schema'
   ORDER BY d.datname, n.nspname, s.relname "

   if [ $server_version -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/c.relispartition/NULL/g')

   fi

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/c.relrowsecurity/NULL/g')
      query=$(echo "$query" | sed -e 's/c.relforcerowsecurity/NULL/g')
      query=$(echo "$query" | sed -e 's/mxid_age(c.relminmxid)/NULL/g')

   fi

   if [ $server_version -lt 90400 ]; then

      query=$(echo "$query" | sed -e 's/c.relreplident/NULL/g')
      query=$(echo "$query" | sed -e 's/s.n_mod_since_analyze/NULL/g')

   fi


   if [ $server_version -lt 90300 ]; then

      query=$(echo "$query" | sed -e 's/c.relminmxid/NULL/g')
      query=$(echo "$query" | sed -e 's/mxid_age(c.relminmxid)/NULL/g')

   fi

   QUERY_TABLES="$query"



   # Partitioned Tables
   query="
   SELECT 
      current_database() AS datname
     ,NULL
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      p.partrelid AS partrelid,
      p.partstrat AS partstrat,
      p.partattrs AS partattrs,
      p.partclass AS partclass,
      p.partcollation AS partcollation,
      p.partdefid AS partdefid,
      pg_get_partkeydef(p.partrelid) AS partdesc
   FROM pg_partitioned_table p "


   if [ $server_version -lt 110000 ]; then

      query=$(echo "$query" | sed -e 's/p.partdefid/NULL/g')
   fi

   [ $server_version -lt 100000 ] && query=""


   QUERY_TABLE_PARTIONED="$query"



   # Indexes
   query="
   SELECT 
      current_database() AS datname
     ,NULL AS stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      i.oid AS idxoid,
      d.oid AS datoid,
      n.oid AS nspoid,
      c.oid AS reloid,
      i.relname,
      a.amname,
      i.reltablespace,
      i.relowner,
      pg_relation_filenode(i.oid) AS relfilenode,
      i.relpages,
      i.reltuples,
      i.relpersistence AS relpersistence,
      i.relnatts,
      i.reloptions,
      x.indisunique,
      x.indisprimary,
      x.indisexclusion AS indisexclusion,
      x.indimmediate AS indimmediate,
      x.indisclustered,
      x.indisvalid,
      x.indisready AS indisready,
      x.indcheckxmin AS indcheckxmin,
      x.indislive AS indislive,
      x.indisreplident AS indisreplident,
      x.xmin AS idx_xmin,
      pg_catalog.pg_get_indexdef(i.oid) AS indexdef,
      pg_catalog.pg_relation_size(i.oid) AS idxsize,
      pg_catalog.pg_stat_get_blocks_fetched(i.oid) - pg_catalog.pg_stat_get_blocks_hit(i.oid) AS idx_blks_read,
      pg_catalog.pg_stat_get_blocks_hit(i.oid) AS idx_blks_hit,
      s.idx_scan,
      s.idx_tup_read,
      s.idx_tup_fetch
   FROM pg_catalog.pg_database d,
        pg_catalog.pg_index x
   JOIN pg_catalog.pg_class c ON c.oid = x.indrelid
   JOIN pg_catalog.pg_class i ON i.oid = x.indexrelid
   LEFT JOIN pg_catalog.pg_stat_user_indexes s ON s.indexrelid = x.indexrelid
   LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
   LEFT JOIN pg_catalog.pg_am a ON a.oid = i.relam
   WHERE d.datname = current_database()
    AND (c.relkind = 'r'::char OR c.relkind = 'p'::char)
    AND (i.relkind = 'i'::char OR i.relkind = 'I'::char)
    AND n.nspname <> 'information_schema' "

   if [ $server_version -lt 90400 ]; then

      query=$(echo "$query" | sed -e 's/x.indisreplident/NULL/g')

   fi

   if [ $server_version -lt 90300 ]; then

      query=$(echo "$query" | sed -e 's/x.indislive/NULL/g')

   fi

   QUERY_INDEXES="$query"



   # Attributes
   query="
   SELECT
      current_database() AS datname
     ,NULL AS stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      A.attrelid,
      A.attname,
      A.attnum,
      A.atttypid,
      A.attstattarget,
      A.attlen,
      A.attndims,
      A.atttypmod,
      A.attbyval,
      A.attstorage,
      A.attalign,
      A.attnotnull,
      A.atthasdef,
      A.attisdropped,
      A.attislocal,
      A.attinhcount,
      pg_catalog.format_type(T.oid, A.atttypmod) AS atttypname,
      A.attcollation AS attcollation,
      A.attacl AS attacl,
      A.attoptions AS attoptions,
      ARRAY(
         SELECT pg_catalog.quote_ident(option_name) || ' ' || pg_catalog.quote_literal(option_value)
	 FROM pg_catalog.pg_options_to_table(A.attfdwoptions)
	 ORDER BY option_name
	 )::TEXT[] AS attfdwoptions,
      NULL AS adsrc,
      S.inherited AS stainherit,
      S.null_frac AS stanullfrac,
      S.avg_width AS stawidth,
      S.n_distinct AS stadistinct,
      S.most_common_freqs,
      S.correlation
   FROM pg_catalog.pg_attribute A
   LEFT JOIN pg_catalog.pg_stats S ON A.attrelid = CAST( quote_ident(S.schemaname) || '.' || quote_ident(S.tablename) AS pg_catalog.regclass) AND A.attname = S.attname
   LEFT JOIN pg_catalog.pg_type T ON A.atttypid = T.oid
   LEFT JOIN pg_catalog.pg_attrdef D ON D.adrelid = A.attrelid AND D.adnum = A.attnum AND A.attnum > 0 "

   QUERY_ATTRIBUTES="$query"



   # Types
   query="
   SELECT 
      current_database() AS datname
     ,NULL AS stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      oid as typoid,
      typname,
      typnamespace,
      typowner,
      typlen,
      typbyval,
      typtype,
      typcategory AS typcategory,
      typispreferred AS typispreferred,
      typisdefined,
      typdelim,
      typrelid,
      typelem,
      typarray,
      typinput,
      typoutput,
      typreceive,
      typsend,
      typmodin,
      typmodout,
      typanalyze,
      typalign,
      typstorage,
      typnotnull,
      typbasetype,
      typtypmod,
      typndims,
      typcollation AS typcollation,
      typdefaultbin,
      typdefault,
      typacl AS typacl
   FROM pg_catalog.pg_type
   WHERE oid > 16384"

   QUERY_TYPES="$query"



   # Operators
   query="
   SELECT
      current_database() AS datname
     ,NULL AS stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      oid AS oproid,
      oprname,
      oprnamespace,
      oprleft,
      oprright,
      oprowner,
      oprkind,
      oprcanmerge,
      oprcanhash,
      oprresult,
      oprcom,
      oprnegate,
      oprcode,
      oprrest,
      oprjoin
   FROM pg_catalog.pg_operator "

   QUERY_OPERATORS="$query"



   # Languages
   query="
   SELECT
      oid AS lanoid,
      lanname,
      lanowner,
      lanispl,
      lanpltrusted,
      lanacl
   FROM pg_catalog.pg_language "

   QUERY_LANGUAGES="$query"



   # Functions
   # prokind =>> f for a normal function, p for a procedure, a for an aggregate function, or w for a window function
   query="
   SELECT
      oid AS prooid,
      proname,
      pronamespace,
      proowner,
      prokind AS prokind,
      prosecdef,
      proargtypes,
      proconfig,
      proacl,
      prolang,
      procost,
      prorows,
      provariadic AS provariadic,
      NULL AS protransform,
      proleakproof AS proleakproof,
      proisstrict,
      proretset,
      provolatile,
      proparallel AS proparallel,
      pronargs,
      pronargdefaults AS pronargdefaults,
      prorettype,
      proallargtypes,
      proargmodes,
      proargnames,
      protrftypes AS protrftypes
   FROM pg_catalog.pg_proc"

   if [ $server_version -lt 110000 ]; then

      query=$(echo "$query" | sed -e 's/prokind /NULL/g')

   fi

   if [ $server_version -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/proparallel /NULL/g')

   fi

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/protrftypes /NULL/g')

   fi

   QUERY_FUNCTIONS="$query"



   # Locks
   query="
   SELECT 
      current_database() AS datname
     ,NULL AS stats_reset
     ,now() AS ts_snapshot
     ,NULL AS elapsed_interval
     ,NULL AS elapsed_seconds,
      locktype,
      database,
      relation,
      page,
      tuple,
      virtualxid AS virtualxid,
      transactionid,
      classid,
      objid,
      objsubid,
      virtualtransaction AS virtualtransaction,
      pid,
      mode,
      granted,
      fastpath
   FROM pg_catalog.pg_locks
   WHERE pid <> pg_catalog.pg_backend_pid()"

   QUERY_LOCKS="$query"



   # Activity
   # REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(query, $re$'(?:[^'\\\\]|''|\\\\.)*?'(?!')|(\\$[^$]*\\$).*?\\1$re$, $rp$'*REDACTED*'$rp$, 'g'), $re$(?<!\\*REDACTED\\*)'(?!\\*REDACTED\\*)(?:[^'\\\\]|''|\\\.)*i?\\Z|(\\$[^$]*?\\$).*?\\Z$re$, $rp$'*REDACTED*...$rp$, 'g'), $re$\\m\\d+\\M$re$, '####', 'g') AS query,

   query=" 
SELECT 
   current_database() AS datname
  ,NULL AS stats_reset
  ,now() AS ts_snapshot
  ,NULL AS elapsed_interval
  ,NULL AS elapsed_seconds,
    datid,
    datname,
    pid AS pid,
    usesysid,
    usename,
    application_name AS application_name,
    client_addr,
    client_port,
    backend_start,
    xact_start AS xact_start,
    state_change AS state_change,
    NULL AS waiting,
    wait_event AS wait_event,
    wait_event_type AS wait_event_type,
    state AS status,
    backend_xid AS backend_xid,
    backend_xmin AS backend_xmin,
    query_start,
    query 
FROM pg_catalog.pg_stat_activity 
WHERE pid <> pg_catalog.pg_backend_pid() 
"



   if [ $server_version -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/waiting /NULL/g')
      query=$(echo "$query" | sed -e 's/wait_event /NULL/g')
      query=$(echo "$query" | sed -e 's/wait_event_type /NULL/g')

   fi


   if [ $server_version -lt 90400 ]; then

      query=$(echo "$query" | sed -e 's/backend_xid /NULL/g')
      query=$(echo "$query" | sed -e 's/backend_xmin /NULL/g')

   fi


   QUERY_ACTIVITY="$query"

}



# quick and dirty at the moment...
# Add Database and Timestamps

function Query_Modify() {

   QUERY_CLUSTER_GENERAL_INFO="
SELECT ts.*,td.*
FROM ($QUERY_CLUSTER_GENERAL_INFO) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_TABLESPACES="
SELECT ts.*,td.*
FROM ($QUERY_TABLESPACES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_SETTINGS="
SELECT ts.*,td.*
FROM ($QUERY_SETTINGS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_ROLES="
SELECT ts.*,td.*
FROM ($QUERY_ROLES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

#   QUERY_DATABASES="
#SELECT ts.*,td.*
#FROM ($QUERY_DATABASES) td
#    ,(SELECT
#   datname
#  ,stats_reset
#  ,now() AS ts_snapshot
#  , now() - stats_reset AS elapsed_interval
#  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
#FROM pg_stat_database 
#WHERE datname = current_database() )ts
#"

   QUERY_DB_ROLE_SETTINGS="
SELECT ts.*,td.*
FROM ($QUERY_DB_ROLE_SETTINGS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"


   QUERY_REPLICATION="
SELECT ts.*,td.*
FROM ($QUERY_REPLICATION) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_REPLICATION_SLOTS="
SELECT ts.*,td.*
FROM ($QUERY_REPLICATION_SLOTS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_EXTENSION_USED="
SELECT ts.*,td.*
FROM ($QUERY_EXTENSION_USED) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_EXTENSION_AVAILABLE="
SELECT ts.*,td.*
FROM ($QUERY_EXTENSION_AVAILABLE) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_SCHEMAS="
SELECT ts.*,td.*
FROM ($QUERY_SCHEMAS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_TABLES="
SELECT ts.*,td.*
FROM ($QUERY_TABLES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_TABLE_PARTIONED="
SELECT ts.*,td.*
FROM ($QUERY_TABLE_PARTIONED) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_INDEXES="
SELECT ts.*,td.*
FROM ($QUERY_INDEXES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_ATTRIBUTES="
SELECT ts.*,td.*
FROM ($QUERY_ATTRIBUTES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_TYPES="
SELECT ts.*,td.*
FROM ($QUERY_TYPES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_OPERATORS="
SELECT ts.*,td.*
FROM ($QUERY_OPERATORS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_LANGUAGES="
SELECT ts.*,td.*
FROM ($QUERY_LANGUAGES) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_FUNCTIONS="
SELECT ts.*,td.*
FROM ($QUERY_FUNCTIONS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_LOCKS="
SELECT ts.*,td.*
FROM ($QUERY_LOCKS) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"

   QUERY_ACTIVITY="
SELECT ts.*,td.*
FROM ($QUERY_ACTIVITY) td
    ,(SELECT
   datname
  ,stats_reset
  ,now() AS ts_snapshot
  , now() - stats_reset AS elapsed_interval
  ,extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE datname = current_database() )ts
"


#VERBOSE=3
#QueryExec mwe_partitioning "$QUERY_CLUSTER_GENERAL_INFO"
#QueryExec mwe_partitioning "$QUERY_TABLESPACES"
#QueryExec mwe_partitioning "$QUERY_SETTINGS"
#QueryExec mwe_partitioning "$QUERY_ROLES"
#QueryExec mwe_partitioning "$QUERY_DATABASES"
#QueryExec mwe_partitioning "$QUERY_DB_ROLE_SETTINGS"
#QueryExec mwe_partitioning "$QUERY_REPLICATION"
#QueryExec mwe_partitioning "$QUERY_REPLICATION_SLOTS"
#QueryExec mwe_partitioning "$QUERY_EXTENSION_USED"
#QueryExec mwe_partitioning "$QUERY_EXTENSION_AVAILABLE"
#QueryExec mwe_partitioning "$QUERY_SCHEMAS"
#QueryExec mwe_partitioning "$QUERY_TABLES"
#QueryExec mwe_partitioning "$QUERY_TABLE_PARTIONED"
#QueryExec mwe_partitioning "$QUERY_INDEXES"
#QueryExec mwe_partitioning "$QUERY_ATTRIBUTES"
#QueryExec mwe_partitioning "$QUERY_TYPES"
#QueryExec mwe_partitioning "$QUERY_OPERATORS"
#QueryExec mwe_partitioning "$QUERY_LANGUAGES"
#QueryExec mwe_partitioning "$QUERY_FUNCTIONS"
#QueryExec mwe_partitioning "$QUERY_LOCKS"
#QueryExec mwe_partitioning "$QUERY_ACTIVITY"

#QueryExec mwe_partitioning "$QUERY_BGWRITER"
#QueryExec mwe_partitioning "$QUERY_DATABASES"


}


function db_export() {

# Automatic Table Creation for feeding table models

ports='5432 5433 5435 5436 5437'
db=benchmark_definitions

> /tmp/$db.sql

for p in $ports
do

   dbmgr=postgres
   [[ $p -eq 5432 ]] && dbmgr=fred

   echo "PORT=$p"
   psql -p $p -d $dbmgr -c "DROP DATABASE IF EXISTS $db"
   psql -p $p -d $dbmgr -c "CREATE DATABASE $db"

   schema=$(psql -p $p -d $dbmgr -qAtc "SELECT 'v' || (CASE WHEN current_setting('server_version_num')::int / 10000 > 9 THEN current_setting('server_version_num')::int / 10000 ELSE current_setting('server_version_num')::int / 1000 + (current_setting('server_version_num')::int / 100 ) % 10 END)")

   v=$(psql -p $p -d $dbmgr -qAtc "SELECT current_setting('server_version_num')")

   QueryFactory $v
   Query_Modify



   psql -p $p -d $db -c "CREATE SCHEMA $schema"

   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_CLUSTER_GENERAL_INFO AS ($QUERY_CLUSTER_GENERAL_INFO)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_TABLESPACES  AS ($QUERY_TABLESPACES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_SETTINGS AS ($QUERY_SETTINGS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_ROLES AS ($QUERY_ROLES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_DATABASES AS ($QUERY_DATABASES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_DB_ROLE_SETTINGS AS ($QUERY_DB_ROLE_SETTINGS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_REPLICATION AS ($QUERY_REPLICATION)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_REPLICATION_SLOTS AS ($QUERY_REPLICATION_SLOTS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_EXTENSION_USED AS ($QUERY_EXTENSION_USED)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_EXTENSION_AVAILABLE AS ($QUERY_EXTENSION_AVAILABLE)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_SCHEMAS AS ($QUERY_SCHEMAS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_TABLES AS ($QUERY_TABLES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_TABLE_PARTIONED AS ($QUERY_TABLE_PARTIONED)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_INDEXES AS ($QUERY_INDEXES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_ATTRIBUTES AS ($QUERY_ATTRIBUTES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_TYPES AS ($QUERY_TYPES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_OPERATORS AS ($QUERY_OPERATORS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_LANGUAGES AS ($QUERY_LANGUAGES)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_FUNCTIONS AS ($QUERY_FUNCTIONS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_LOCKS AS ($QUERY_LOCKS)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_ACTIVITY AS ($QUERY_ACTIVITY)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_BGWRITER AS ($QUERY_BGWRITER)"
   psql -p $p -d $db -c "CREATE TABLE $schema.QUERY_DATABASES AS ($QUERY_DATABASES)"


   pg_dump -p $p -d $db --schema-only >> /tmp/$db.sql

done


QueryFactory 150000 
Query_Modify

#exit 10
}


# Connect to PostgreSQL to get the content of pg_setting
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#

collect_postgres_guc() {

   local title='Collecting PostgreSQL Grand Unified Configuration'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      query_base="SELECT name || '=' || setting FROM pg_settings"
      query_where=""

      if [ "$USER_SCHEMA" != true ]; then
   
         [ "$VERBOSE" -gt 0 ] && PrintMessage '' '   Applying restriction'
         query_where="WHERE name NOT IN ('search_path')"

      fi

      [ "$VERBOSE" -gt 1 ] && PrintMessage 'DEBUG' '   Retrieving information'
      QueryExec postgres "$query_base $query_where" \
                | sed 's/^/postgresql\.guc\./' >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'DEBUG' '   Information written'

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi



   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      query_base="SELECT format('%s=%s', name, current_setting(name)) FROM pg_settings"
      query_where=""

      if [ "$USER_SCHEMA" != true ]; then

         [ "$VERBOSE" -gt 0 ] && PrintMessage '' '   Applying restriction'
         query_where="WHERE name NOT IN ('search_path')"

      fi

      [ "$VERBOSE" -gt 1 ] && PrintMessage 'DEBUG' '   Retrieving information'
      QueryExec postgres "$query_base $query_where" \
                | sed 's/^/postgresql\.show\./' >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'DEBUG' '   Information written'

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi




}




#
# Connect to PostgreSQL to fetch content of system tables
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#
# IN: $1 = tablename
# OUT: table content as a JSON Object Array

collect_postgres_system_table() {

   local db="$1"
   local table="$2"
   local attributes=

   if [ "$COLLECT_POSTGRES" == true ]; then

      # Get Attributes
      query="
         SELECT string_agg( t.attname, ',' )
         FROM (
               SELECT attnum, attname
               FROM pg_attribute
               WHERE attnum > 0 AND attrelid = '$table'::regclass
               ORDER BY attnum
              ) t
      "
      attributes=$(QueryExec "$db" "$query")

      if [ "$USER_SCHEMA" == false ]; then

         # Change name fields by their md5 image

         attributes=",$attributes,"

	 # Roles, Databases, Schemas

	 attributes=`echo "$attributes" | sed 's/,rolname,/,md5(rolname) AS rolname,/g'`
         attributes=`echo "$attributes" | sed 's/,usename,/,md5(usename) AS usename,/g'`
         attributes=`echo "$attributes" | sed 's/,role_name,/,md5(role_name) AS role_name,/g'`
	 attributes=`echo "$attributes" | sed 's/,datname,/,md5(datname) AS datname,/g'`
	 attributes=`echo "$attributes" | sed 's/,schemaname,/,md5(schemaname) AS schemaname,/g'`
         attributes=`echo "$attributes" | sed 's/,nspname,/,md5(nspname) AS nspname,/g'`
         attributes=`echo "$attributes" | sed 's/,schema_name,/,md5(schema_name) AS schema_name,/g'`

	 # Tables, views
         attributes=`echo "$attributes" | sed 's/,relname,/,md5(relname) AS relname,/g'`
         attributes=`echo "$attributes" | sed 's/,tablename,/,md5(tablename) AS tablename,/g'`
         attributes=`echo "$attributes" | sed 's/,table_name,/,md5(table_name) AS table_name,/g'`
         attributes=`echo "$attributes" | sed 's/,viewname,/,md5(viewname) AS viewname,/g'`
         attributes=`echo "$attributes" | sed 's/,view_name,/,md5(view_name) AS view_name,/g'`
         attributes=`echo "$attributes" | sed 's/,matviewname,/,md5(matviewname) AS matviewname,/g'`

	 # Indices, Constrainsts
         attributes=`echo "$attributes" | sed 's/,indexname,/,md5(indexname) AS indexname,/g'`
         attributes=`echo "$attributes" | sed 's/,indexrelname,/,md5(indexrelname) AS indexrelname,/g'`
         attributes=`echo "$attributes" | sed 's/,conname,/,md5(conname) AS conname,/g'`
         attributes=`echo "$attributes" | sed 's/,constraint_name,/,md5(constraint_name) AS constraint_name,/g'`

         # Attributes
         attributes=`echo "$attributes" | sed 's/,attname,/,md5(attname) AS attname,/g'`
         attributes=`echo "$attributes" | sed 's/,attnames,/,md5(attnames) AS attnames,/g'`
         attributes=`echo "$attributes" | sed 's/,attribute_name,/,md5(attribute_name) AS attribute_name,/g'`
         attributes=`echo "$attributes" | sed 's/,column_name,/,md5(column_name) AS column_name,/g'`

	 # Replication, Slots, Publications, Subscriptions
         attributes=`echo "$attributes" | sed 's/,slot_name,/,md5(slot_name) AS slot_name,/g'`
         attributes=`echo "$attributes" | sed 's/,pubname,/,md5(pubname) AS pubname,/g'`
         attributes=`echo "$attributes" | sed 's/,subname,/,md5(subname) AS subname,/g'`
         attributes=`echo "$attributes" | sed 's/,subslotname,/,md5(subslotname) AS subslotname,/g'`

         # Infrastructure
         attributes=`echo "$attributes" | sed 's/,client_hostname,/,md5(client_hostname) AS client_hostname,/g'`
         attributes=`echo "$attributes" | sed 's/,spcname,/,md5(spcname) AS spcname,/g'`
         attributes=`echo "$attributes" | sed 's/,srvname,/,md5(srvname) AS srvname,/g'`


	 # Remove Extra Characters

         attributes=${attributes:1}
         attributes=${attributes::-1}

      fi


      # Get Content (JSON format)
      query="
         SELECT array_to_json( array_agg( row_to_json( t.* ) ) )
         FROM ( SELECT $attributes FROM $table) t
      "
      result=$(QueryExec "$db" "$query")
      echo "$result"

   fi

}





#
# Collect contents of pg_stat_* and pg_statio_*
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#

collect_postgres_stat_tables() {

   local title='Collecting PostgreSQL Activity Statistics'
   local db="$1"

   if [ "$COLLECT_POSTGRES" == true ]; then

      query="SELECT relname FROM pg_class WHERE relname ~ 'pg_stat_' OR relname ~ 'pg_statio_'"
      tables=$(QueryExec "$db" "$query")
      for table in $tables
      do
         [ "$VERBOSE" -gt 0 ] && PrintMessage '' "Collecting Statistics from $table"
         result=$(collect_postgres_system_table "$table")
	 echo "postgresql.$table=$result" >> $METRICS_OUTPUT

      done


      result=$(collect_postgres_system_table "pg_catalog.pg_stat_user_indexes")
      echo "postgresql.stats.user_indexes=$result"  >> $METRICS_OUTPUT

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get the content of pg_settings
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#

collect_postgres_db_role_setting() {

   local title='Collecting PostgreSQL (db,role) settings'
   local redact_prefix=
   local redact_suffix=
   local result=

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"


      if [ "$USER_SCHEMA" == false ]; then
         redact_prefix='md5('
	 redact_suffix=')'
      fi
         
      # Dump pg_db_role_setting content as json object
      query="
      SELECT array_to_json( array_agg( row_to_json( t.* ) ) )
      FROM (
         SELECT coalesce($redact_prefix role.rolname $redact_suffix, 'database wide') as role, 
                coalesce($redact_prefix db.datname $redact_suffix, 'cluster wide') as database, 
                setconfig as what_changed
         FROM pg_db_role_setting role_setting
         LEFT JOIN pg_roles role ON role.oid = role_setting.setrole
         LEFT JOIN pg_database db ON db.oid = role_setting.setdatabase
      ) t
      "
      result=`QueryExec postgres "$query"`
      echo "postgresql.pg_db_role_setting=$result" >> $METRICS_OUTPUT

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get Tablespaces 
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#

collect_postgres_tablespaces() {

   local title='Collecting PostgreSQL Tablespaces'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_system_table postgres 'pg_tablespace')
      echo "postgresql.pg_tablespace=$result" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.pg_tablespace=$result"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get a view of estimated bloat on relations
# Requirements: COLLECT_POSTGRES=true
# Modificators: USER_SCHEMA
#

collect_postgres_bloating() {

   local db="$1"
   local title='Collecting PostgreSQL relation bloat'
   local redact_prefix=
   local redact_suffix=
   local result=

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"


      if [ "$USER_SCHEMA" == false ]; then
         redact_prefix='md5('
         redact_suffix=')'
      fi

      # Dump pg_db_role_setting content as json object
      query="COPY (
SELECT
  current_database(),
  ($redact_prefix schemaname $redact_suffix) AS schemaname,
  ($redact_prefix tablename $redact_suffix) AS tablename,
  ROUND((CASE WHEN otta=0 THEN 0.0 ELSE sml.relpages::float/otta END)::numeric,1) AS tbloat,
  CASE WHEN relpages < otta THEN 0 ELSE bs*(sml.relpages-otta)::BIGINT END AS wastedbytes,
  ($redact_prefix iname $redact_suffix) AS iname,
  ROUND((CASE WHEN iotta=0 OR ipages=0 THEN 0.0 ELSE ipages::float/iotta END)::numeric,1) AS ibloat,
  CASE WHEN ipages < iotta THEN 0 ELSE bs*(ipages-iotta) END AS wastedibytes 
FROM (
  SELECT
    schemaname, tablename, cc.reltuples, cc.relpages, bs,
    CEIL((cc.reltuples*((datahdr+ma-
      (CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END))+nullhdr2+4))/(bs-20::float)) AS otta,
    COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples,0) AS ituples, COALESCE(c2.relpages,0) AS ipages,
    COALESCE(CEIL((c2.reltuples*(datahdr-12))/(bs-20::float)),0) AS iotta
  FROM (
    SELECT
      ma,bs,schemaname,tablename,
      (datawidth+(hdr+ma-(case when hdr%ma=0 THEN ma ELSE hdr%ma END)))::numeric AS datahdr,
      (maxfracsum*(nullhdr+ma-(case when nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
    FROM (
      SELECT
        schemaname, tablename, hdr, ma, bs,
        SUM((1-null_frac)*avg_width) AS datawidth,
        MAX(null_frac) AS maxfracsum,
        hdr+(
          SELECT 1+count(*)/8
          FROM pg_stats s2
          WHERE null_frac<>0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
        ) AS nullhdr
      FROM pg_stats s, (
        SELECT
          (SELECT current_setting('block_size')::numeric) AS bs,
          CASE WHEN substring(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
          CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
        FROM (SELECT version() AS v) AS foo
      ) AS constants
      GROUP BY 1,2,3,4,5
    ) AS foo
  ) AS rs
  JOIN pg_class cc ON cc.relname = rs.tablename
  JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
  LEFT JOIN pg_index i ON indrelid = cc.oid
  LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
) AS sml 
ORDER BY wastedbytes DESC
) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.bloat.stats.csv`
      echo "postgresql.$db.bloat=$METRICS_FOLDER/$db.bloat.stats.csv" >> $METRICS_OUTPUT

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}




#
# Connect to PostgreSQL to get pg_buffercache
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_buffer_cache_internal() {

   local header=$1

   # pg_buffercache (Cluster Level)

   local query="
SELECT
   COALESCE(d.datname, 'ClusterWide') AS databasename
  ,n.nspname AS schemaname
  ,c.relname AS tablename
  ,count(*) blocks
  ,round( 100.0 * 8192 * count(*) / pg_table_size(c.oid) ) AS pct_rel
  ,round( 100.0 * 8192 * count(*) FILTER (WHERE b.usagecount > 1) / pg_table_size(c.oid) ) AS pct_hot 
  ,now() AS ts_since
  ,now() AS ts_snapshot
  ,now() - now() AS elapsed_interval
  ,extract( 'epoch' from now() )::bigint AS elapsed_seconds 
FROM pg_buffercache b 
JOIN pg_class c ON pg_relation_filenode(c.oid) = b.relfilenode 
JOIN pg_namespace n ON n.oid = c.relnamespace 
LEFT JOIN pg_database d ON d.oid = b.reldatabase 
WHERE b.usagecount IS NOT NULL  
GROUP BY d.datname,n.nspname,c.relname,c.oid 
ORDER BY 4 DESC, 1,2,3 
LIMIT 1000
"

   QueryExec postgres "COPY ($query) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.buffercache.stats.csv

}


collect_postgres_buffer_cache() {

   local title='Collecting PostgreSQL Shared Buffers'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_buffer_cache_internal HEADER)
      echo "postgresql.postgres.buffercache=$METRICS_FOLDER/postgres.buffercache.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.buffercache=$METRICS_FOLDER/postgres.buffercache.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get BgWriter + current_wal_lsn
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_bgwriter_internal() {

   local header=$1

   # BgWriter Activity (Checkpoint, WAL)

   local query="
SELECT
  checkpoints_timed,
  checkpoints_req,
  checkpoint_write_time,
  checkpoint_sync_time,
  buffers_checkpoint,
  buffers_clean,
  maxwritten_clean,
  buffers_backend,
  buffers_backend_fsync,
  buffers_alloc,
  (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_wal_lsn_diff( pg_current_wal_lsn(), '0/0' ) END) AS lsn_write_bytes,
  pg_is_in_recovery() AS recovery,
  (CASE WHEN pg_is_in_recovery() THEN pg_wal_lsn_diff( pg_last_wal_receive_lsn (), '0/0' ) ELSE NULL END ) AS last_wal_receive_bytes,
  (CASE WHEN pg_is_in_recovery() THEN pg_wal_lsn_diff( pg_last_wal_replay_lsn (), '0/0' ) ELSE NULL END ) AS last_wal_replay_bytes,
  stats_reset AS ts_since,
  now() AS ts_snapshot,
  now() - stats_reset AS elapsed_interval,
  extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_bgwriter
"

   if [ $pg_version_num -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/pg_wal_lsn_diff/pg_xlog_location_diff/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_lsn/pg_current_xlog_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_insert_lsn/pg_current_xlog_insert_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_flush_lsn/pg_current_xlog_flush_location/g')

   fi

   if [ $pg_version_num -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_xlog_flush_location()/NULL/g')

   fi

   QueryExec postgres "COPY ($query) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.bgwriter.stats.csv 

}


collect_postgres_bgwriter() {

   local title='Collecting PostgreSQL BgWriter'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_bgwriter_internal HEADER)
      echo "postgresql.postgres.bgwriter=$METRICS_FOLDER/postgres.bgwriter.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.bgwriter=$METRICS_FOLDER/postgres.bgwriter.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get replication status
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_replication_internal() {

   local header=$1

   # pg_stat_replication

   local query="
  
SELECT now() AS ts_snapshot
      ,application_name, pid
      ,client_addr, client_port
      ,backend_start, backend_xmin
      ,state, sync_priority, sync_state
      ,(CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_flush_lsn() END) AS primary_flush_lsn
      ,sent_lsn, write_lsn, flush_lsn, replay_lsn
      , reply_time 
FROM pg_stat_replication
"

   if [ $pg_version_num -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/pg_wal_lsn_diff/pg_xlog_location_diff/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_lsn/pg_current_xlog_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_insert_lsn/pg_current_xlog_insert_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_flush_lsn/pg_current_xlog_flush_location/g')

   fi

   if [ $pg_version_num -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_xlog_flush_location()/NULL/g')

   fi

   QueryExec postgres "COPY ($query) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.replication.stats.csv

}


collect_postgres_replication() {

   local title='Collecting PostgreSQL Replication'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_replication_internal HEADER)
      echo "postgresql.postgres.replication=$METRICS_FOLDER/postgres.replication.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.replication=$METRICS_FOLDER/postgres.replication.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}




#
# Connect to PostgreSQL to get backend enumeration
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_backends_internal() {

   local header=$1

   # pg_stat_activity

   local query="
SELECT now() as ts_snapshot
     , backend_type
     , state
     , (case when state = 'idle' then NULL ELSE wait_event END) AS wait_event
     , (CASE WHEN state = 'idle' THEN NULL ELSE wait_event_type END) AS wait_event_type
     , count(*) 
FROM pg_stat_activity 
GROUP BY 1,2,3,4,5 ORDER BY 1,2
"

   QueryExec postgres "COPY ($query) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.backends.stats.csv

}


collect_postgres_backends() {

   local title='Collecting PostgreSQL Backends'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_backends_internal HEADER)
      echo "postgresql.postgres.backends=$METRICS_FOLDER/postgres.backends.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.backends=$METRICS_FOLDER/postgres.backends.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get Database Stats
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

prev_collect_postgres_database_internal() {

   local header=$1

   QueryExec postgres "COPY (
SELECT
  datname, numbackends,
  xact_commit, xact_rollback, COALESCE( 100 * xact_rollback / (xact_rollback + xact_commit), 0) AS rollback_pct,
  blks_read, blks_hit, 100 * blks_hit / (blks_hit + blks_read) AS hit_pct,
  tup_returned, tup_fetched, tup_inserted,tup_updated, tup_deleted,
  conflicts,
  temp_files, temp_bytes,
  deadlocks, 
  checksum_failures, checksum_last_failure,
  blk_read_time::bigint, blk_write_time::bigint,
  stats_reset AS ts_since,
  now() AS ts_snapshot,
  now() - stats_reset AS elapsed_interval,
  extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
FROM pg_stat_database 
WHERE blks_hit > 0 AND (xact_rollback + xact_commit) > 0 
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.db.stats.csv

}


prev_collect_postgres_database() {

   local title='Collecting PostgreSQL Database Statistics'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_database_internal HEADER)
      echo "postgresql.postgres.database_stats=$METRICS_FOLDER/postgres.database.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.database_stats=$METRICS_FOLDER/postgres.database.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get Citus Information
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

function collect_postgres_citus() {

   local title='Collecting PostgreSQL Citus Information'

   local db=$"$1"
   local query=
   local result=
   
   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"


      #--- Collect Citus Version -------------------------------------------------

      query="SELECT extversion FROM pg_extension WHERE extname = 'citus'"
      result=$(QueryExec "$db" "$query")
      
      if [ "$result" == '' ]; then
         [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
         return
      fi


      #--- Collect Citus Table Information ------------------------------------

      QueryExec "$db" "COPY (
SELECT now() AS ts_snapshot
      ,table_name
      ,citus_table_type
      ,distribution_column
      ,colocation_id
      ,table_size
      ,shard_count
      ,table_owner
      ,access_method 
FROM citus_tables 
ORDER BY colocation_id,table_name::text
   ) TO STDOUT CSV HEADER DELIMITER E'\t'" >> $METRICS_FOLDER/$db.citus.table.stats.csv

      echo "postgresql.$db.citus_table_stats=$METRICS_FOLDER/$db.citus.table.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.citus_table_stats=$METRICS_FOLDER/$db.citus.table.stats.csv"


      #-- Collect Citus Shard Information -------------------------------------

      QueryExec "$db" "COPY (
SELECT now() AS ts_snapshot
      ,s.table_name
      ,s.shardid
      ,s.shard_name
      ,s.citus_table_type
      ,s.colocation_id
      ,s.nodename
      ,s.nodeport
      ,s.shard_size
      ,p.placementid
      ,p.shardstate
      ,p.shardlength 
FROM citus_shards s JOIN pg_dist_placement p ON (s.colocation_id = p.groupid AND s.shardid = p.shardid) 
ORDER BY s.colocation_id,s.shardid 
   ) TO STDOUT CSV HEADER DELIMITER E'\t'" >> $METRICS_FOLDER/$db.citus.shard.stats.csv

      echo "postgresql.$db.citus_shard_stats=$METRICS_FOLDER/$db.citus.shard.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.citus_shard_stats=$METRICS_FOLDER/$db.citus.shard.stats.csv"


      #-- Collect Citus Stat Activity -----------------------------------------
      
      QueryExec "$db" "COPY (
SELECT now() AS ts_snapshot
      ,global_pid
      ,nodeid
      ,is_worker_query
      ,datid
      ,datname
      ,pid
      ,leader_pid
      ,usesysid
      ,usename
      ,application_name
      ,client_addr
      ,client_hostname
      ,client_port
      ,backend_start
      ,xact_start
      ,query_start
      ,state_change
      ,wait_event_type
      ,wait_event
      ,state
      ,backend_xid
      ,backend_xmin
      ,query_id
      ,query
      ,backend_type 
FROM citus_stat_activity 
ORDER BY global_pid,is_worker_query,query_start NULLS LAST, nodeid
   ) TO STDOUT CSV HEADER DELIMITER E'\t'" >> $METRICS_FOLDER/$db.citus.activity.stats.csv

      echo "postgresql.$db.citus_activity_stats=$METRICS_FOLDER/$db.citus.activity.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.citus_activity_stats=$METRICS_FOLDER/$db.citus.activity.stats.csv"


      #-- Collect Citus Stat Statements ---------------------------------------

      QueryExec "$db" "COPY (
SELECT now() AS ts_snapshot
      ,queryid
      ,userid
      ,dbid
      ,query
      ,executor
      ,partition_key
      ,calls 
FROM citus_stat_statements
   ) TO STDOUT CSV HEADER DELIMITER E'\t'" >> $METRICS_FOLDER/$db.citus.statement.stats.csv

      echo "postgresql.$db.citus_statement_stats=$METRICS_FOLDER/$db.citus.statement.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.citus_statement_stats=$METRICS_FOLDER/$db.citus.statement.stats.csv"


   #-- Collect Network Connections --------------------------------------------

   if [ "$(whereis ss)" != "" ]; then
      ss -o state all "( dport = $PG_PORT or sport = $PG_PORT )" >> $METRICS_FOLDER/linux.ss.csv
   fi


   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



#
# Connect to PostgreSQL to get Table Stats
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_table_internal() {

   local db="$1"
   local header=$2

   QueryExec "$db" "COPY (
SELECT 
   current_database() AS datname,
   c.oid,
   t.schemaname, t.relname,
   c.relpages, c.relpages::bigint * 8192::bigint AS heap_size,
   pg_relation_size(c.oid) AS relation_size, pg_total_relation_size(c.oid) AS relation_total_size
  ,COALESCE( t.seq_scan, 0 ) AS seq_scan
  ,COALESCE( t.seq_tup_read, 0 ) AS seq_tup_read
  ,COALESCE( t.idx_scan, 0 ) AS idx_scan
  ,COALESCE( t.idx_tup_fetch, 0 ) AS idx_tup_fetch
  ,COALESCE( t.n_tup_ins, 0 ) AS n_tup_ins
  ,COALESCE( t.n_tup_upd, 0 ) AS n_tup_upd
  ,COALESCE( t.n_tup_del, 0 ) AS n_tup_del
  ,COALESCE( t.n_tup_hot_upd, 0 ) AS n_tup_hot_upd
  ,COALESCE( b.heap_blks_read, 0 ) AS heap_blks_read
  ,COALESCE( b.heap_blks_hit, 0 ) AS heap_blks_hit
  ,COALESCE( b.idx_blks_read, 0 ) AS idx_blks_read
  ,COALESCE( b.idx_blks_hit, 0 ) AS idx_blks_hit
  ,COALESCE( b.toast_blks_read, 0 ) AS toast_blks_read
  ,COALESCE( b.toast_blks_hit, 0 ) AS toast_blks_hit
  ,COALESCE( b.tidx_blks_read, 0 ) AS tidx_blks_read
  ,COALESCE( b.tidx_blks_hit, 0 ) AS tidx_blks_hit
  ,c.reltuples::bigint
  ,COALESCE( t.n_live_tup, 0 ) AS n_live_tup
  ,COALESCE( t.n_dead_tup, 0 ) AS n_dead_tup
  ,COALESCE( t.n_mod_since_analyze, 0 ) AS n_mod_since_analyze
  ,t.last_analyze, t.analyze_count,t.last_autoanalyze,t.autoanalyze_count
  ,t.last_vacuum, t.vacuum_count, t.last_autovacuum, t.autovacuum_count
  ,d.ts_since, d.ts_snapshot, d.elapsed_interval, d.elapsed_seconds 
FROM pg_class c 
INNER JOIN pg_stat_user_tables t ON (t.relid = c.oid) 
INNER JOIN pg_statio_user_tables b ON (b.relid = c.oid) 
JOIN LATERAL (
              SELECT stats_reset AS ts_since,
                     now() AS ts_snapshot,
                     now() - stats_reset AS elapsed_interval,
                     extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
              FROM pg_stat_database
              WHERE datname = current_database()
             ) d ON true 
ORDER BY schemaname,relname
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.table.stats.csv

}


collect_postgres_table() {

   local db=$1
   local title="Collecting PostgreSQL $db Table Statistics"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_table_internal $db HEADER)
      echo "postgresql.$db.table_stats=$METRICS_FOLDER/$db.table.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.table_stats=$METRICS_FOLDER/$db.table.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}




#
# Connect to PostgreSQL to get Index Stats
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_index_internal() {

   local db="$1"
   local header=$2

   QueryExec "$db" "COPY (
SELECT 
   current_database() AS datname,
   c.oid,
   i.schemaname, i.relname AS tablename, i.indexrelname AS indexname,
   c.relpages, c.relpages::bigint * 8192::bigint AS index_size,
   c.reltuples::bigint,
   i.idx_scan, i.idx_tup_read, i.idx_tup_fetch,
   b.idx_blks_read, b.idx_blks_hit,
   d.ts_since, d.ts_snapshot, d.elapsed_interval, d.elapsed_seconds 
FROM pg_class c 
INNER JOIN pg_stat_user_indexes i ON (i.indexrelid = c.oid) 
INNER JOIN pg_statio_user_indexes b ON (b.indexrelid = c.oid) 
JOIN LATERAL (
              SELECT stats_reset AS ts_since,
                     now() AS ts_snapshot,
                     now() - stats_reset AS elapsed_interval,
                     extract( 'epoch' from now() - stats_reset )::bigint AS elapsed_seconds 
              FROM pg_stat_database
              WHERE datname = current_database()
             ) d ON true 
ORDER BY schemaname, tablename, indexname
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.index.stats.csv

}


collect_postgres_index() {

   local db=$1
   local title="Collecting PostgreSQL $db Index Statistics"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_index_internal $db HEADER)
      echo "postgresql.postgres.index_stats=$METRICS_FOLDER/$db.index.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.index_stats=$METRICS_FOLDER/$db.index.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}





###--- Import From DataBene.Support.Checker.sh -----------------------------###




#
# Connect to PostgreSQL to get Cluster Information
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_cluster_info_internal() {

   local db="$1"
   local header=$2

   local query="
SELECT
    '$(hostname)' AS hostname,
    pg_catalog.version(),
    pg_catalog.current_setting('port') AS port,
    current_setting('data_directory') AS data_directory,
    (CASE WHEN pg_is_in_recovery() THEN NULL ELSE txid_current() END) AS txid_current,
    txid_current_snapshot() AS txid_current_snapshot,
    txid_snapshot_xmin(txid_current_snapshot()) AS txid_snapshot_xmin,
    txid_snapshot_xmax(txid_current_snapshot()) AS txid_snapshot_xmax,
    current_timestamp AS current_timestamp,
    (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_lsn() END) AS wal_lsn,
    (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_insert_lsn() END) AS wal_insert_lsn,
    (CASE WHEN pg_is_in_recovery() THEN NULL ELSE pg_current_wal_flush_lsn() END) AS wal_flush_lsn,
    pg_catalog.pg_postmaster_start_time() AS postmaster_start_time,
    pg_conf_load_time() AS conf_load_time,
    pg_is_in_recovery() AS is_in_recovery,
    false AS is_rds
         "

   if [ $server_version -lt 100000 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_wal_lsn/pg_current_xlog_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_insert_lsn/pg_current_xlog_insert_location/g')
      query=$(echo "$query" | sed -e 's/pg_current_wal_flush_lsn/pg_current_xlog_flush_location/g')

   fi

   if [ $server_version -lt 90600 ]; then

      query=$(echo "$query" | sed -e 's/pg_current_xlog_flush_location()/NULL/g')

   fi


   QueryExec "$db" "COPY ( $query 
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/postgres.cluster.info.csv

}


collect_postgres_cluster_info() {

   local db=$1
   local title='Collecting PostgreSQL Cluster Information'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_cluster_info_internal $db HEADER)
      echo "postgresql.postgres.cluster_info=$METRICS_FOLDER/postgres.cluster_info.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.postgres.cluster_info=$METRICS_FOLDER/postgres.cluster_info.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}





#
# Connect to PostgreSQL to get Tablespace Stats
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_tablespace_internal() {

   local db="$1"
   local header=$2

   local query="
SELECT
    name,
    current_setting(name),
    source,
    setting,
    boot_val AS boot_val,
    reset_val AS reset_val,
    sourcefile AS sourcefile,
    sourceline AS sourceline,
    pending_restart AS pending_restart
FROM pg_catalog.pg_settings
         "

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/pending_restart/NULL/g')

   fi


   QueryExec "$db" "COPY ( $query
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.tablespace.stats.csv

}


collect_postgres_tablespace() {

   local db=$1
   local title="Collecting PostgreSQL $db Tablespace Statistics"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_tablespace_internal $db HEADER)
      echo "postgresql.$db.tablespace_stats=$METRICS_FOLDER/$db.tablespace.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.tablespace_stats=$METRICS_FOLDER/$db.tablespace.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}





#
# Connect to PostgreSQL to get setting
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_setting_internal() {

   local db="$1"
   local header=$2

   local query="
SELECT
    name,
    current_setting(name),
    source,
    setting,
    boot_val AS boot_val,
    reset_val AS reset_val,
    sourcefile AS sourcefile,
    sourceline AS sourceline,
    pending_restart AS pending_restart
FROM pg_catalog.pg_settings
         "

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/pending_restart/NULL/g')

   fi


   QueryExec "$db" "COPY ( $query
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.settings.csv

}


collect_postgres_setting() {

   local db=$1
   local title="Collecting PostgreSQL $db Settings"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_setting_internal $db HEADER)
      echo "postgresql.$db.settings=$METRICS_FOLDER/$db.settings.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.settings=$METRICS_FOLDER/$db.settings.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}





#
# Connect to PostgreSQL to get Roles
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_role_internal() {

   local db="$1"
   local header=$2
   local query="
SELECT
    oid,
    rolname,
    rolsuper,
    rolinherit,
    rolcreaterole,
    rolcreatedb,
    true AS rolcatupdate,
    rolcanlogin,
    rolreplication AS rolreplication,
    rolconnlimit,
    rolvaliduntil,
    rolbypassrls AS rolbypassrls,
    rolconfig
FROM pg_catalog.pg_roles
         "

   if [ $server_version -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/rolbypassrls/NULL/g')

   fi

   QueryExec "$db" "COPY ( $query
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.roles.csv

}


collect_postgres_role() {

   local db=$1
   local title="Collecting PostgreSQL $db Roles"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_role_internal $db HEADER)
      echo "postgresql.$db1.roles=$METRICS_FOLDER/$db.roles.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.roles=$METRICS_FOLDER/$db.roles.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}





#
# Connect to PostgreSQL to get Database Stats
# Requirements: COLLECT_POSTGRES=true
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_database_internal() {

   local db="$1"
   local header=$2
   local query="
SELECT
    oid,
    datname,
    pg_stat_get_db_numbackends(oid) AS numbackends,
    datdba,
    encoding,
    datcollate AS datcollate,
    datctype AS datctype,
    dattablespace,
    datistemplate,
    datallowconn,
    datconnlimit,
    datlastsysoid AS datlastsysoid,
    CASE WHEN pg_catalog.has_database_privilege(oid, 'CONNECT')
        THEN pg_catalog.pg_database_size(oid)
        ELSE NULL
    END AS datsize,
    datfrozenxid,
    age(datfrozenxid) AS datage,
    datminmxid AS datminmxid,
    mxid_age(datminmxid) AS datminmxid_age,
    datacl,
    pg_catalog.pg_stat_get_db_xact_commit(oid) AS xact_commit,
    pg_catalog.pg_stat_get_db_xact_rollback(oid) AS xact_rollback,
    pg_catalog.pg_stat_get_db_blocks_fetched(oid) -
        pg_catalog.pg_stat_get_db_blocks_hit(oid) AS blks_read,
    pg_catalog.pg_stat_get_db_blocks_hit(oid) AS blks_hit,
    pg_stat_get_db_tuples_returned(oid) AS tup_returned,
    pg_stat_get_db_tuples_fetched(oid) AS tup_fetched,
    pg_stat_get_db_tuples_inserted(oid) AS tup_inserted,
    pg_stat_get_db_tuples_updated(oid) AS tup_updated,
    pg_stat_get_db_tuples_deleted(oid) AS tup_deleted,
    pg_stat_get_db_conflict_all(oid) AS conflicts,
    pg_stat_get_db_temp_files(oid) AS temp_files,
    pg_stat_get_db_temp_bytes(oid) AS temp_bytes,
    pg_stat_get_db_deadlocks(oid) AS deadlocks,
    pg_stat_get_db_blk_read_time(oid) AS blk_read_time,
    pg_stat_get_db_blk_write_time(oid) AS blk_write_time,
    pg_stat_get_db_conflict_tablespace(oid) AS confl_tablespace,
    pg_stat_get_db_conflict_lock(oid) AS confl_lock,
    pg_stat_get_db_conflict_snapshot(oid) AS confl_snapshot,
    pg_stat_get_db_conflict_bufferpin(oid) AS confl_bufferpin,
    pg_stat_get_db_conflict_startup_deadlock(oid) AS confl_deadlock,
    COALESCE(pg_stat_get_db_stat_reset_time(oid), '1970-01-01'::timestamp) AS ts_since,
    now() AS ts_snapshot,
    now() - COALESCE(pg_stat_get_db_stat_reset_time(oid),'1970-01-01'::timestamp) AS elapsed_interval,
    extract( epoch from now() - COALESCE(pg_stat_get_db_stat_reset_time(oid),'1970-01-01'::timestamp) )::bigint AS elapsed_seconds 
FROM pg_catalog.pg_database 
WHERE datname NOT IN ('template0', 'template1')
         "

   if [ $pg_version_num -ge 150000 ]; then

      query=$(echo "$query" | sed -e 's/datlastsysoid/NULL/g')

   fi


   if [ $pg_version_num -lt 90500 ]; then

      query=$(echo "$query" | sed -e 's/mxid_age(datminmxid)/NULL/g')

   fi

   if [ $pg_version_num -lt 90300 ]; then

      query=$(echo "$query" | sed -e 's/datminmxid /NULL /g')

   fi

   QueryExec "$db" "COPY ( $query
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.database.stats.csv

}


collect_postgres_database() {

   local db=$1
   local title="Collecting PostgreSQL $db Database Statistics"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_database_internal $db HEADER)
      echo "postgresql.postgres.database_stats=$METRICS_FOLDER/$db.database.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.database_stats=$METRICS_FOLDER/$db.database.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}














#
# Connect to PostgreSQL to get XXX Stats
# Requirements: COLLECT_POSTGRES=true:0
# Modificators:
#

# internal function is also called by watch scenario without header

collect_postgres_XXX_internal() {

   local db="$1"
   local header=$2

   QueryExec "$db" "COPY ( $query
   ) TO STDOUT CSV $header DELIMITER E'\t'" >> $METRICS_FOLDER/$db.XXX.stats.csv

}


collect_postgres_XXX() {

   local db=$1
   local title="Collecting PostgreSQL $db XXX Statistics"

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      local result=$(collect_postgres_XXX_internal $db HEADER)
      echo "postgresql.postgres.XXX_stats=$METRICS_FOLDER/$db.XXX.stats.csv" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 2 ] && PrintMessage 'COLLECT' "postgresql.$db.XXX_stats=$METRICS_FOLDER/$db.XXX.stats.csv"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}



















###############################################################################
# METADATA ####################################################################
###############################################################################


#
# Gather Server Identity or Cluster Identity
# Requirement: COLLECT_SYSTEM=true or COLLECT_POSTGRES=true
# Modificators:
#

benchmark_identify() {

   local title=

   title='Collecting Linux Meta Identification'

   if [ "$COLLECT_SYSTEM" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      # Identification => hostname, ip, system_uuid, machine-id

      host_name=$(hostname)
      echo "benchmark.meta.linux.host_name=$host_name" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.host_name=$host_name"

      host_ip=$(hostname -I | cut -d ' ' -f1)
      echo "benchmark.meta.linux.host_ip=$host_ip" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.host_ip=$host_ip"


      # system_uuid=$(dmidecode -s system-uuid)
      # echo "benchmark.meta.linux.system_uuid=$system_uuid" >> $METRICS_OUTPUT
      # [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.system_uuid=$system_uuid"

      machine_id=$(cat /etc/machine-id)
      echo "benchmark.meta.linux.machine_id=$machine_id" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.machine_id=$machine_id"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi


   title='Collecting PostgreSQL Meta Identification'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      # Identification => cluster_name, system_identifier, port, data_directory

      pg_version_num=`QueryExec postgres "show server_version_num"`

      cluster_name='Not Defined'
      if [ $pg_version_num -ge 90500 ]; then
         cluster_name=$(QueryExec postgres "SHOW cluster_name")
      fi
      echo "benchmark.meta.postgresql.cluster_name=$cluster_name" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.cluster_name=$cluster_name"

      # PostgreSQL 9.6+
      cluster_id='Not Defined'
      if [ $pg_version_num -ge 90600 ]; then
         cluster_id=$(QueryExec postgres 'SELECT system_identifier FROM pg_control_system()')
      fi
      echo "benchmark.meta.postgresql.system_identifier=$cluster_id" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.system_identifier=$cluster_id"

      cluster_port=$(QueryExec postgres "SHOW port")
      echo "benchmark.meta.postgresql.cluster_port=$cluster_port" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.cluster_port=$cluster_port" 

      cluster_datadir=$(QueryExec postgres "SHOW data_directory")
      echo "benchmark.meta.postgresql.cluster_datadir=$cluster_datadir" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.cluster_datadir=$cluster_datadir"

      database_names=$(QueryExec postgres "SELECT string_agg(datname, ',') FROM pg_database WHERE datallowconn = 't' AND datname NOT IN ('template0', 'template1')")
      echo "benchmark.meta.postgresql.databases=$database_names" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.databases=$database_names"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}




#
# Describe the machine and PostgreSQL as much as permitted
# Requirements: COLLECT_SYSTEM=true or COLLECT_POSTGRES=true
# Modificators: 

benchmark_describe() {

   local title=

   title='Collecting Linux Meta Description'

   if [ "$COLLECT_SYSTEM" ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"
	   
      #
      # Server RAM
      # Requirements: COLLECT_SYSTEM=true
      # Modificators:
      #

      host_ram=$(lsmem | grep 'Total online memory:' | tr -d ' ' | cut -d ':' -f2)
      echo "benchmark.meta.linux.host_ram=$host_ram" >> $METRICS_OUTPUT

      #
      # Machine Local Disk Sizes
      # Requirements: COLLECT_SYSTEM=true
      # Modificators:
      #

      local_disk_sizes=
      while read entry
      do

         dev=`echo "$entry"| tr -s ' ' | cut -d ' ' -f1`
         siz=`echo "$entry"| tr -s ' ' | cut -d ' ' -f4`
         echo "benchmark.meta.linux.host.disk.""$dev""=""$siz" >> $METRICS_OUTPUT

         local_disk_sizes="$local_disk_sizes / $siz"

      done < <(lsblk | grep '^[hs]d[a-z]')

      local_disk_sizes=${local_disk_sizes:3}
      echo "benchmark.meta.linux.host.disk_sizes=$local_disk_sizes" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.host.disk_sizes=$local_disk_sizes"


      #
      # Physical or Virtual Machine
      # Requirements: COLLECT_SYSTEM=true
      # Modificators:
      #


      host_virtual='Virtualized'
      echo "benchmark.meta.linux.host_type=$host_virtual" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.host_type=$host_virtual"


      #
      # OS Release and Kernel Version
      # Requirements: COLLECT_SYSTEM=true
      # Modificators:
      #

      os_release=$(grep 'PRETTY_NAME=' /etc/*-release | tr -d '"' | cut -d '=' -f2)
      echo "benchmark.meta.linux.name.pretty=$os_release" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.name.pretty=$os_release"

      os_kernel=$(uname -r)
      echo "benchmark.meta.linux.kernel=$os_kernel" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.linux.kernel=$os_kernel"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi


   title='Collecting PostgreSQL Meta Description'

   if [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      #
      # PostgreSQL Version (Human Format)
      # Requirements: COLLECT_POSTGRES=true
      # Modificators:
      #

      pg_version=`QueryExec postgres "show server_version" | cut -d ' ' -f1`
      pg_version_major=${pg_version%.*}
      pg_version_minor=${pg_version##*.}
      pg_version="$pg_version_major"".""$pg_version_minor"
      echo "benchmark.meta.postgresql.version=$pg_version" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.version=$pg_version"


      #
      # PostgreSQL Shared Buffers (Human Format)
      # Requirements: COLLECT_POSTGRES=true
      # Modificators:
      #

      cluster_sb=`QueryExec postgres 'SHOW shared_buffers'`
      echo "benchmark.meta.postgresql.shared_buffers=$cluster_sb" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.shared_buffers=$cluster_sb"


      #
      # PostgreSQL max_connections
      # Requirements: COLLECT_POSTGRES=true
      # Modificators:
      #

      max_connections=`QueryExec postgres 'SHOW max_connections'`
      echo "benchmark.meta.postgresql.max_connections=$max_connections" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.max_connections=$max_connections"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi


   title='Collecting Shared Meta Description'

   if [ "$COLLECT_SYSTEM" == true ] && [ "$COLLECT_POSTGRES" == true ]; then

      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title"

      #
      # PostgreSQL Cluster Size on Disk
      # Requirements: COLLECT_SYSTEM=true, COLLECT_POSTGRES=true
      # Modificators:
      #

      pgdata=`QueryExec postgres 'SHOW data_directory'`
      cluster_size=`du -sBG $pgdata | cut -f1`
      echo "benchmark.meta.postgresql.cluster_size=$cluster_size" >> $METRICS_OUTPUT
      [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.postgresql.cluster_size=$cluster_size"

   else
      [ "$VERBOSE" -gt 0 ] && PrintMessage '' "$title [skipped]"
   fi

}


###############################################################################
# SCENARIOS ###################################################################
###############################################################################

foundation() {

   #?collect_benchmark_metadata

   collect_linux_os_version
   collect_linux_cpu
   collect_linux_mem
   collect_linux_sysctl
   collect_linux_disks

   collect_postgres_guc

}


classic() {

   foundation


   #-- Query Factory Integration ----------------------------------------------
   pg_version_num=`QueryExec postgres "show server_version_num"`

   QueryFactory $pg_version_num
   Query_Modify

   db=postgres

   query="COPY ( $QUERY_CLUSTER_GENERAL_INFO ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.cluster.stats.csv`

   query="COPY ( $QUERY_CLUSTER_GENERAL_INFO ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.cluster.stats.csv`

   query="COPY ( $QUERY_TABLESPACES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.tablespaces.stats.csv`

   query="COPY ( $QUERY_SETTINGS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.settings.stats.csv`

   query="COPY ( $QUERY_ROLES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.roles.stats.csv`

   query="COPY ( $QUERY_DATABASES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.databases.stats.csv`

   query="COPY ( $QUERY_DB_ROLE_SETTINGS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.roles_settings.stats.csv`

   query="COPY ( $QUERY_REPLICATION ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.replication.stats.csv`

   query="COPY ( $QUERY_REPLICATION_SLOTS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.replication_slots.stats.csv`


   query="COPY ( $QUERY_BGWRITER ) TO STDOUT CSV HEADER DELIMITER E'\t'"
   result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.bgwriter.stats.csv`



   # Cluster Level Statistics

   collect_postgres_tablespaces
   collect_postgres_db_role_setting
   collect_postgres_bgwriter
   collect_postgres_replication
   collect_postgres_backends
   collect_postgres_database postgres

   if [ "$SAMPLE_BUFFER_CACHE" == "true" ] ; then
      collect_postgres_buffer_cache
   fi

   # Database Level Statistics

   db_list=$(QueryExec postgres "
      SELECT string_agg(datname, ' ')
      FROM pg_database
      WHERE datallowconn = 't' AND datname NOT IN ('template0', 'template1')
      ")

   for db in $db_list
   do

      PrintMessage ''  "Static statistics are being recorded for database $PG_PORT/$db"
      [ "$COLLECT_DUMP" == true ] && collect_postgres_definitions $db
      collect_postgres_table $db
      collect_postgres_index $db
      collect_postgres_bloating $db
      collect_postgres_citus $db

      # Query Factory

      query="COPY ( $QUERY_EXTENSION_USED ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.extensions_used.stats.csv`

      query="COPY ( $QUERY_EXTENSION_AVAILABLE ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.extensions_available.stats.csv`

      query="COPY ( $QUERY_SCHEMAS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.schemas.stats.csv`

      query="COPY ( $QUERY_TABLES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.tables.stats.csv`

      query="COPY ( $QUERY_TABLE_PARTIONED ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.partitions.stats.csv`

      query="COPY ( $QUERY_INDEXES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.indexes.stats.csv`

      query="COPY ( $QUERY_ATTRIBUTES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.attributes.stats.csv`

      query="COPY ( $QUERY_TYPES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.type.stats.csv`

      query="COPY ( $QUERY_OPERATORS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.operators.stats.csv`

      query="COPY ( $QUERY_LANGUAGES ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.languages.stats.csv`

      query="COPY ( $QUERY_FUNCTIONS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.functions.stats.csv`

      query="COPY ( $QUERY_LOCKS ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.locks.stats.csv`

      query="COPY ( $QUERY_ACTIVITY ) TO STDOUT CSV HEADER DELIMITER E'\t'"
      result=`QueryExec "$db" "$query" >> $METRICS_FOLDER/$db.qf.activity.stats.csv`

   done   



   #--- PostgreSQL Live Metrics ------------------------------------------------


   # Counting Active Replication Streams
   # Infosec: user-data=no, user-schema=no
   #

   if [ "$pg_version_num" -ge '90200' ]; then
      query='SELECT count(*) FROM pg_stat_replication'
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.replication.streams=$count" >> $METRICS_OUTPUT
   fi


   # Counting Active Replication Slots
   # Infosec: user-data=no, user-schema=no
   #
   if [ "$pg_version_num" -ge '90400' ]; then
      query='SELECT count(*) FROM pg_replication_slots'
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.replication.slots=$count" >> $METRICS_OUTPUT
   fi


   # Counting User Tables whose (auto)vacuum count is zero and x_scan > 0
   # Infosec: user-data=no, user-schema=no
   #
   query='
      SELECT count(*)
      FROM pg_stat_user_tables
      WHERE (vacuum_count = 0 OR vacuum_count IS NULL)
        AND (autovacuum_count = 0 OR autovacuum_count IS NULL) AND (seq_scan + idx_scan) > 0
    '
   count=`QueryExec postgres "$query"`
   echo "postgresql.live.user_tables.unvacuumed.count=$count" >> $METRICS_OUTPUT


   # Counting User Tables whose vacuum is late
   # Infosec: user-data=no, user-schema=no
   #
   query="
      SELECT count(*)
      FROM pg_stat_user_tables
      WHERE n_dead_tup > 1000
        AND n_live_tup > 1000
        AND 1.05::float * (current_setting('autovacuum_vacuum_threshold')::float
            + current_setting('autovacuum_vacuum_scale_factor')::float * n_live_tup::float)
            < n_dead_tup
   "
   count=`QueryExec postgres "$query"`
   echo "postgresql.live.user_tables.latevacuum.count=$count" >> $METRICS_OUTPUT


   # Counting Additionnal Tablespaces
   # Infosec: user-data=no, user-schema=no
   #
   if [ "$pg_version_num" -ge '90200' ]; then
      query="SELECT count(*) FROM pg_tablespace WHERE spcname NOT IN ('pg_default','pg_global')"
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.tablespaces=$count" >> $METRICS_OUTPUT
   fi


   # Counting Application Users
   # Infosec: user-data=no, user-schema=no
   #
   query="
      SELECT count(*)
      FROM pg_user
      WHERE usesuper = 'f' AND userepl = 'f'
   "
   count=`QueryExec postgres "$query"`
   echo "postgresql.live.application.user.count=$count" >> $METRICS_OUTPUT

   # Counting Replication Users
   # Infosec: user-data=no, user-schema=no
   #
   query="
      SELECT count(*)
      FROM pg_user
      WHERE usesuper = 'f' AND userepl = 't'
   "
   count=`QueryExec postgres "$query"`
   echo "postgresql.live.replication.user.count=$count" >> $METRICS_OUTPUT


}


watch() {

   # Collect statistics every s seconds for i iterations
   # pg_stat_database, pg_stat(io)_user_table, pg_stat(io)_user_index


   # Default sampling interval is checkpoint_warning
   # Default sampling duration is 5 x checkpoint_timeout
   # Static view: WATCH_INTERVAL!=0, WATCH_MAXLOOP=0

   local WATCH_MAXLOOP=0
   local WATCH_Loop=0
   local MOD_BgWriter=1
   local MOD_Databases=1
   local MOD_Relations=1
   local MOD_BufferCache=10


   classic 


   #METRICS_FOLDER="$STORE/$PROJECT/""$(hostname)""_""$SCENARIO""_""$RUN_HMS"
   #mkdir -p "$METRICS_FOLDER"

   echo 'ts_snapshot pid backend_type state ppid minflt majflt utime systime processor delayacct_blkio_ticks' > $METRICS_FOLDER/linux.process.stats.csv


   db_list=$(QueryExec postgres "
      SELECT string_agg(datname, ' ')
      FROM pg_database
      WHERE datallowconn = 't' AND datname NOT IN ('template0', 'template1', 'postgres')
      ")
   [ "$db_list" == "" ] && db_list=postgres


   if [ "$WATCH_PERIOD" == 0 ]; then
      WATCH_PERIOD=$(QueryExec postgres "SELECT 5 * setting::integer FROM pg_settings WHERE name = 'checkpoint_timeout'")
   fi

   WATCH_MAXLOOP=$(( 1 + ($WATCH_PERIOD / $WATCH_INTERVAL) ))


   PrintMessage '' "Dynamic statistics are requested for all databases."
   PrintMessage '' "Estimated duration is $(( $WATCH_INTERVAL * $WATCH_MAXLOOP )) seconds."


WATCH_Loop=1
while [ $WATCH_Loop -le $WATCH_MAXLOOP ];
do

   PrintMessage '' "Waiting ($WATCH_INTERVAL seconds)"
   result=$(QueryExec postgres "SELECT pg_sleep( extract(epoch FROM
                   to_timestamp(ceil( extract( epoch FROM now()) 
                 / extract(epoch from interval '$WATCH_INTERVAL seconds')) 
		 * extract(epoch from interval '$WATCH_INTERVAL seconds')) - now() ))")

    PrintMessage '' "Sampling $WATCH_Loop / $WATCH_MAXLOOP @ $(date '+%Y%m%d%H%M%S')"


   ### Collect Linux Essentials ###############################################

   PrintMessage '' "   Collecting Linux Activity Stats @ $(date '+%Y%m%d%H%M%S')"

   now="$(date '+%Y%m%d%H%M%S')"
   grep -v -E '^intr|^btime' /proc/stat | sed "s/\(^.\)/$now \1/" >> $METRICS_FOLDER/linux.cpu.stats.csv 
   cat /proc/vmstat | sed "s/\(^.\)/$now \1/" >> $METRICS_FOLDER/linux.mem.stats.csv
   cat /proc/diskstats | sed 's/^[ \t]*//' | tr -s ' ' | sed "s/\(^.\)/$now \1/" >> $METRICS_FOLDER/linux.disk.stats.csv
   cat /proc/net/dev | sed 's/^[ \t]*//' | tr -s ' ' | sed "s/\(^.\)/$now \1/" >> $METRICS_FOLDER/linux.network.stats.csv


   # Collect cgroup metrics

   CG_ROOT=/sys/fs/cgroup

   while read fullname
   do

      filename=${fullname##$CG_ROOT}
      filename=${filename:1}
      filename=$(echo "$filename" | tr '/' '_')

      out=$METRICS_FOLDER/cgroup.$filename.samples
      echo "PGBSAMPLE $(date '+%Y%m%d%H%M%S')" >> $out
      cat $fullname >> $out

   done < <(find $CG_ROOT/ -type f | grep -vE 'cgroup.kill|memory.reclaim')

   #-- Process Monitoring -----------------------------------------------------

   while read record
   do

      pid=$(echo "$record" | cut -d '|' -f1)
      bck=$(echo "$record" | cut -d '|' -f2)
      bck=$(echo "$bck" | tr ' ' '_')

      # state(3), ppid(4), minflt(10), majflt(12), utime(14), systime(15), processor(39), delayacct_blkio_ticks(42)
      stat=$(cat /proc/$pid/stat | cut -d ' ' -f3,4,10,12,14,15,39,42)
      [ "$stat" != '' ] && echo "$pid $bck $stat" | sed "s/\(^.\)/$now \1/" >> $METRICS_FOLDER/linux.process.stats.csv

   done < <(QueryExec postgres "SELECT pid,backend_type FROM pg_stat_activity WHERE backend_type <> 'client backend'")



   ## Collect PostgreSQL Stats ################################################

   if [ "$(( WATCH_Loop % MOD_BgWriter ))" == "0" ]; then
      PrintMessage '' "   Collecting BgWriter Activity Stats @ $(date '+%Y%m%d%H%M%S')"
      collect_postgres_bgwriter_internal

      PrintMessage '' "   Collecting Replication Stats @ $(date '+%Y%m%d%H%M%S')"
      collect_postgres_replication_internal

      PrintMessage '' "   Collecting Backends Stats @ $(date '+%Y%m%d%H%M%S')"
      collect_postgres_backends_internal

   fi


   if [ "$(( WATCH_Loop % MOD_Databases ))" == "0" ]; then
      PrintMessage '' "   Collecting Databases Activity Stats @ $(date '+%Y%m%d%H%M%S')"
      collect_postgres_database_internal postgres
   fi



   if [ "$(( WATCH_Loop % MOD_Relations ))" == "0" ]; then 

      ### Extract Statistics from User Databases ##############################

      for db in $db_list
      do
      
         # Table Level Statistics
	 PrintMessage '' "   Collecting $db Table Activity Stats @ $(date '+%Y%m%d%H%M%S')"
         collect_postgres_table_internal $db

         # Index Level Statistics
	 PrintMessage '' "   Collecting $db Index Activity Stats @ $(date '+%Y%m%d%H%M%S')"
         collect_postgres_index_internal $db

      done

   fi


   if [ "$SAMPLE_BUFFER_CACHE" == "true" ] && [ $(( WATCH_Loop % MOD_BufferCache )) == "0" ] ; then

      ### Sample Shared Buffers (Can be expensive) ############################
      PrintMessage '' "   Collecting BufferCache Activity Stats @ $(date '+%Y%m%d%H%M%S')"
      collect_postgres_buffer_cache_internal

   fi


   PrintMessage '' ""

   ((WATCH_Loop++))

done
   


}





rdba() {

   classic

#
# RDBA
#
#  Storage
#
#    Collect used and free disk spaces
#      - data_directory
#      - pg_wal | pg_xlog
#      - tablespace locations
#      - /var (logs)
#
#    Collect inode consumptions
#
#  Activity
#
#    Collect long running transactions ( > 2 hours )
#    Collect unvacuumed tables (n_dead_tup / n_live_tup > x, relpages > y)
#
#  Parse PostgreSQL logs (FATAL,ERROR,slow queries, req checkpoints, temp files)
#
#  Trending
#     Used disk spaces
#     Table growth rates
#
#  Alerting
#    Alert when free diskspace <xGB, <x%
#    Alert when free inodes <x%
#    Alert when free disk space < 3 * largest table total size
#    Alert when running transaction older than 1 day
#    Alert when global ratio degrades (xact_rollback, blks_read, temp_bytes, ...)
  
#

   ### Linux ------------------------------------------------------------------


   ### PostgreSQL -------------------------------------------------------------

   #-- 


   q='SELECT '


}





###############################################################################
# Main ########################################################################
###############################################################################

#
# pg_benchmark -h --help --version
# pgbenchmark --project=xxx --scenario=foundation --store='dir or -' -v{1,3} --verbose
#
# Specific collect
# pg_benchmark collect -c --conninfo='...' -l --level='details|aggregates'
#                      --no-user-schema --user-data --postgres-only --system-only
#
# Specific analyze
# When --store points to a file, we analyze this file
# When --store points to a directory, we search for matching collections to analyze
# pg_benchmark analyze --store=...
#                      --scenario=matching_scenario --project=matching_project
# 


opts=$(getopt -o hc:l:v --long help,version,project:,scenario:,store:,conninfo:,port:,level:,watch-period:,watch-interval:,verbose,vv,vvv,no-user-schema,no-user-data,postgres-only,system-only,sample-buffer-cache,collect-dump \
              -n 'pg_benchmark' -- "$@")

if [ $? != 0 ] ; then

   PrintUsage
   exit $EXIT_FATAL
fi


eval set -- "$opts"

# General
PROJECT=default
SCENARIO=foundation
PROVIDED_PROJECT=false
PROVIDED_SCENARIO=false
STORE=$(pwd)
VERBOSE=0
CMD=collect

# Collect
PG_HOST=
PG_PORT=5432
PG_USER=postgres
PG_DBNAME=postgres
CONNINFO=
LEVEL='details'
USER_SCHEMA=true
USER_DATA=false
COLLECT_POSTGRES=true
COLLECT_SYSTEM=true
COLLECT_DUMP=false

WATCH_PERIOD=0
WATCH_INTERVAL=60
SAMPLE_BUFFER_CACHE=false

#
# Option Parsing
#

PROVIDED_PORT=1
PROVIDED_CONNINFO=1


while true; do
  case "$1" in

    -h | --help) PrintUsage; exit $EXIT_OK ;;
    --version) PrintVersion; exit $EXIT_OK ;;
    -v) ((VERBOSE++)); shift ;;
    --verbose ) VERBOSE=1; shift ;;

    --project) PROJECT="$2"; PROVIDED_PROJECT=true; shift 2 ;;
    --scenario) SCENARIO="$2"; PROVIDED_SCENARIO=true; shift 2 ;;
    --store) case "$2" in
	     -) STORE=/dev/stdout ;;
	     *) STORE="$2" ;;
             esac
	     shift 2
	     ;;

    -c | --conninfo)
            CONNINFO="$2";
            shift 2
            PROVIDED_CONNINFO=0
            while read kv
            do
               [[ "$kv" =~ 'host' ]] && PG_HOST=$(echo "$kv" | cut -d '=' -f2)
               [[ "$kv" =~ 'port' ]] && PG_PORT=$(echo "$kv" | cut -d '=' -f2)
               [[ "$kv" =~ 'user' ]] && PG_USER=$(echo "$kv" | cut -d '=' -f2)
               [[ "$kv" =~ 'dbname' ]] && PG_DBNAME=$(echo "$kv" | cut -d '=' -f2)
            done < <(echo "$CONNINFO" | sed -r 's/[[:alnum:]]+=/\n&/g')
#            if [ "$PG_HOST" = '' ] || [ "$PG_PORT" = '' ] ||  [ "$PG_USER" = '' ] || [ "$PG_DBNAME" = '' ]; then
#               echo 'ERROR: --conninfo is expected to set host, port, user and dbname.'
#               exit $EXIT_FATAL
#            fi
            ;;
    --port)
            PG_PORT="$2";
            PROVIDED_PORT=0
            shift 2 
            ;;
    -l | --level) LEVEL="$2"; shift 2 ;;

    --no-user-schema) USER_SCHEMA=false; shift ;;
    --user-data) USER_DATA=true; shift ;;

    --postgres-only ) COLLECT_SYSTEM=false; shift ;;
    --system-only ) COLLECT_POSTGRES=false; shift ;;

    --watch-period ) WATCH_PERIOD=$2; shift 2;;
    --watch-interval ) WATCH_INTERVAL=$2; shift 2;;

    --sample-buffer-cache ) SAMPLE_BUFFER_CACHE=true; shift ;;

    --collect-dump ) COLLECT_DUMP=true; shift ;;

    -- ) shift; break ;;
    * ) break ;;
  esac
done


# --port and --conninfo are exclusive
if [ $PROVIDED_PORT -eq 0 ] && [ $PROVIDED_CONNINFO -eq 0 ]; then
   echo 'ERROR: --port and --conninfo are exclusive, please provide only one of them.'
   echo 'HINT: --port is used for local access.'
   echo '      --conninfo is used for remote access only systems like RDS.'
   exit $EXIT_FATAL
fi




#
# Show Variable Contents on Debug
#

if [ "$VERBOSE" -gt 2 ]; then

   echo "---- Var Dump ------------------------------------"

   echo "# General"
   echo "   PROJECT='$PROJECT'"
   echo "   SCENARIO='$SCENARIO'"
   echo "   STORE='$STORE'"
   echo "   VERBOSE='$VERBOSE'"

   echo "# Collect"
   echo "   PG_PORT='$PG_PORT'"
   echo "   CONNINFO='$CONNINFO'"
   echo "   LEVEL='$LEVEL'"
   echo "   USER_SCHEMA='$USER_SCHEMA'"
   echo "   USER_DATA='$USER_DATA'"
   echo "   COLLECT_POSTGRES='$COLLECT_POSTGRES'"
   echo "   COLLECT_SYSTEM='$COLLECT_SYSTEM'"
   echo
   echo "Extra parameters: $@"

fi




#
# Make sure a valid command is selected
#

if [ "$1" != '' ]; then

   CMD="$1"

   cmd_list="collect analyze report"
   if [[ ! $cmd_list =~ $CMD ]]; then
      PrintMessage 'ERROR' "Command ""$CMD"" does not match ($cmd_list)"
      exit $EXIT_FATAL
   fi

fi



#
# Check consistency of provided options
#


# Project (check [a-ZA-Z0-9-_]+ only)
invalid_chars=$( echo "$PROJECT" | tr -d '[:alnum:]-_' )
if [ "$invalid_chars" != '' ]; then
   PrintMessage 'ERROR' "project name must be composed from 'a-z', 'A-Z', '0-9', '-' and '_'."
   exit $EXIT_FATAL;
fi


# Scenario in (foundation)
scenario_list="foundation classic watch"
if [[ ! $scenario_list =~ $SCENARIO ]]; then
   PrintMessage 'ERROR' "Unkown scenario ""$SCENARIO"""
   exit $EXIT_FATAL
fi




#
# Collect Relative Option Consistency Checking
#

if [ "$CMD" == "collect" ]; then

   # LEVEL in (details, aggregates)
   if [[ ! $LEVEL =~ details|aggregates ]]; then
      PrintMessage 'ERROR' "--level accepts either 'details' or 'aggregates'"
      exit $EXIT_FATAL
   fi


   # (COLLECT_SYSTEM, COLLECT_POSTGRES) != (false, false)
   if [ "$COLLECT_SYSTEM" == 'false' ] && [ "$COLLECT_POSTGRES" == 'false' ]; then
      PrintMessage 'ERROR' "Both options --system-only and --postgres-only have been provided."
      exit $EXIT_FATAL
   fi


   # USER_SCHEMA == false => USER_DATA = false
   if [ "$USER_SCHEMA" == 'false' ] && [ "$USER_DATA" == 'true' ]; then
      PrintMessage 'INFO' "Providing --no-user-schema forces --no-user-data"
      USER_DATA=false
   fi


   # Test Connection to Postgres
   
   PGSQL_SUDO=
   PGSQL_CONNINFO="port=$PG_PORT user=$PG_USER dbname=$PG_DBNAME connect_timeout=2"

   if [ "$PG_HOST" == '' ]; then
      PGSQL_SUDO='sudo -iu postgres'
      PGSQL_SUDO=''
   else
      PGSQL_CONNINFO="host=$PG_HOST $PGSQL_CONNINFO"
   fi
      
   PGSQL="$PGSQL_SUDO psql '$PGSQL_CONNINFO' -qAtc 'SELECT 1'"
   output=$(eval "$PGSQL")
   if [ $? != 0 ]; then
      PrintMessage 'ERROR' "Could not connect to PostgreSQL using $PGSQL"
      [ "$VERBOSE" -gt 0 ] && PrintfMessage 'DEBUG' "$output"
      exit $EXIT_PGFATAL
   fi


   # STORE - When directory, test existence or try to create

   if [ "$STORE" != '/dev/stdout' ]; then

      # Is Directory Existing
      if [ ! -d "$STORE/$PROJECT" ]; then
         # Try to create it
         output=$( mkdir -p "$STORE/$PROJECT" 2>&1)
         if [ $? != 0 ]; then
            PrintMessage 'ERROR' "Could not create ""$STORE/$PROJECT"""
            PrintMessage 'DEBUG' "$output"
            exit $EXIT_FATAL
         fi
      fi

      # Test Writable Directory
      if [ "$STORE" != '/dev/stdout' ]; then
         f="pg_benchmark_$RUN_HMS"
         output=$( touch "$STORE/$PROJECT/$f" 2>&1)
         if [ $? != 0 ]; then
            PrintMessage 'ERROR' "Could not create ""$STORE/$PROJECT/$f"""
            PrintMessage 'DEBUG' "$output"
            exit $EXIT_FATAL
         fi
         rm -f "$STORE/$PROJECT/$f"
      fi

   fi


fi


#
# Analyze Relative Option Consistency Checking
#

if [ "$CMD" == 'analyze' ]; then

   # Reject when --store=-

   if [ "$STORE" == '/dev/stdout' ]; then
      PrintMessage 'ERROR' 'analyze does not support --store=-'
      exit $EXIT_FATAL
   fi

fi

#
# Show Variable Contents on Debug
#

if [ "$VERBOSE" -gt 2 ]; then

   echo "---- Var Dump ------------------------------------"

   echo "# General"
   echo "   PROJECT='$PROJECT'"
   echo "   SCENARIO='$SCENARIO'"
   echo "   STORE='$STORE'"
   echo "   VERBOSE='$VERBOSE'"

   echo "# Collect"
   echo "   PG_PORT='$PG_PORT'"
   echo "   CONNINFO='$CONNINFO'"
   echo "   LEVEL='$LEVEL'"
   echo "   USER_SCHEMA='$USER_SCHEMA'"
   echo "   USER_DATA='$USER_DATA'"
   echo "   COLLECT_POSTGRES='$COLLECT_POSTGRES'"
   echo "   COLLECT_SYSTEM='$COLLECT_SYSTEM'"
   echo 
   echo "$@"

fi





###############################################################################
### COLLECT processing ########################################################
###############################################################################

if [ "$CMD" == 'collect' ]; then



   # Where to write Metrics (terminal versus file)
   METRICS_OUTPUT=/dev/stdout
   if [ "$STORE" != '/dev/stdout' ]; then

      METRICS_ROOT="$STORE/$PROJECT"
      METRICS_CONTEXT="$(hostname)""_""$SCENARIO""_""$RUN_HMS"
      METRICS_FOLDER="$METRICS_ROOT/$METRICS_CONTEXT"
      METRICS_OUTPUT="$METRICS_FOLDER"".collection"


      > $METRICS_OUTPUT

      if [ "$SCENARIO" != 'foundation' ]; then
         mkdir -p "$METRICS_FOLDER"
      fi

      PrintMessage 'INFO' "Metrics are being written to $METRICS_OUTPUT"
   fi


   PrintMessage '' "Project: $PROJECT"
   PrintMessage '' "Store: $STORE"
   PrintMessage '' "Scenario: $SCENARIO"
   PrintMessage '' "Command: $CMD"


   ### Publish Benchmark Support Relative Information ############################

   echo "benchmark.meta.collect.time=$RUN_HMS" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.time=$RUN_HMS"

   echo "benchmark.meta.project=$PROJECT" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.project=$PROJECT"

   echo "benchmark.meta.scenario=$SCENARIO" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.scenario=$SCENARIO"

   echo "benchmark.meta.command=$CMD" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.command=$CMD" 

   echo "benchmark.meta.collect.level=$LEVEL" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.level=$LEVEL"

   echo "benchmark.meta.collect.user_schema=$USER_SCHEMA" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.user_schema=$USER_SCHEMA"

   echo "benchmark.meta.collect.user_data=$USER_DATA" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.user_data=$USER_DATA" 

   echo "benchmark.meta.collect.postgres=$COLLECT_POSTGRES" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.postgres=$COLLECT_POSTGRES"

   echo "benchmark.meta.collect.system=$COLLECT_SYSTEM" >> $METRICS_OUTPUT
   [ "$VERBOSE" -gt 1 ] && PrintMessage 'META' "benchmark.meta.collect.system=$COLLECT_SYSTEM"


   benchmark_identify
   benchmark_describe

   ts_beg=$(date '+%s')

   eval "$SCENARIO"

   cd $METRICS_ROOT >/dev/null
   tar czf $METRICS_CONTEXT.tgz $METRICS_CONTEXT*
   cd - >/dev/null

   ts_end=$(date '+%s')
   PrintMessage '' "Scenario $SCENARIO has been running for $((ts_end - ts_beg)) seconds."

   
exit 10


   PrintMessage '' "Collect General Information"

   # Infosec: user-data=no, user-schema=no
   echo "benchmark.meta.collect_time=$RUN_HMS" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.collect_time=$RUN_HMS"


   #
   # Machine Identification
   # Infosec: user-data=no, user-schema=no, potential leak
   #

   # system_uuid=$(dmidecode -s system-uuid)
   # echo "benchmark.meta.system_uuid=$system_uuid" >> $METRICS_OUTPUT
   # PrintMessage 'DATA' "benchmark.meta.system_uuid=$system_uuid"

   host_name=$(hostname)
   echo "benchmark.meta.host_name=$host_name" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.host_name=$host_name"

   host_ip=$(hostname -I | cut -d ' ' -f1)
   echo "benchmark.meta.host_ip=$host_ip" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.host_ip=$host_ip"


   #
   # Machine RAM
   # Infosec: user-data=no, user-schema=no
   #

   # host_ram=$(dmidecode -t 17 | grep 'Size:' | \
	#       grep -v 'No Module Installed' | \
	#       tr -s ' ' | cut -d ' ' -f2 | \
	#       awk '{ sum += $1 } END { print sum }')
   # echo "benchmark.meta.host_ram=$host_ram" >> $METRICS_OUTPUT
   # PrintMessage 'DATA' "benchmark.meta.host_ram=$host_ram"


   #
   # Machine Local Disk Sizes
   # Infosec: user-data=no, user-schema=no
   #

   local_disk_sizes=
   while read entry
   do

      dev=`echo "$entry"| tr -s ' ' | cut -d ' ' -f1`
      siz=`echo "$entry"| tr -s ' ' | cut -d ' ' -f4`
      echo "benchmark.meta.host_""$dev""=""$siz" >> $METRICS_OUTPUT

      local_disk_sizes="$local_disk_sizes / $siz"

   done < <(lsblk | grep '^[hs]d[a-z]')

   local_disk_sizes=${local_disk_sizes:3}
   echo "benchmark.meta.host_disk_sizes=$local_disk_sizes" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.host_disk_sizes=$local_disk_sizes"


   #
   # PostgreSQL Cluster Name
   # Infosec: user-data=no, user-schema=yes
   #

   query='SHOW cluster_name'
   cluster_name=`QueryExec postgres "$query"`
   echo "benchmark.meta.postgresql.cluster_name=$cluster_name" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.postgresql.cluster_name=$cluster_name"


   #
   # PostgreSQL Cluster Disk Size
   # Infosec: user-data=no, user-schema=no
   #

   query='SHOW data_directory'
   pgdata=`QueryExec postgres "$query"`
   cluster_size=`du -sBG $pgdata | cut -f1`
   echo "benchmark.meta.postgresql.cluster_size=$cluster_size" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.postgresql.cluster_size=$cluster_size"


   #
   # PostgreSQL Shared_Buffers
   # Infosec: user-data=no, user-schema=no
   #

   query='SHOW shared_buffers'
   cluster_sb=`QueryExec postgres "$query"`
   echo "benchmark.meta.postgresql.shared_buffers=$cluster_sb" >> $METRICS_OUTPUT
   PrintMessage 'DATA' "benchmark.meta.postgresql.shared_buffers=$cluster_sb"



   ### Publish Linux and PostgreSQL Information ###############################


   if [ "$COLLECT_SYSTEM" == true ]; then

      PrintMessage '' "Collecting Linux Information"

      #-- OS Linux Basic Informations ----------------------------------------#
      # Infosec: user-data=no, user-schema=no
      #

      os_release=$(grep 'PRETTY_NAME=' /etc/*-release | tr -d '"' | cut -d '=' -f2)
      echo "linux.os.name.pretty=$os_release" >> $METRICS_OUTPUT

      os_kernel=$(uname -r)
      echo "linux.os.kernel=$os_kernel" >> $METRICS_OUTPUT


      #
      # IP Adresses
      # Infosec: user-data=no, user-schema=no
      #

      ip_local=`hostname -I | cut -d ' ' -f1`
      echo "linux.ip.local=$ip_local" >> $METRICS_OUTPUT


      #-- OS Linux - CPU Information ------------------------------------------
      # Infosec: user-data=no, user-schema=no
      #

      PrintMessage '' "Gathering CPU Information"

      info=`grep '^model name' /proc/cpuinfo`
      model=`echo "$info" | head -n 1 | cut -d ':' -f2`
      count=`echo "$info" | wc -l`

      echo "linux.cpu.count=$count" >> $METRICS_OUTPUT
      echo "linux.cpu.model=${model:1}" >> $METRICS_OUTPUT

      echo "benchmark.meta.host_cpu_count=$count" >> $METRICS_OUTPUT

      governor="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
      [ "$governor" == '' ] && governor='virtualized'
      echo "linux.cpu.governor=$governor" >> $METRICS_OUTPUT



      #-- OS Linux - Memory Information --------------------------------------#
      # Infosec: user-data=no, user-schema=no
      #

      PrintMessage '' "Gathering Memory Information"

      cat /proc/meminfo | \
          tr ':' '='| tr -d ' ' | sed 's/kB$//' | \
          sed 's/^/linux\.meminfo\./' >> $METRICS_OUTPUT


      #-- OS Linux - sysctl Information ---------------------------------------
      # Infosec: user-data=no, user-schema=no
      #

      PrintMessage '' "Gathering Kernel Information"

      sysctl -a 2>/dev/null | \
             tr -d ' ' | grep -E '^kernel|^vm' |\
             sed 's/^/linux\.sysctl\./' >> $METRICS_OUTPUT


      #-- OS Linux - other ----------------------------------------------------
      # Infosec: user-data=no, user-schema=no
      #

      info=`cat /sys/kernel/mm/transparent_hugepage/enabled | cut -d '[' -f2 | cut -d ']' -f1`
      echo "linux.other.mm.transparent_hugepage.enabled=$info" >> $METRICS_OUTPUT

   fi




   if [ "$COLLECT_POSTGRES" == true ]; then

      PrintMessage '' "Collecting PostgreSQL Information"

      #--- PostgreSQL Versioning ----------------------------------------------
      # Infosec: user-data=no, user-schema=no
      #

      pg_version=`QueryExec postgres "show server_version" | cut -d ' ' -f1`
      pg_version_major=${pg_version%.*}
      pg_version_minor=${pg_version##*.}

      pg_version_num=`QueryExec postgres "show server_version_num"`


      #
      # Get Cluster system_identifier
      # Infosec: user-data=no, user-schema=no
      #

      if [ "$pg_version_num" -ge 90600 ]; then
         query='SELECT system_identifier FROM pg_control_system()'
	 pg_id=`QueryExec postgres "$query"`
         echo "postgresql.live.system_identifier=$pg_id" >> $METRICS_OUTPUT
	 echo "benchmark.meta.pg_system_identifier=$pg_id" >> $METRICS_OUTPUT

#      else
#         # Experimental way
#	 bindir=$(pg_config | grep '^BINDIR = ' | cut -d ' ' -f3)
#	 datadir=$(grep 'postgresql.guc.data_directory=' $METRICS_OUTPUT | cut -d '=' -f2)
#        pg_systemid=$($bindir/pg_controldata -D $datadir | \
#                      grep 'Database system identifier' | cut -d ':' -f2 | tr -d ' ')


      fi


      #--- PostgreSQL Setting Values ------------------------------------------
      # Infosec: user-data=no, user-schema=yes
      #

      QueryExec postgres "SELECT name || '=' || setting FROM pg_settings" \
                | sed 's/^/postgresql\.guc\./' >> $METRICS_OUTPUT


      #--- PostgreSQL Live Metrics --------------------------------------------


      # Counting Active Replication Streams
      # Infosec: user-data=no, user-schema=no
      #

      if [ "$pg_version_num" -ge '90200' ]; then
         query='SELECT count(*) FROM pg_stat_replication'
         count=`QueryExec postgres "$query"`
         echo "postgresql.live.replication.streams=$count" >> $METRICS_OUTPUT
      fi


      # Counting Active Replication Slots
      # Infosec: user-data=no, user-schema=no
      #
      if [ "$pg_version_num" -ge '90400' ]; then
         query='SELECT count(*) FROM pg_replication_slots'
         count=`QueryExec postgres "$query"`
         echo "postgresql.live.replication.slots=$count" >> $METRICS_OUTPUT
      fi


      # Counting User Tables whose (auto)vacuum count is zero and seq_scan > 0
      # Infosec: user-data=no, user-schema=no
      #
#      query='
#         SELECT count(*)
#         FROM pg_stat_user_tables
#         WHERE (vacuum_count = 0 OR vacuum_count IS NULL)
#           AND (autovacuum_count = 0 OR autovacuum_count IS NULL) AND seq_scan > 0
#      '
#      count=`QueryExec "$query"`
#      echo "postgresql.live.user_tables.unvacuumed.count=$count" >> $METRICS_OUTPUT


      # Counting User Tables whose vacuum is late
      # Infosec: user-data=no, user-schema=no
      #
#      query="
#         SELECT count(*)
#         FROM pg_stat_user_tables
#         WHERE n_dead_tup > 1000
#           AND n_live_tup > 1000
#           AND 1.05::float * (current_setting('autovacuum_vacuum_threshold')::float
#               + current_setting('autovacuum_vacuum_scale_factor')::float * n_live_tup::float)
#               < n_dead_tup
#      "
#      count=`QueryExec "$query"`
#      echo "postgresql.live.user_tables.latevacuum.count=$count" >> $METRICS_OUTPUT


      # Counting Additionnal Tablespaces
      # Infosec: user-data=no, user-schema=no
      #
      if [ "$pg_version_num" -ge '90200' ]; then
         query="SELECT count(*) FROM pg_tablespace WHERE spcname NOT IN ('pg_default','pg_global')"
         count=`QueryExec postgres "$query"`
         echo "postgresql.live.tablespaces=$count" >> $METRICS_OUTPUT
      fi


      # Counting Application Users
      # Infosec: user-data=no, user-schema=no
      #
      query="
         SELECT count(*)
         FROM pg_user
         WHERE usesuper = 'f' AND userepl = 'f'
      "
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.application.user.count=$count" >> $METRICS_OUTPUT

      # Counting Replication Users
      # Infosec: user-data=no, user-schema=no
      #
      query="
         SELECT count(*)
         FROM pg_user
         WHERE usesuper = 'f' AND userepl = 't'
      "
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.replication.user.count=$count" >> $METRICS_OUTPUT





      # Counting pg_db_role_setting Entries
      # Critical for Operability and Audit
      # Content shall be explored by hand
      # Infosec: user-data=no, user-schema=no (counting version)
      #
      query="
         SELECT coalesce(role.rolname, 'database wide') as role, 
                coalesce(db.datname, 'cluster wide') as database, 
                setconfig as what_changed
         FROM pg_db_role_setting role_setting
         LEFT JOIN pg_roles role ON role.oid = role_setting.setrole
         LEFT JOIN pg_database db ON db.oid = role_setting.setdatabase;
      "

      query="SELECT count(*) FROM pg_db_role_setting"
      count=`QueryExec postgres "$query"`
      echo "postgresql.live.db_role_setting.entry.count=$count" >> $METRICS_OUTPUT


   fi # COLLECT_POSTGRES


   if [ "$COLLECT_SYSTEM" == true ] && [ "$COLLECT_POSTGRES" == true ]; then

      PrintMessage '' "Collecting Storage Information"


      #--- Disk Space ---------------------------------------------------------

      #
      # Track 'nobarrier' FS
      # Infosec: user-data=no, user-schema=no
      #

      nobarrier_count=$(mount -l | grep 'nobarrier' | wc -l)
      echo "linux.fs.nobarrier.count=$nobarrier_count" >> $METRICS_OUTPUT


      #
      # Disk Space Examination is required to prevent ourselves from being pushed into
      # terrible situations due to no free disk space...
      #


      # TODO: Should pay attention to tablespaces (to be done in a future release)


      #
      # PostgreSQL Cluster
      # Infosec: user-data=no, user-schema=no
      #

      if [ "$METRICS_OUTPUT" != '/dev/stdout' ]; then

         data_directory="$(grep 'postgresql.guc.data_directory=' $METRICS_OUTPUT | cut -d '=' -f2)"

         data_directory_df_entry=$(df -BM $data_directory | tail -1 | tr -s ' ')

         data_directory_df_freeMB=$(echo "$data_directory_df_entry" | cut -d ' ' -f4 | \
		                    sed 's/[a-zA-Z]//')
         echo "linux.live.pgdata.freespace_MB=$data_directory_df_freeMB" >> $METRICS_OUTPUT
 
      fi



      #
      # Get free disk space on device where pg_wal is located
      # Infosec: user-data=no, user-schema=no
      #

      if [ "$METRICS_OUTPUT" != '/dev/stdout' ]; then
  
         wal_dir="$(grep 'postgresql.guc.data_directory=' $METRICS_OUTPUT | cut -d '=' -f2)"
         [ -e "$wal_dir""/pg_xlog" ] && wal_dir="$wal_dir""/pg_xlog"
         [ -e "$wal_dir""/pg_wal" ] && wal_dir="$wal_dir""/pg_wal"

         wal_free_diskspace_MB=$(df -BM $wal_dir | tail -1 | tr -s ' ' | \
		                 cut -d ' ' -f4 | sed 's/[a-zA-Z]//')
         echo "linux.live.wal.freespace_MB=$wal_free_diskspace_MB" >> $METRICS_OUTPUT

      fi


   fi # COLLECT SYSTEM + POSTGRES

fi # COLLECT




###############################################################################
### ANALYZE processing ########################################################
###############################################################################


if [ "$CMD" == 'analyze' ]; then


   # STORE can point to either
   #      a specific collection
   #   or a directory with many collections (support multi-level directories)

   filter="find $STORE | grep '.collection$'"

   # Update filter accordingly to provided project and scenario tags
   if [ -d "$STORE" ]; then

      # Update Filter
      [ "$PROVIDED_SCENARIO" == true ] && filter="$filter | grep '$SCENARIO'"
      [ "$PROVIDED_PROJECT" == true ] && filter="$filter | grep '$PROJECT'"

   fi

   # Process Collections
   while read collection
   do
      # Skip Collection When Existing Analysis
      analysis="${collection%%.collection}.analysis"
      if [ -f "$analysis" ]; then
         PrintMessage 'Skip' "$collection"
         continue
      fi

      collection_scenario=$(echo "$collection" | grep -o '[^/]*$' | cut -d '_' -f2)
      PrintMessage 'Analyze' "$collection ($collection_scenario)"
      ./DB_Analyzer.sh "templates/$collection_scenario/analyze.json" "$collection"

   done < <(eval "$filter")


fi





###############################################################################
### REPORT processing #########################################################
###############################################################################


if [ "$CMD" == 'report' ]; then


   # STORE can point to either
   #      a specific analysis
   #   or a directory with many analyses (support multi-level directories)

   filter="find $STORE | grep '.analysis$'"

   # Update filter accordingly to provided project and scenario tags
   if [ -d "$STORE" ]; then

      # Update Filter
      [ "$PROVIDED_SCENARIO" == true ] && filter="$filter | grep '$SCENARIO'"
      [ "$PROVIDED_PROJECT" == true ] && filter="$filter | grep '$PROJECT'"

   fi

   # Process Analyses
   while read analysis
   do
      # Skip Analysis When Existing Report
      report="${analysis%%.analysis}.report.pdf"
      if [ -f "$report" ]; then
         PrintMessage 'Skip' "$analysis"
         continue
      fi

      analysis_scenario=$(echo "$analysis" | grep -o '[^/]*$' | cut -d '_' -f2)
      analysis_filename=$(basename "$analysis")

      # Localize Execution Context
      current_path=$(pwd)
      forge_path="$current_path/report_forge"
      mkdir -p "$forge_path"

      ###template_base='template_report_'$analysis_scenario
      cp "templates/$analysis_scenario/report.md" "$forge_path"
      cp "$analysis" "$forge_path"
      cp "${analysis%%.analysis}/export/classic.bgwriter.stats.md" "$forge_path"
      cp "${analysis%%.analysis}/export/classic.checkpoint.stats.md" "$forge_path"
      cp "${analysis%%.analysis}/export/classic.checkpoint.average.stats.md" "$forge_path"


      # Include TOP20 for Classic and Watch scenarios

      if [[ "$analysis_scenario" == 'classic' || "$analysis_scenario" == 'watch' ]]; then

         # List exported datasets and build Markdown Array then move to forge

         cp "${analysis%%.analysis}"/export/top20* "$forge_path"

	 # Produce markdown hierarchy of TOP 20 Indexes CSV datasets
         ./list_to_hierarchy.sh \
		 $forge_path/top20_indexes_never_used.stats.csv \
		 $forge_path/top20_indexes_never_used.stats.md
	 ./list_to_hierarchy.sh \
		 $forge_path/top20_indexes_used_outside_watched_period.stats.csv \
                 $forge_path/top20_indexes_used_outside_watched_period.stats.md
	 ./list_to_hierarchy.sh \
		 $forge_path/top20_indexes_used_over_watched_period.stats.csv \
		 $forge_path/top20_indexes_used_over_watched_period.stats.md


#         while read csv
#         do
#            csv_base=$(basename $csv)
#            sed "s/\(^.*$\)/| \1 | /" $csv > "$forge_path/$csv_base"
#
#         done < <(ls -1 "${analysis%%.analysis}"/export/top20*)

      fi

      # Include Graphics
      if [ "$analysis_scenario" == 'watch' ]; then
         cp -r "${analysis%%.analysis}/images" "$forge_path"
         cat "${analysis%%.analysis}/images/gnuplot.postgres.md" >> "$forge_path/report.md"
         cat "${analysis%%.analysis}/images/gnuplot.linux.md" >> "$forge_path/report.md"
      fi

      cd $forge_path

      PrintMessage 'Report' "$analysis ($analysis_scenario)"

      pandoc=$(whereis pandoc-easy | cut -d ' ' -f2-)
      mv report.md report.md.j2
      mv  $analysis_filename ${analysis_filename}.json
      eval "$pandoc report.md.j2 --datafile=${analysis_filename}.json"
      eval "$pandoc -vvv report.md"
#      $pandoc report.md.j2 --datafile=${analysis_filename}.json
#      $pandoc report.md



      forge_result=$(ls -1 report*.pdf)
      [ "$forge_result" != '' ] && mv "$forge_result" "$report"

      forge_result=$(ls -1 report.md)
      [ "$forge_result" != '' ] && mv "$forge_result" "$report.md"

      cd "$current_path"
      rm -rf "$forge_path"

   done < <(eval "$filter")


fi

