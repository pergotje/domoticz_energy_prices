# domoticz_energy_prices v0.3b
## _Jeroen Gouma_

Domoticz_Energy_Prices (aka DEP) is a small set of scripts to perform a hourly update of the electricity prices used for costcalculation in Domoticz. 

Scripts are intended for and tested on a Raspberry Pi or other linux environment.

Sometimes one has to reconsider the plans and go back to the drawingboard. 
After the previous version I found out it was released a bit to early. 
I did not take into account the fact that on end of day some counters where reset to 0. 
Thanks to other scripts I could make a better solution (I think).

In the new setup the collection of prices is unchanged, but calculation of the costs is moved inside Domoticz in a dzvents script. 
The script now also takes into account the other costs you have to incorporate (netbeheer, teruggave energiebelasting en leveringskosten)

Improvements can (and will) be made. Suggestions are welcome!


## To Do: 
- Finetuning and cleanup
- Implement error handling on price collecting

## Scripts
- collect_prices.sh
Collects the prices for tomorrow and saves them for future use by the other scripts
- show_prices.sh
Script to check what the actual prices are that would be send to Domoticz
- update_domoticz_prices.sh
Performs the actual update of the dummy-device in Domoticz every hour with the actual price.
- electricity_costs.dzvents
Calculates the electricity costs per hour based on variable pricing

## Installation part 1 (price gathering)
# Domoticz
- Create a dummy sensor in Domoticz of type "Custom Sensor" and take a note of the index number. Give it a proper name indicating it's holding the LAST HOUR price of electricity.
- Create a dummy sensor in Domoticz of type "Custom Sensor" and take a note of the index number. Give it a proper name indicating it's holding the CURRENT price of electricity.
# script
- Go to https://enever.nl and create a token (it's free).
- Edit the script ```collect_prices.sh``` and add your token on line 3.

- Create a folder on your domoticz environment and put all files in there. 
 I use ```/home/pi/domoticz/scripts/energy_prices/ ```
- Make the scripts executable (```chmod 755 *.sh```)
- Execute the command below in the same folder to collect today's pricing (replace the XXXXXX string with your token):
    ``` wget -O $(date +'%Y%m%d').json https://enever.nl/api/stroomprijs_vandaag.php?token=XXXXXXXXX```
- Execute the show_prices script to validate the output:
``` ./show_prices.sh ```



- If all looks fine open the script update_domoticz_costs.sh and make the following modifcations:
```
- on line 15:	change the URL to your own Domoticz IP
- on line 16:	Enter the Domoticz IDX of your p1 meter
# If Ypu want to use Telegram for updates, Enter your:
- on line 16:	Bot Api (Botfather)
- on line 16:	Chat ID
# See line 149/151 for the Domoticz counters
# See line 158/164 for Telegram messages
- Save the file and close it.

open the script enever.conf and make the following modifcations:
- on line 15-28: remove the # in front of the line which mentions our energy provider
: change the idx number of the used energy provider to the idx of the sensor created in Domoticz
```
- Save the file and close it.

- The moment of truth: Run the update_domoticz_costs.sh script and check the results:
``` ./update_domotiz_costs.sh ```
- If the feedback contains ``` "status": "OK" ``` everything works as designed.
- At line 26 you can change the debug to   MyDebug="Y"     if you need to debug.



## Automation
Of course nobody want to run these scripts manually, that's why we have crontab at our disposal. Add the following lines to the crontab the user running domoticz (and change the path to your environment):
```
   # Collect variable electricity prices for tomorrow
      30    19    *    *    *     /home/pi/domoticz/scripts/energy_prices/collect_prices.sh >/dev/null 2>&1
   # Update variable electricity prices in Domoticz
       0     *     *    *     *   /home/pi/domoticz/scripts/energy_prices/update_domoticz_costs.sh  >/dev/null 2>&1
```
The update script is scheduled on minut 0 of every hour to ensure the dashboard always shows the actual price.

## Installation part 2 (Cost calculation)

- Create a dummy sensor in Domoticz of type "Custom Sensor" and take a note of the index number. Give it a proper name indicating it's holding the costs of electricity. You can create multiple for multiple providers if required.
- Create 3 user variables in Domoticz:
    - fixed daily delivery costs incl BTW (DailyFixedFee)
    - fixed daily "netbeheer" costs incl BTW (DailyFixedCosts)
    - fixed daily "vermindering energiebelasting" incl BTW (negative value as it is a return) (EnergyTaxReturn)

- In Domoticz, create a new dzvents script. Paste the content of the file ```electricity_costs.dzvents``` and make the following modifcations:
```
- on line 2: change the idx number you use in Domoticz to read data from your meter (aka "Power")
- on line 3: change the idx number you use in Domoticz which holds the dynamic electricity price (created in part 1)
- on line 3: change the idx number you use in Domoticz which holds the cumulative electricity cost (created step 1 of this part)
- on line 7: change the idx number of the user variable you created for DailyFixedFee
- on line 8: change the idx number of the user variable you created for DailyFixedCosts
- on line 9: change the idx number of the user variable you created for EnergyTaxReturn
```

Save the file and be patient. The script is scheduled on minute 59 of every (clock)hour because it needs to total usage of the past hour to enable proper calculation. The first (partial) day will have incorrect values, but starting of the next day is should be correct.

The second Domoticz dummy with Current price can be used as a trigger to start or stop scripts in Domoticz.
(If price is above, turn off)

Every hour you will also find the relevant data in the Domoticz logfile.
