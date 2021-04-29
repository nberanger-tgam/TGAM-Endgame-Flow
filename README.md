# TGAM workflow for Elastic Endgame agent install with Jamf

There following are set up in Jamf for this workflow:

### **Policies:**
  1. Endgame 1 - Install Endgame (Triggered)
  2. Endgame 2 - Check for Endgame Install (Daily Recurring Check-in)
  3. Endgame 3 - Uninstall Endgame (Ongoing Recurring Check-in)
  4. Endgame 4 - Upload Jamf Logs (Triggered)

### **Static Groups:**
  1. Endgame Install Failed
  2. Endgame Install Failed 2nd Time
  3. Endgame Install Failed 3 times
  4. Endgame is Installed

### **Smart Groups:**
  1. Endgame Install Failed at Least 3 Times
  2. Endgame Install Missing

### **Scripts:**
  1. jamfEndgameInstall.sh
  2. jamfEndgameInstalCheck.sh
  3. jamfEndgameUninstall.sh
  4. jamfLogUpload.sh

### **Packages:**
  1. Endgame installer pkg

## **The Workflow is as follows:**
- The Endgame agent is installed via the policy ***Endgame 1 - Install Endgame (Triggered)***. This policy is either run manually, or triggered via the recurring policy ***Endgame 2 - Check for Endgame Install (Daily Recurring Check-in)***, using the command `jamf policy -event install-endgame`
  - Once the Endgame installer pkg is deployed, the script ***jamfEndgameInstall.sh*** is run. This will install the Endgame agent, and then use the Endgame API to confirm that the computer has registered with the Endgame console.
  - If the computer is found in the Endgame console, it is then added to the Jamf static group ***Endgame is Installed***.
  - If the computer is not found in the Endgame console, the script will use the Jamf API to see if the computer is in the static group ***Endgame Install Failed***
  - If it is not found in that group, then it will be added, which will also cause it to be added to the smart group ***Endgame Install Missing***
  - If it is found in that group, the script will then check to see if it is in the ***Endgame Install Failed 2nd Time***
  - If it is not found in that group, then it will be added to the 2nd group, which will also cause it to be added to the smart group ***Endgame Install Missing***
  - If it is found in the 2nd group, then it will be added to the ***Endgame Install Failed 3 times*** static group, which will also cause it to be added to the smart group ***Endgame Install Failed at Least 3 Times***

- The policy ***Endgame 2 - Check for Endgame Install (Daily Recurring Check-in)*** is run on a daily recurrance, scoped to the ***Endgame is Installed*** static group.
  - This policy is scoped to all users, with the exclusion of the following computers and groups:
    - Endgame Testers (wider scope)
  - This policy runs the script ***jamfEndgameInstalCheck.sh*** which works similar to the above, checking to make sure that the Endgame agent is installed, and that the computer is registered with the Endgame console. The computer will be assigned to one of the three static groups based on the results. 

- If a computer is added to the ***Endgame Install Failed**, or ***Endgame Install Failed 2nd Time*** static groups, it will also be added to the ***Endgame Install Missing*** smart group.
  - The policy ***Endgame 3 - Uninstall Endgame (Ongoing Recurring Check-in)*** is set to run ongoing during check-in, and is scoped to the ***Endgame Install Missing*** smart group.
  - The script ***jamfEndgameUninstall.sh*** will remove the agent from the computer, and also make sure that the computer is not listed in the ***Endgame is Installed*** static group.
  -  The policy will then run the command `jamf policy -event upload-jamf-logs`, which will trigger the policy ***Endgame 4 - Upload Jamf Logs (Triggered)***

- The policy ***Endgame 4 - Upload Jamf Logs (Triggered)*** will zip both the *jamf.log* and *TGAM-Jamf.log* files into the file `$compHostName-$timeStamp-logs.zip` and upload this to the computer's attachment payload in Jamf.
  - The policy then runs the command `jamf policy -event install-endgame` which triggers the policy ***Endgame 1 - Install Endgame (Triggered)***, and starts the process above over again.

- If a computer is added the ***Endgame Install Failed 3 times*** static group, it is then also added to the ***Endgame Install Failed at Least 3 Times*** smart group.
  - An email notification will be sent out whenever a computer is added to, or removed from, this group.
  - After the notification is sent out, the workflow follows the same path as if the machine had been added to the ***Endgame Install Missing*** smart group.

Here is a flow chart which outlines the workflow described above:
[TGAM Jamf Endgame Workflow Flowchart](https://github.com/nberanger-tgam/TGAM-Endgame-Flow/blob/main/Jamf%20-%20Endgame%20Flowchart.png)

