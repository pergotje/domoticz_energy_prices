#!/bin/bash
##########################################
#
# Script to collect the electricity usage of the previous hour
# and multiply this with the electricity tarif for that hour.
#
# Result is written to Domoticz
#
#########################################


# Modify variables below to your situation
#####################################
SetUp () {
  MyDomoticzURL="http://192.168.2.###:8080"
  MyDomoticzPowerIdx=##
  MyTelegramAPI="########:##############"
  MyTelegramChatID="-###########"
}


# Process parameters
#####################################
CheckParameters () {
  MyDebug="Y"
}


# Set enviroment
#####################################
setEnvironment () {
  Mydir=`dirname $0`
  MyTempFile=$Mydir/usage.json
}


# Debug info
#####################################
Echo () {
 if [[ "$MyDebug" == "Y" ]]; then
    echo $1 $2 $3 $4 $5
 fi
}


# Processing starts here
#####################################

CheckParameters $@
SetUp
setEnvironment

MyLastHourStart=$(date -d "now - 60 minutes"  +'%Y-%m-%d %H:00')
MyTSStart=$(date -d "$MyLastHourStart")
MyLastHourEnd=$(date -d "now"  +'%Y-%m-%d %H:00')
MyDate=$Mydir/$(date +'%Y%m%d')
MyLastHour=$(date -d"- 60 minutes" +'%H')
MyCurrentHour=$(date -d"- 0 minutes" +'%H')


Echo "-----"
Echo "Update prices"
Echo "-----"


# Extract last hour price from today's pricelist in <date>.json
MyPrices=$(cat $MyDate.json |jq -r --arg MyLastHour "$MyLastHour" '.data[$MyLastHour |tonumber]|[.datum, .prijs, .prijsZP, .prijsEE, .prijsTI, .prijsFR, .prijsAIP, .prijsEZ, .prijsZG, .prijsNE, .prijsGSL, .prijsANWB, .prijsVON, .prijsMDE]|@csv'| tr -d '"')

# Extract current price from today's pricelist in <date>.json
MyCurrentPrices=$(cat $MyDate.json |jq -r --arg MyCurrentHour "$MyCurrentHour" '.data[$MyCurrentHour |tonumber]|[.datum, .prijs, .prijsZP, .prijsEE, .prijsTI, .prijsFR, .prijsAIP, .prijsEZ, .prijsZG, .prijsNE, .prijsGSL, .prijsANWB, .prijsVON, .prijsMDE]|@csv'| tr -d '"')

Echo "-----"
Echo "Calculating Last Hour"
Echo "-----"
Echo "MyLastHourStart: 	"$MyLastHourStart
Echo "MyTSStart:  	"$MyTSStart
Echo "MyLastHourEnd:   	"$MyLastHourEnd
Echo "MyDate:      	"$MyDate
Echo "MyLastHour:      	"$MyLastHour
Echo "MyCurrentHour:  	"$MyCurrentHour


#Calculate electricity usage last hour
curl -s -o $MyTempFile "$MyDomoticzURL/json.htm?type=graph&sensor=counter&idx=$MyDomoticzPowerIdx&range=day"

Echo "-----"
Echo "-----"
Echo "Calculating Poweruse Last Hour"
Echo "-----"


MyStartValue=$(cat $MyTempFile |jq -r --arg MyLastHourStart "$MyLastHourStart" '.result[]|select(.d | startswith($MyLastHourStart))'|jq -r '[.eu]|@csv'|tr ' ' _ |tr -d '"')
MyEndValue=$(cat $MyTempFile |jq -r --arg MyLastHourEnd "$MyLastHourEnd" '.result[]|select(.d | startswith($MyLastHourEnd))'|jq -r '[.eu]|@csv'|tr ' ' _ |tr -d '"')

MyStartValueReturn=$(cat $MyTempFile |jq -r --arg MyLastHourStart "$MyLastHourStart" '.result[]|select(.d | startswith($MyLastHourStart))'|jq -r '[.eg]|@csv'|tr ' ' _ |tr -d '"')
MyEndValueReturn=$(cat $MyTempFile |jq -r --arg MyLastHourEnd "$MyLastHourEnd" '.result[]|select(.d | startswith($MyLastHourEnd))'|jq -r '[.eg]|@csv'|tr ' ' _ |tr -d '"')

Echo "MyStartValue: "$MyStartValue
Echo "MyEndValue:   "$MyEndValue
Echo "MyReturnStart:"$MyStartValueReturn
Echo "MyReturnEnd:  "$MyEndValueReturn


MyUsageWH="$(($MyEndValue-$MyStartValue))"
MyUsageKWH=$(echo "scale=4; $MyUsageWH/1000" | bc)
Echo "-----"
Echo "MyUsageWH:    "$MyUsageWH
Echo "UsageKWH:     "$MyUsageKWH

for provider in $(cat $Mydir/enever.conf |grep -v "^#")
do
 MyProviderID=$(echo $provider|cut -d, -f1)
 MyProvider=$(echo $provider|cut -d, -f3)
 MyProviderLastHourPriceIDX=$(echo $provider|cut -d, -f4)
 MyProviderCostsDayIDX=$(echo $provider|cut -d, -f5)
 MyProviderCurrentPriceIDX=$(echo $provider|cut -d, -f6)
# MyProviderCostsMonthIDX=$(echo $provider|cut -d, -f7)
# MyProviderCostsYearIDX=$(echo $provider|cut -d, -f8)
 MyPrice=$(echo $MyPrices|cut -d, -f$MyProviderID)
 MyCurrentPrice=$(echo $MyCurrentPrices|cut -d, -f$MyProviderID)
 MyCosts=$(echo "scale=4; $MyUsageKWH*$MyPrice" | bc)

Echo "-----"
 Echo "-----"
 Echo "Provider:     	"$MyProvider
 Echo "UsageKWH:     	"$MyUsageKWH
 Echo "Last Hour Price: "$MyPrice
 Echo "Costs:        	"$MyCosts
 Echo "Current Price:	"$MyCurrentPrice


 # Retreive cost counters
 MyDayCost=$(curl -s "$MyDomoticzURL/json.htm?type=graph&sensor=Percentage&idx=$MyProviderCostsDayIDX&range=day"|jq -r '.result[-1]|.v')
 Echo "MyDayCost: "$MyDayCost



 # Calculate new value
 MyNewCosts=$(printf "%.2f" $(echo "scale=2; $MyDayCost+$MyCosts" | bc))
 Echo "MyNewCosts: "$MyNewCosts


 Echo "-----"
 Echo "Updating Cost Counters"
 Echo "-----"


 # Update cost counters
 curl -s "$MyDomoticzURL/json.htm?type=command&param=udevice&idx=$MyProviderCostsDayIDX&nvalue=0&svalue=$MyNewCosts"
 curl -s "$MyDomoticzURL/json.htm?type=command&param=udevice&idx=$MyProviderLastHourPriceIDX&nvalue=0&svalue=$MyPrice"
 curl -s "$MyDomoticzURL/json.htm?type=command&param=udevice&idx=$MyProviderCurrentPriceIDX&nvalue=0&svalue=$MyCurrentPrice"

 Echo "-----"
 Echo "Sending Telegram"
 Echo "-----"

 # Send price to telegram
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=**********************************"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=Verbruik+afgelopen+uur+$MyUsageWH+Watt"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=Stroomprijs+afgelopen+uur+$MyPrice+euro"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=Kosten+afgelopen+uur+$MyCosts+euro"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=Verbruik+tot+nu+toe+$MyNewCosts+euro"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=Huidige+Stroomprijs+$MyCurrentPrice+euro"
  curl -s "https://api.telegram.org/bot$MyTelegramAPI/sendMessage?chat_id=$MyTelegramChatID&text=**********************************"

 Echo "-"
 Echo "Done"


done

