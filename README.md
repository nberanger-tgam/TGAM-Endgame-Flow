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
- The Endgame agent is installed via the policy ***Endgame 1 - Install Endgame (Triggered)***. This policy is either run manually, or triggered via the recurring policy ***Endgame 2 - Check for Endgame Install (Daily Recurring Check-in)***, using the command:<br/><br/>
  `jamf policy -event install-endgame`
  - Once the Endgame installer pkg is deployed, the script ***jamfEndgameInstall.sh*** is run. This will install the Endgame agent, and then use the Endgame API to confirm that the computer has registered with the Endgame console.
  - If the computer is found in the Endgame console, it is then added to the Jamf static group ***Endgame is Installed***.
  - If the computer is not found in the Endgame console, the script will use the Jamf API to see if the computer is in the static group ***Endgame Install Failed**
  - If it is not found in that group, then it will be added, which will also cause it to be added to the smart group ***Endgame Install Missing***
  - If it is found in that group, the script will then check to see if it is in the ***Endgame Install Failed 2nd Time***
  - If it is not found in that group, then it will be added to the 2nd group, which will also cause it to be added to the smart group ***Endgame Install Missing***
  - If it is found in the 2nd group, then it will be added to the ***Endgame Install Failed 3 times*** static group, which will also cause it to be added to the smart group ***Endgame Install Failed at Least 3 Times***

- The policy ***Endgame 2 - Check for Endgame Install (Daily Recurring Check-in)*** is run on a daily recurrance, scoped to the ***Endgame is Installed*** static group.
  - This policy runs the script ***jamfEndgameInstalCheck.sh*** which works similar to the above, checking to make sure that the Endgame agent is installed, and that the computer is registered with the Endgame console. The computer will be assigned to one of the three static groups based on the results. 

- If a computer is added to the ***Endgame Install Failed**, or ***Endgame Install Failed 2nd Time***, it will also be added to the ***Endgame Install Missing*** smart group.
  - The policy ***Endgame 3 - Uninstall Endgame (Ongoing Recurring Check-in)*** is set to run ongoing during check-in, and is scoped to the ***Endgame Install Missing*** smart group.
  - The script ***jamfEndgameUninstall.sh*** will remove the agent from the computer, and also make sure that the computer is not listed in the ***Endgame is Installed*** static group.
  -  The policy will then run the command *jamf policy -event upload-jamf-logs*, which will trigger the policy ***Endgame 4 - Upload Jamf Logs (Triggered)***


    
    
    
    
   - Endgame install works/check for Endgame is successful - Endgame is Installed (ID 396) - remove computer from ALL of the
     install failed groups - daily policy to check if Endgame is still installed

   - 1st failed group - Endgame Install Failed (ID 397) - gets added to smart group Endgame Install Missing (ID 398) - runs
     uninstall - tries to install again

   - 2nd install failed group - Endgame Install Failed 2nd Time (ID 399) - gets added to smart group Endgame Install Missing
     (ID 398) - runs uninstall - tries to install again

   - 3rd install failed group - Endgame Install Failed 3 Times (ID 400) - gets added to smart group Endgame Install Failed at
     Least 3 Times (ID 401) - sends notification - runs uninstall - continues to try and install

