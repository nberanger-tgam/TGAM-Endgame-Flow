#!/bin/sh

# jamfEndgameInstallCheck.sh

#####
#                   THIS SCRIPT IS DESIGNED TO RUN WITHIN JAMF
#
# This script uses the Endgame and Jamf APIs. It checks to see if a computer is in the Endgame console. It will then
# assign the computer to a static group in Jamf depending on if the device was found inthe Endgame console or not.
# The results will also be output to /private/var/tmp/TGAM-Jamf.log
#
# JQ is used to parse the JSON data.
# If JQ is not already installed, a Jamf policy will be called to download and run the installer.
#
# Steps:
# ------
# - Endgame install works/check for Endgame is successful - Endgame is Installed (ID 396) - remove computer from ALL
#   of the install failed groups - daily policy to check if Endgame is still installed
#
# - 1st failed group - Endgame Install Failed (ID 397) - gets added to smart group Endgame Install Missing (ID 398) -
#   runs uninstall - tries to install again
#
# - 2nd install failed group - Endgame Install Failed 2nd Time (ID 399) - gets added to smart group Endgame Install
#   Missing (ID 398) - runs uninstall - tries to install again
#
# - 3rd install failed group - Endgame Install Failed 3 Times (ID 400) - gets added to smart group Endgame Install
#   Failed at Least 3 Times (ID 401) - sends notification - runs uninstall - continues to try and install
#
#####
# version 2.0
# Created by Nathan Beranger, April 21, 2021
#####
# Revision notes:
#
# April 26, 2021  - Added logic to check if computer was already in a failed group, and assign to the next failed
#                   group if it was found
#                 - created functions to make script easier to read
####

# echo all output
# set -x

## Assign today's date and time, and name of script for logging purposes
DATE=$(date '+%Y-%m-%d %H:%M')
SCRIPTNAME="Check for Endgame Installation"

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

## Variables
compHostName=$(hostname)
serialNumber="$(ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}')"
jamfJSONheader="accept: application/json"
jamfxmlHeader="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>"
endgameAPIuser="$4"
endgameAPIpass="$5"
jamfProURL="$6"
jamfAPIuser="$7"
jamfAPIpass="$8"


#####

## Dependencies:

## Check if JQ is installed, and install it if it is not (this is used to parse the JSON data)
JQ="/usr/local/bin/jq"

if [ -f "$JQ" ];
  then
    echo "Check for JQ: JQ is installed."
  else
    echo "Check for JQ: JQ is not installed. Installing it now..."
    jamf policy -event install-jq
    jqVersion=$(jq --version)
    if [ "$jqVersion" = "jq-1.6" ]
      then
        echo "$jqVersion is now installed and can be found at $JQ"
      else
        echo "Something went wrong and JQ did not install. Trying once more..."
        jamf policy -event install-jq
        jqVersion=$(jq --version)
        if [ "$jqVersion" = "jq-1.6" ]
          then
            echo "$jqVersion is now installed and can be found at $JQ"
          else
            echo "Something went wrong again and JQ still did not install correctly. Exiting now." && exit
        fi
    fi
fi

#####

## Functions

# Add computer to a Jamf static group
jamfAddToGroup()
{
  jamfAPIurl="JSSResource/computergroups/id/${jamfGroupID}"
  jamfGroupAPIdata="<computer_group><id>${jamfGroupID}</id><name>${jamfGroupName}</name><computer_additions><computer><name>$compHostName</name></computer></computer_additions></computer_group>"
  curl -sSkiu "${jamfAPIuser}":"${jamfAPIpass}" \
  "${jamfProURL}/${jamfAPIurl}" \
  -H "Content-Type: text/xml" \
  -d "${jamfxmlHeader}${jamfGroupAPIdata}" \
  -X PUT  > /dev/null
}

# Remove computer from a Jamf static group
jamfRemoveFromGroup()
{
  jamfSerialAPIdata="<computer_group><computer_deletions><computer><serial_number>${serialNumber}</serial_number></computer></computer_deletions></computer_group>"
  curl -sfu "${jamfAPIuser}":"${jamfAPIpass}" \
  "${jamfProURL}/JSSResource/computergroups/id/${jamfGroupID}" \
  -H "Content-Type: text/xml" \
  -d "${jamfxmlHeader}${jamfSerialAPIdata}" \
  -X PUT
}
# Gather list of serial numbers from computers in a Jamf static group
findGroupSerialNumbers()
{
  computers=$(curl -sfu "${jamfAPIuser}":"${jamfAPIpass}" \
  -X GET -H "${jamfJSONheader}" \
  "${jamfProURL}/JSSResource/computergroups/id/${jamfGroupID}" \
  | jq -r '.computer_group' | jq -r '.computers' | jq -r '.[].serial_number' )
}

# Check to see if computer serial number is in list of serial numbers from a group in Jamf
serialCheck()
{
  jamfGroupSerialNumbers=$( [[ $computers =~ (^|[[:space:]])$serialNumber($|[[:space:]]) ]] && echo 'True' || echo 'False' )
}

#####

## Check to see if computer has registered with Endgame server

# Log in to Endgame API and capture authentication token
authKey=$( curl -X POST \
--header 'Content-Type: application/json' \
--header 'Accept: application/json' \
-d "{
\"username\": \"${endgameAPIuser}\",\"password\": \"${endgameAPIpass}\"}" \
'https://bahglo.endgameone.com/api/v1/auth/login/' \
| jq -r '.metadata' | jq -r '.token' )

# Check to see if computer has registered with Endgame console
endpointResults=$( curl -X GET \
--header 'Accept: application/json' \
"https://bahglo.endgameone.com/api/v1/endpoints/?name=${compHostName}" -H \
"Authorization: JWT ${authKey}" | jq -r '.data' | jq -r '.[].status')

#####

# Output results and assign/remove computer from Jamf static groups based on results
if [ "$endpointResults" = "monitored" ]
  then
    jamfGroupID="396"
    jamfGroupName="Endgame is Installed"
    jamfAPIurl="JSSResource/computergroups/id/${jamfGroupID}"
    jamfGroupAPIdata="<computer_group><id>${jamfGroupID}</id><name>${jamfGroupName}</name><computer_additions><computer><name>$compHostName</name></computer></computer_additions></computer_group>"
    # Call function to assign computer to Endgame is Installed static group (ID 396)
    jamfAddToGroup
    # Call function to remove computer from Endgame Install Failed static group (ID 397)
    jamfGroupID="397"
    jamfGroupName="Endgame Install Failed"
    jamfRemoveFromGroup
    # Call function to remove computer from Endgame Install Failed 2nd Time static group (ID 399)
    jamfGroupID="399"
    jamfGroupName="Endgame Install Failed 2nd Time"
    jamfRemoveFromGroup
    # Call function to remove the computer from Endgame Install Failed 3 Times static group (ID 400)
    jamfGroupID="400"
    jamfGroupName="Endgame Install Failed 3 Times"
    jamfRemoveFromGroup
    # Set group name back to Endgame is Installed (ID 396) for commenting purposes
    jamfGroupID="396"
    jamfGroupName="Endgame is Installed"
    endgameInstallStatus="$compHostName is now being $endpointResults by Endgame and has been added to the $jamfGroupName group in Jamf." && echo "$endgameInstallStatus"
    echo ""
    echo "If $compHostName was in any of the Endgame Install Failed groups, it has now been removed."
  else
    jamfGroupID="396"
    jamfGroupName="Endgame is Installed"
    # Call function to remove computer from Endgame is Installed group (ID 396)
    jamfRemoveFromGroup
    # Check if computer is already assigned to any Endgame Install Failed static groups
    jamfGroupID="397"
    jamfGroupName="Endgame Install Failed"
    # Get list of serial numbers of computers, and check to see if computer is already in Endgame Install Failed group (ID 397)
    findGroupSerialNumbers
    # Check if computer serial number is already in list of serial numbers from static group Endgame Install Failed group (ID 397)
    serialCheck
    if  [ "$jamfGroupSerialNumbers" = "True" ]
      then
      echo "Looks like the Endgame install has failed once before..."
      # Check if computer serial number is already in  list of serial numbers from static group Endgame Install Failed 2nd Time (ID 399)
      jamfGroupID="399"
      jamfGroupName="Endgame Install Failed 2nd Time"
      # Get list of serial numbers of computers in group
      findGroupSerialNumbers
      # Check to see if the serial number of the computer is already in the list of serial numbers from the group in Jamf
      serialCheck
      if  [ "$jamfGroupSerialNumbers" = "True" ]
        then
        echo "It looks like the Endgame install has failed twice..."
        # Call function to assign computer to Jamf static group Endgame Install Failed 3 Times (ID 400)
        jamfGroupID="400"
        jamfGroupName="Endgame Install Failed 3 Times"
        jamfAddToGroup
        endgameInstallStatus="It appears Endgame will not install. After multiple attemps, there is still no record of $compHostName in the Endgame console. It has now been added to the $jamfGroupName group in Jamf."
        else
        # Since computer was not already in Endgame Install Failed 2nd Time (ID 399), call function to assign it now
        jamfAddToGroup
        endgameInstallStatus="It appears Endgame is not installed. This is the second attempt, but there is still no record of $compHostName in the Endgame console. It has now been added to the $jamfGroupName group in Jamf."
      fi
      else
      # Since computer was not already in Endgame Install Failed group (ID 397), call function to assign it now
      jamfAddToGroup
      endgameInstallStatus="It appears Endgame is not installed. There is no record of $compHostName in the Endgame console. It has now been added to the $jamfGroupName group in Jamf."
    fi
  # Echo results
  echo "$endgameInstallStatus"
fi

exit 0