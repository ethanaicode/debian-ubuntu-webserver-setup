#!/bin/bash

# MySQL backup script
# Recommended to place this script for /usr/local/bin/db_backup.sh

DATE=$(date +%Y%m%d_%H%M%S)

mysqldump -uroot -p'YourPassword' database_name | gzip > /backup/mysql/database_name_$DATE.sql.gz

# If you want to backup specific databases, you can specify them like this:
# mysqldump -uroot -p'YourPassword' --databases database1 database2 | gzip > /backup/mysql/specific_databases_$DATE.sql.gz
#     Or you can duplicate the command for each database you want to backup :)

# If you want to backup all databases, use the following command instead:
# mysqldump -uroot -p'YourPassword' --all-databases | gzip > /backup/mysql/all_databases_$DATE.sql.gz

# Delete backups older than 7 days
find /backup/mysql -type f -mtime +7 -delete