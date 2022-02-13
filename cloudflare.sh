#!/bin/bash
# Author : Hilmi Abdul Azis Firmansyah
# Copyright (c) devisty.net
# Script follows here:
## change to "bin/sh" when necessary

red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
white=$'\e[0m'

echo "Input Email Cloudflare"
read EMAIL

# if ["${EMAIL}" == '']; then
# echo "$red Email Tidak Boleh Kosong"
# echo "Input Ulang Email Anda :"
# read EMAIL
# echo "$white"
# exit 1
# fi

echo "$blu Email anda adalah : $EMAIL"
echo "$white"

echo "input Token Auth Anda"
echo "lihat di sebelah kanan bawah pada halaman overview"
echo "cari '$blu Get your API token'"
echo "$white"
echo "Kemudian Klik View pada '$blu Global API Key'"
read AUTH
echo "Input $blu Zone ID $white Anda"
read ZONE
echo "Buat $blu A RECORD $white dengan nama ddns dengan content $blu 8.8.8.8 $white"
echo "Masukkan $blu Record Name $white yang sudah anda daftarkan disini"
read RECORD

echo "Membuat Cron"
echo "1 >> crontab"
echo "*/1 * * * * /bin/bash /root/cloudflare-ddns-updater/cloudflare.sh >> crontab"

auth_email="$EMAIL"                                # The email used to login 'https://dash.cloudflare.com'
auth_method="global"                               # Set to "global" for Global API Key or "token" for Scoped API Token 
auth_key="$AUTH"                                   # Your API Token or Global API Key
zone_identifier="$ZONE"                            # Can be found in the "Overview" tab of your domain
record_name="$RECORD"                              # Which record you want to be synced
ttl="3600"                                         # Set the DNS TTL (seconds)
proxy=false                                        # Set the proxy to true or false
slacksitename=""                                   # Title of site "Example Site"
slackchannel=""                                    # Slack Channel #example
slackuri=""                                        # URI for Slack WebHook "https://hooks.slack.com/services/xxxxx"


###########################################
## Check if we have a public IP
###########################################
ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/)

if [ "${ip}" == "" ]; then 
  logger -s "DDNS Updater: No public IP found"
  exit 1
fi

###########################################
## Check and set the proper auth header
###########################################
if [ "${auth_method}" == "global" ]; then
  auth_header="X-Auth-Key:"
else
  auth_header="Authorization: Bearer"
fi

###########################################
## Seek for the A record
###########################################

logger "DDNS Updater: Check Initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
                      -H "X-Auth-Email: $auth_email" \
                      -H "$auth_header $auth_key" \
                      -H "Content-Type: application/json")

###########################################
## Check if the domain has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  logger -s "DDNS Updater: Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  exit 1
fi

###########################################
## Get existing IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  logger "DDNS Updater: IP ($ip) for ${record_name} has not changed."
  exit 0
fi

###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"(\w+)".*/\1/')

###########################################
## Change the IP@Cloudflare using the API
###########################################
update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                     -H "X-Auth-Email: $auth_email" \
                     -H "$auth_header $auth_key" \
                     -H "Content-Type: application/json" \
              --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":\"$ttl\",\"proxied\":${proxy}}")

###########################################
## Report the status
###########################################
case "$update" in
*"\"success\":false"*)
  logger -s "DDNS Updater: $ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
  if [[ $slackuri != "" ]]; then
    curl -L -X POST $slackuri \
    --data-raw '{
      "channel": "'$slackchannel'",
      "text" : "'"$slacksitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
    }'
  fi
  exit 1;;
*)
  logger "DDNS Updater: $ip $record_name DDNS updated."
  if [[ $slackuri != "" ]]; then
    curl -L -X POST $slackuri \
    --data-raw '{
      "channel": "'$slackchannel'",
      "text" : "'"$slacksitename"' Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
    }'
  fi
  exit 0;;
esac
