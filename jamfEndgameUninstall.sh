#!/bin/sh

# jamfEndgameUninstall.sh

#####
# This script is meant to be run from Jamf, AFTER the Endgame installer pkg is on the computer.
# If the files are found then it will uninstall the Endgame agent, and all related files.
#####
# version 2.0
#####
# Revision notes:
# 1.0	
#	April 2021  - updated to use Jamf API to assign/remove computer from static groups
#
# 2.0
#   April 2021  - changed logic in Jamf, no longer need to assign/rempove computer from static groups
#
#####

# echo all output
# set -x

## Assign today's date and time, and name of script for logging purposes
DATE=$(date '+%Y-%m-%d %H:%M')
SCRIPTNAME="Uninstall Endgame Sensor"

## Send all output to /private/var/tmp/TGAM-Jamf.log
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>> /private/var/tmp/TGAM-Jamf.log

echo "---------------------------------------------------"
echo "$DATE"" | ""$SCRIPTNAME"
echo "---------------------------------------------------"

#####

## Variables
compHostName=$(hostname)
endgameVersion=$(find /private/var/tmp/Endgame/macos/ -name "*.cfg" | sed 's/[^0-9]*//g')
pathToAgent="/private/var/tmp/Endgame/macos"
endgameAgent="SensorMacOSInstaller-bahglo-detect-v$endgameVersion"
endgameConfig="SensorMacOSInstaller-bahglo-detect-v$endgameVersion.cfg"


#####

## Display currently installed version of Endgame
echo "Endgame Version $endgameVersion is currently installed. It will now be removed."

#####

## Dependencies

## Check if Endgame installer exists in correct location
echo "Checking for Endgame installation agent..."
if [ -f "$pathToAgent/$endgameAgent" ]
then
	echo "Endgame version $endgameVersion agent files found. Preparing uninstaller..."
	echo "Converting $endgameAgent to an executable..."
	Chmod +x "$pathToAgent/$endgameAgent"
else
	echo "$pathToAgent/$endgameAgent not found. Halting operation."
  	UninstallStatus="1"
fi

#####

## Uninstall Endgame agent, create uninstall log, make sure any remaining Endgame files are removed
echo "Executing uninstallation of Endgame..."
sudo "$pathToAgent/$endgameAgent" -c "$pathToAgent/$endgameConfig" -u force -d false -l /private/var/tmp/Endgame_uninstall.log

## Check to make sure the Endgame SEXT has been uninstalled
# as of right now, SIP has to be disabled before you can run systemextensionsctl uninstall.
# Apple is supposed to be removing this restriction at some point in the future
if [ -d "/Applications/Endgame" ]
then
    echo "Endgame system extension found, removing it now."
    # systemextensionsctl uninstall 4FVLCA237T com.endgame.alert
    rm -rf /Applications/Endgame
else
    echo "The Endgame system extension either did not exist, or it was succesfully removed."
fi

UninstallStatus="0"

#####

## Check if uninstallation completed succesfully
echo "Checking for Endgame_uninstall.log..."
if [ -f "/private/var/tmp/Endgame_uninstall.log" ] && [ ! -d "/Library/Endgame" ]
then
	echo "The uninstall log was found at /private/var/tmp/Endgame_uninstall.log, and a copy has also been uploaded to the Jamf Pro server."
    ## Remove Endgame uninstall files
	echo "Cleaning up uninstall files..."
	rm -rf /private/var/tmp/Endgame
    echo "Endgame has successfully been uninstalled from $compHostName."
else
	if [ -f "/private/var/tmp/Endgame_uninstall.log" ] 
	then
		echo "Something went wrong. The uninstall log exists, but so does /Library/Endgame/. The uninstall may not have completed succesfully."
		UninstallStatus="1"
	fi		
	echo "Something went wrong. The uninstall log was not found. The uninstall may not have completed succesfully."
	UninstallStatus="1"
fi

########################

exit "$UninstallStatus"