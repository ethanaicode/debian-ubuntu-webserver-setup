# HOW TO

```bash
# Create backup directory
sudo mkdir -p /backup/mysql

# Create backup script
sudo vim /usr/local/bin/db_backup.sh
# Refer to the content of the script provided in db_backup.sh

# Make the script executable
sudo chmod +x /usr/local/bin/db_backup.sh

# Create systemd service file
sudo vim /etc/systemd/system/dbbackup.service
# Refer to the content of the service file provided in dbbackup.service

# Create systemd timer file
sudo vim /etc/systemd/system/dbbackup.timer
# Refer to the content of the timer file provided in dbbackup.timer

# Reload systemd, enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable --now dbbackup.timer
systemctl list-timers

# Run the service manually to test
sudo systemctl start dbbackup.service
# Check the logs to verify the backup process
journalctl -u dbbackup.service
```