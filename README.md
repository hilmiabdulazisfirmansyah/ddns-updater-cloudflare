# DDNS UPDATER CLOUDFLARE
DDNS Updater Cloudflare

# Setup DDNS Cloudflare
- sudo su
 - git clone https://github.com/hilmiabdulazisfirmansyah/ddns-updater-cloudflare.git
 - cd ddns-updater-cloudflare
 - chmod +x ./cloudflare.sh

# Setting Cron for DDNS
 - crontab -e
 - 1
 - */1 * * * * /bin/bash /root/cloudflare-ddns-updater/cloudflare.sh

# Restart cron
  - systemctl restart cron

# Check Cron
- ps aux | grep crond
