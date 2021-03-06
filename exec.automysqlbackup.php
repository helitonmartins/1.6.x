<?php


function buildconfig(){
	
	$unix=new unix();
	$hostname=$unix->hostname_g();
	
	$f[]="#version=3.0_rc2";
	$f[]="# DONT'T REMOVE THE PREVIOUS VERSION LINE!";
	$f[]="#";
	$f[]="# Uncomment to change the default values (shown after =)";
	$f[]="# WARNING:";
	$f[]="# This is not true for UMASK, CONFIG_prebackup and CONFIG_postbackup!!!";
	$f[]="#";
	$f[]="# Default values are stored in the script itself. Declarations in";
	$f[]="# /etc/automysqlbackup/automysqlbackup.conf will overwrite them. The";
	$f[]="# declarations in here will supersede all other.";
	$f[]="";
	$f[]="# Edit \$PATH if mysql and mysqldump are not located in /usr/local/bin:/usr/bin:/bin:/usr/local/mysql/bin";
	$f[]="#PATH=\${PATH}:FULL_PATH_TO_YOUR_DIR_CONTAINING_MYSQL:FULL_PATH_TO_YOUR_DIR_CONTAINING_MYSQLDUMP";
	$f[]="";
	$f[]="# Basic Settings";
	$f[]="";
	$f[]="# Username to access the MySQL server e.g. dbuser";
	$f[]="CONFIG_mysql_dump_username='root'";
	$f[]="";
	$f[]="# Password to access the MySQL server e.g. password";
	$f[]="CONFIG_mysql_dump_password=''";
	$f[]="";
	$f[]="# Host name (or IP address) of MySQL server e.g localhost";
	$f[]="CONFIG_mysql_dump_host='localhost'";
	$f[]="";
	$f[]="# \"Friendly\" host name of MySQL server to be used in email log";
	$f[]="# if unset or empty (default) will use CONFIG_mysql_dump_host instead";
	$f[]="CONFIG_mysql_dump_host_friendly='$hostname'";
	$f[]="";
	$f[]="# Backup directory location e.g /backups";
	$f[]="CONFIG_backup_dir='/home/artica/backup/$hostname/MySQL-databases'";
	$f[]="";
	$f[]="# This is practically a moot point, since there is a fallback to the compression";
	$f[]="# functions without multicore support in the case that the multicore versions aren't";
	$f[]="# present in the system. Of course, if you have the latter installed, but don't want";
	$f[]="# to use them, just choose no here.";
	$f[]="# pigz -> gzip";
	$f[]="# pbzip2 -> bzip2";
	$f[]="CONFIG_multicore='no'";
	$f[]="";
	$f[]="# Number of threads (= occupied cores) you want to use. You should - for the sake";
	$f[]="# of the stability of your system - not choose more than (#number of cores - 1).";
	$f[]="# Especially if the script is run in background by cron and the rest of your system";
	$f[]="# has already heavy load, setting this too high, might crash your system. Assuming";
	$f[]="# all systems have at least some sort of HyperThreading, the default is 2 threads.";
	$f[]="# If you wish to let pigz and pbzip2 autodetect or use their standards, set it to";
	$f[]="# 'auto'.";
	$f[]="#CONFIG_multicore_threads=2";
	$f[]="";
	$f[]="# Databases to backup";
	$f[]="";
	$f[]="# List of databases for Daily/Weekly Backup e.g. ( 'DB1' 'DB2' 'DB3' ... )";
	$f[]="# set to (), i.e. empty, if you want to backup all databases";
	$f[]="#CONFIG_db_names=()";
	$f[]="# You can use";
	$f[]="#declare -a MDBNAMES=( \"\${DBNAMES[@]}\" 'added entry1' 'added entry2' ... )";
	$f[]="# INSTEAD to copy the contents of \$DBNAMES and add further entries (optional).";
	$f[]="";
	$f[]="# List of databases for Monthly Backups.";
	$f[]="# set to (), i.e. empty, if you want to backup all databases";
	$f[]="#CONFIG_db_month_names=()";
	$f[]="";
	$f[]="# List of DBNAMES to EXLUCDE if DBNAMES is empty, i.e. ().";
	$f[]="CONFIG_db_exclude=( 'information_schema' )";
	$f[]="";
	$f[]="# List of tables to exclude, in the form db_name.table_name";
	$f[]="# You may use wildcards for the table names, i.e. 'mydb.a*' selects all tables starting with an 'a'.";
	$f[]="# However we only offer the wildcard '*', matching everything that could appear, which translates to the";
	$f[]="# '%' wildcard in mysql.";
	$f[]="#CONFIG_table_exclude=()";
	$f[]="";
	$f[]="";
	$f[]="# Advanced Settings";
	$f[]="";
	$f[]="# Rotation Settings";
	$f[]="";
	$f[]="# Which day do you want monthly backups? (01 to 31)";
	$f[]="# If the chosen day is greater than the last day of the month, it will be done";
	$f[]="# on the last day of the month.";
	$f[]="# Set to 0 to disable monthly backups.";
	$f[]="#CONFIG_do_monthly=\"01\"";
	$f[]="";
	$f[]="# Which day do you want weekly backups? (1 to 7 where 1 is Monday)";
	$f[]="# Set to 0 to disable weekly backups.";
	$f[]="#CONFIG_do_weekly=\"5\"";
	$f[]="";
	$f[]="# Set rotation of daily backups. VALUE*24hours";
	$f[]="# If you want to keep only today's backups, you could choose 1, i.e. everything older than 24hours will be removed.";
	$f[]="CONFIG_rotation_daily=2";
	$f[]="";
	$f[]="# Set rotation for weekly backups. VALUE*24hours";
	$f[]="CONFIG_rotation_weekly=35";
	$f[]="";
	$f[]="# Set rotation for monthly backups. VALUE*24hours";
	$f[]="CONFIG_rotation_monthly=150";
	$f[]="";
	$f[]="";
	$f[]="# Server Connection Settings";
	$f[]="";
	$f[]="# Set the port for the mysql connection";
	$f[]="#CONFIG_mysql_dump_port=3306";
	$f[]="";
	$f[]="# Compress communications between backup server and MySQL server?";
	$f[]="#CONFIG_mysql_dump_commcomp='no'";
	$f[]="";
	$f[]="# Use ssl encryption with mysqldump?";
	$f[]="CONFIG_mysql_dump_usessl='no'";
	$f[]="";
	$f[]="# For connections to localhost. Sometimes the Unix socket file must be specified.";
	$f[]="CONFIG_mysql_dump_socket='/var/run/mysqld/mysqld.sock'";
	$f[]="";
	$f[]="# The maximum size of the buffer for client/server communication. e.g. 16MB (maximum is 1GB)";
	$f[]="#CONFIG_mysql_dump_max_allowed_packet=''";
	$f[]="";
	$f[]="# This option sends a START TRANSACTION SQL statement to the server before dumping data. It is useful only with";
	$f[]="# transactional tables such as InnoDB, because then it dumps the consistent state of the database at the time";
	$f[]="# when BEGIN was issued without blocking any applications.";
	$f[]="#";
	$f[]="# When using this option, you should keep in mind that only InnoDB tables are dumped in a consistent state. For";
	$f[]="# example, any MyISAM or MEMORY tables dumped while using this option may still change state.";
	$f[]="#";
	$f[]="# While a --single-transaction dump is in process, to ensure a valid dump file (correct table contents and";
	$f[]="# binary log coordinates), no other connection should use the following statements: ALTER TABLE, CREATE TABLE,";
	$f[]="# DROP TABLE, RENAME TABLE, TRUNCATE TABLE. A consistent read is not isolated from those statements, so use of";
	$f[]="# them on a table to be dumped can cause the SELECT that is performed by mysqldump to retrieve the table";
	$f[]="# contents to obtain incorrect contents or fail.";
	$f[]="#CONFIG_mysql_dump_single_transaction='no'";
	$f[]="";
	$f[]="# http://dev.mysql.com/doc/refman/5.0/en/mysqldump.html#option_mysqldump_master-data";
	$f[]="# --master-data[=value] ";
	$f[]="# Use this option to dump a master replication server to produce a dump file that can be used to set up another";
	$f[]="# server as a slave of the master. It causes the dump output to include a CHANGE MASTER TO statement that indicates";
	$f[]="# the binary log coordinates (file name and position) of the dumped server. These are the master server coordinates";
	$f[]="# from which the slave should start replicating after you load the dump file into the slave.";
	$f[]="#";
	$f[]="# If the option value is 2, the CHANGE MASTER TO statement is written as an SQL comment, and thus is informative only;";
	$f[]="# it has no effect when the dump file is reloaded. If the option value is 1, the statement is not written as a comment";
	$f[]="# and takes effect when the dump file is reloaded. If no option value is specified, the default value is 1.";
	$f[]="#";
	$f[]="# This option requires the RELOAD privilege and the binary log must be enabled. ";
	$f[]="#";
	$f[]="# The --master-data option automatically turns off --lock-tables. It also turns on --lock-all-tables, unless";
	$f[]="# --single-transaction also is specified, in which case, a global read lock is acquired only for a short time at the";
	$f[]="# beginning of the dump (see the description for --single-transaction). In all cases, any action on logs happens at";
	$f[]="# the exact moment of the dump.";
	$f[]="# ==================================================================================================================";
	$f[]="# possible values are 1 and 2, which correspond with the values from mysqldump";
	$f[]="# VARIABLE=    , i.e. no value, turns it off (default)";
	$f[]="#";
	$f[]="#CONFIG_mysql_dump_master_data=";
	$f[]="";
	$f[]="# Included stored routines (procedures and functions) for the dumped databases in the output. Use of this option";
	$f[]="# requires the SELECT privilege for the mysql.proc table. The output generated by using --routines contains";
	$f[]="# CREATE PROCEDURE and CREATE FUNCTION statements to re-create the routines. However, these statements do not";
	$f[]="# include attributes such as the routine creation and modification timestamps. This means that when the routines";
	$f[]="# are reloaded, they will be created with the timestamps equal to the reload time.";
	$f[]="#";
	$f[]="# If you require routines to be re-created with their original timestamp attributes, do not use --routines. Instead,";
	$f[]="# dump and reload the contents of the mysql.proc table directly, using a MySQL account that has appropriate privileges";
	$f[]="# for the mysql database. ";
	$f[]="#";
	$f[]="# This option was added in MySQL 5.0.13. Before that, stored routines are not dumped. Routine DEFINER values are not";
	$f[]="# dumped until MySQL 5.0.20. This means that before 5.0.20, when routines are reloaded, they will be created with the";
	$f[]="# definer set to the reloading user. If you require routines to be re-created with their original definer, dump and";
	$f[]="# load the contents of the mysql.proc table directly as described earlier.";
	$f[]="#";
	$f[]="CONFIG_mysql_dump_full_schema='yes'";
	$f[]="";
	$f[]="# Backup status of table(s) in textfile. This is very helpful when restoring backups, since it gives an idea, what changed";
	$f[]="# in the meantime.";
	$f[]="CONFIG_mysql_dump_dbstatus='yes'";
	$f[]="";
	$f[]="# Backup dump settings";
	$f[]="";
	$f[]="# Include CREATE DATABASE in backup?";
	$f[]="CONFIG_mysql_dump_create_database='yes'";
	$f[]="";
	$f[]="# Separate backup directory and file for each DB? (yes or no)";
	$f[]="#CONFIG_mysql_dump_use_separate_dirs='yes'";
	$f[]="";
	$f[]="# Choose Compression type. (gzip or bzip2)";
	$f[]="CONFIG_mysql_dump_compression='gzip'";
	$f[]="";
	$f[]="# Store an additional copy of the latest backup to a standard";
	$f[]="# location so it can be downloaded by third party scripts.";
	$f[]="#CONFIG_mysql_dump_latest='no'";
	$f[]="";
	$f[]="# Remove all date and time information from the filenames in the latest folder.";
	$f[]="# Runs, if activated, once after the backups are completed. Practically it just finds all files in the latest folder";
	$f[]="# and removes the date and time information from the filenames (if present).";
	$f[]="CONFIG_mysql_dump_latest_clean_filenames='no'";
	$f[]="";
	$f[]="# Create differential backups. Master backups are created weekly at #\$CONFIG_do_weekly weekday. Between master backups,";
	$f[]="# diff is used to create differential backups relative to the latest master backup. In the Manifest file, you find the";
	$f[]="# following structure";
	$f[]="# \$filename 	md5sum	\$md5sum	diff_id	\$diff_id	rel_id	\$rel_id";
	$f[]="# where each field is separated by the tabular character '\t'. The entries with \$ at the beginning mean the actual values,";
	$f[]="# while the others are just for readability. The diff_id is the id of the differential or master backup which is also in";
	$f[]="# the filename after the last _ and before the suffixes begin, i.e. .diff, .sql and extensions. It is used to relate";
	$f[]="# differential backups to master backups. The master backups have 0 as \$rel_id and are thereby identifiable. Differential";
	$f[]="# backups have the id of the corresponding master backup as \$rel_id.";
	$f[]="#";
	$f[]="# To ensure that master backups are kept long enough, the value of \$CONFIG_rotation_daily is set to a minimum of 21 days.";
	$f[]="#";
	$f[]="#CONFIG_mysql_dump_differential='no'";
	$f[]="";
	$f[]="";
	$f[]="# Notification setup";
	$f[]="";
	$f[]="# What would you like to be mailed to you?";
	$f[]="# - log   : send only log file";
	$f[]="# - files : send log file and sql files as attachments (see docs)";
	$f[]="# - stdout : will simply output the log to the screen if run manually.";
	$f[]="# - quiet : Only send logs if an error occurs to the MAILADDR.";
	$f[]="#CONFIG_mailcontent='stdout'";
	$f[]="";
	$f[]="# Set the maximum allowed email size in k. (4000 = approx 5MB email [see docs])";
	$f[]="#CONFIG_mail_maxattsize=4000";
	$f[]="";
	$f[]="# Allow packing of files with tar and splitting it in pieces of CONFIG_mail_maxattsize.";
	$f[]="#CONFIG_mail_splitandtar='yes'";
	$f[]="";
	$f[]="# Use uuencode instead of mutt. WARNING: Not all email clients work well with uuencoded attachments.";
	$f[]="#CONFIG_mail_use_uuencoded_attachments='no'";
	$f[]="";
	$f[]="# Email Address to send mail to? (user@domain.com)";
	$f[]="#CONFIG_mail_address='root'";
	$f[]="";
	$f[]="";
	$f[]="# Encryption";
	$f[]="";
	$f[]="# Do you wish to encrypt your backups using openssl?";
	$f[]="CONFIG_encrypt='no'";
	$f[]="";
	$f[]="# Choose a password to encrypt the backups.";
	$f[]="#CONFIG_encrypt_password='password0123'";
	$f[]="";
	$f[]="# Other";
	$f[]="";
	$f[]="# Backup local files, i.e. maybe you would like to backup your my.cnf (mysql server configuration), etc.";
	$f[]="# These files will be tar'ed, depending on your compression option CONFIG_mysql_dump_compression compressed and";
	$f[]="# depending on the option CONFIG_encrypt encrypted.";
	$f[]="#";
	$f[]="# Note: This could also have been accomplished with CONFIG_prebackup or CONFIG_postbackup.";
	$f[]="#CONFIG_backup_local_files=()";
	$f[]="";
	$f[]="# Command to run before backups (uncomment to use)";
	$f[]="#CONFIG_prebackup=\"/etc/mysql-backup-pre\"";
	$f[]="";
	$f[]="# Command run after backups (uncomment to use)";
	$f[]="#CONFIG_postbackup=\"/etc/mysql-backup-post\"";
	$f[]="";
	$f[]="# Uncomment to activate! This will give folders rwx------";
	$f[]="# and files rw------- permissions.";
	$f[]="#umask 0077";
	$f[]="";
	$f[]="# dry-run, i.e. show what you are gonna do without actually doing it";
	$f[]="# inactive: =0 or commented out";
	$f[]="# active: uncommented AND =1";
	$f[]="#CONFIG_dryrun=1";
	$f[]="";
}