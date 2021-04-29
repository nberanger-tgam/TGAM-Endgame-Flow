#!/bin/sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# Copyright (c) 2020 Jamf.  All rights reserved.
#
#       Redistribution and use in source and binary forms, with or without
#       modification, are permitted provided that the following conditions are met:
#               * Redistributions of source code must retain the above copyright
#                 notice, this list of conditions and the following disclaimer.
#               * Redistributions in binary form must reproduce the above copyright
#                 notice, this list of conditions and the following disclaimer in the
#                 documentation and/or other materials provided with the distribution.
#               * Neither the name of the Jamf nor the names of its contributors may be
#                 used to endorse or promote products derived from this software without
#                 specific prior written permission.
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# This script was designed to be used in a Self Service policy to allow the facilitation
# or log collection by the end-user and upload the logs to the device record in Jamf Pro
# as an attachment.
#
# REQUIREMENTS:
#           - Jamf Pro
#           - macOS Clients running version 10.13 or later
#
#
# For more information, visit https://github.com/kc9wwh/logCollection
#
# Written by: Joshua Roskos | Jamf
#
#
# Revision History
# 2020-12-01: Added support for macOS Big Sur
# 2021-04-16: Nathan Beranger - Modified original script for TGAM environment, added logging
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

## Echo all commands and results as they run
set -x

## Assign today's date and time, and name of script for logging purposes
DATE=$(date '+%Y-%m-%d %H:%M')
SCRIPTNAME="Uploading Jamf Logs"

#####
# Send all output to /private/var/tmp/TGAM-Jamf.log. Using >> instead of > will
# append output to file instead of overwritting existing file.
#####
# Saves file descriptors 1 (stdout) to 3, and 2 (stderr) to 4,
# so they can be restored to whatever they were before
exec 3>&1 4>&2
# Restore file descriptors for particular signals
trap 'exec 2>&4 1>&3' 0 1 2 3
# Redirect 1 (stdout) to 'TGAM-Jamf.log' then redirect 2 (stderr) to 1 (stdout)
exec 1>>/private/var/tmp/TGAM-Jamf.log 2>&1

echo "---------------------------------------------------"
echo "$DATE"" | ""$SCRIPTNAME"
echo "---------------------------------------------------"

#####

## User Variables
jamfProURL="$4"
jamfProUser="$5"
jamfProPass="$6"
jamfLog="/private/var/log/jamf.log"
tgamJamfLog="/private/var/tmp/TGAM-Jamf.log"

## System Variables
serialNumber=$( system_profiler SPHardwareDataType | grep Serial |  awk '{print $NF}' )
# currentUser=$( stat -f%Su /dev/console )
compHostName=$( scutil --get LocalHostName )
timeStamp=$( date '+%Y-%m-%d' )
osMajor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $1}')
osMinor=$(/usr/bin/sw_vers -productVersion | awk -F . '{print $2}')

## Log Collection
fileName=$compHostName-$timeStamp-logs.zip
zip -j /private/tmp/"$fileName" "$jamfLog" "$tgamJamfLog"

## Upload Log File
if [[ "$osMajor" -eq 11 ]]; then
	jamfProID=$( curl -ku "$jamfProUser":"$jamfProPass" \
    "$jamfProURL"/JSSResource/computers/serialnumber/"$serialNumber"/subset/general \
    | xpath -e "//computer/general/id/text()" )
elif [[ "$osMajor" -eq 10 && "$osMinor" -gt 12 ]]; then
    jamfProID=$( curl -ku "$jamfProUser":"$jamfProPass" \
    "$jamfProURL"/JSSResource/computers/serialnumber/"$serialNumber"/subset/general \
    | xpath "//computer/general/id/text()" )
fi

curl -ku "$jamfProUser":"$jamfProPass" \
"$jamfProURL"/JSSResource/fileuploads/computers/id/"$jamfProID" \
-F name=@/private/tmp/"$fileName" \
-X POST

## Cleanup
rm /private/tmp/"$fileName"
exit 0



