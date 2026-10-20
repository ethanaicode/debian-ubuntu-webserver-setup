#!/bin/bash
set -o pipefail

# MySQL backup script
# Recommended to place this script for /usr/local/bin/db_backup.sh

DATE=$(date +%Y%m%d)
BACKUP_DIR="/www/backup/db"
BACKUP_MODE="list" # Set to "all" or "list"

# Used when BACKUP_MODE is "all".
ALL_DB_USER="root"
ALL_DB_PASSWORD="YourPassword"

# Used when BACKUP_MODE is "list". Values at the same index form one database config.
DB_USERS=("user1" "user2")
DB_PASSWORDS=("password1" "password2")
DB_NAMES=("database1" "database2")

BACKUP_FAILED=0
CURRENT_TEMP_FILE=""
trap 'if [ -n "$CURRENT_TEMP_FILE" ]; then rm -f "$CURRENT_TEMP_FILE"; fi' EXIT

backup_dump() {
	local backup_name="$1"
	shift
	local backup_file="$BACKUP_DIR/${backup_name}_$DATE.sql.gz"

	CURRENT_TEMP_FILE=$(mktemp "$backup_file.tmp.XXXXXX") || {
		echo "Failed to create temporary file for $backup_name." >&2
		return 1
	}

	if ! "$@" | gzip -c > "$CURRENT_TEMP_FILE"; then
		echo "Backup failed for $backup_name; skipping it." >&2
		rm -f "$CURRENT_TEMP_FILE"
		CURRENT_TEMP_FILE=""
		return 1
	fi

	if ! mv -f "$CURRENT_TEMP_FILE" "$backup_file"; then
		echo "Failed to finalize backup for $backup_name; skipping it." >&2
		rm -f "$CURRENT_TEMP_FILE"
		CURRENT_TEMP_FILE=""
		return 1
	fi

	CURRENT_TEMP_FILE=""
	echo "Backup completed for $backup_name."
}

# Create backup directory if it doesn't exist
if ! mkdir -p "$BACKUP_DIR"; then
	echo "Failed to create backup directory: $BACKUP_DIR" >&2
	exit 1
fi

echo "Starting database backup for $DATE..."
case "$BACKUP_MODE" in
	all)
		if ! backup_dump "all_databases" mysqldump --no-tablespaces -u"$ALL_DB_USER" -p"$ALL_DB_PASSWORD" --all-databases; then
			BACKUP_FAILED=1
		fi
		;;
	list)
		if [ "${#DB_USERS[@]}" -ne "${#DB_PASSWORDS[@]}" ] || [ "${#DB_USERS[@]}" -ne "${#DB_NAMES[@]}" ]; then
			echo "DB_USERS, DB_PASSWORDS, and DB_NAMES must have the same number of entries." >&2
			exit 1
		fi

		for ((index = 0; index < ${#DB_NAMES[@]}; index++)); do
			if ! backup_dump "${DB_NAMES[$index]}" mysqldump --no-tablespaces -u"${DB_USERS[$index]}" -p"${DB_PASSWORDS[$index]}" "${DB_NAMES[$index]}"; then
				BACKUP_FAILED=1
			fi
		done
		;;
	*)
		echo "Invalid BACKUP_MODE '$BACKUP_MODE'; use 'all' or 'list'." >&2
		exit 1
		;;
esac

# Delete backups older than 7 days
echo "Deleting backups older than 7 days..."
find "$BACKUP_DIR" -type f -mtime +7 -delete
echo "Old backups deleted."

if [ "$BACKUP_FAILED" -ne 0 ]; then
	echo "Backup run completed with errors." >&2
	exit 1
fi

echo "Database backup for $DATE completed."