#!/bin/sh

# This script will either:
# Fetch phy data and from all associated stations (-p)
# Fetch capabilites from all associated stations (-c)
# Fetch chanim stats (-s) on both radios
# Usage example: "ssh root@x.x.x.x 'sh -s' -- < wl_localscript.sh -c"

# Exit if no argument is given
if [ -z "$1" ]; then
	echo "Usage: $0 -p <input data>"
	exit 1
fi

# Identifier
count="$(( ( RANDOM % 9999 )  + 100 ))"
HOSTNAME=`cat /sys/class/net/eth4/address | tr -d ':'`

if [ $1 = "-p" ]; then
mac=$3
#count=$7
radios="wl0 wl1"

physta_func () {
input_radio=$1
for macs in `wl -i $input_radio assoclist | awk {'print $2'}`; do 
mac=`printf $macs | grep -v assoclist`
stamac_clean=`printf $mac | tr -d ':'`
	for radio in $input_radio;do

# Noise and RSSI per STA is not supported by tg343295c	
#wl -i $radio sta_info $mac | egrep 'frame:' | tr -d 'per|antenna|rssi|of|last|rx|data|frame|:|average|noise|floor|frames' | xargs | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_rssi[$(echo $count)]: $LABEL1 $LABEL2 /"
#wl -i $radio sta_info $mac | egrep 'noise' | tr -d 'per|antenna|rssi|of|last|rx|data|frame|:|average|noise|floor|frames' | xargs | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_noise[$(echo $count)]: $LABEL1 $LABEL2 /"

wl -i $radio sta_info $mac | egrep 'pkt:' | grep 'tx' | tr -d 'rate||of|last|tx|pkt|:|kbps|-' | xargs | awk '{print $1}' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_txphyrate[$(echo $count)]: $radio $stamac_clean /"

wl -i $radio sta_info $mac | egrep 'pkt:' | grep 'rx' | tr -d 'rate|of|last|rx|:kbps' | xargs | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_rxphyrate[$(echo $count)]: $radio $stamac_clean /"
	done
done
}

wl -i wl1 nrate | awk {'print $3,$5,$8,$9'} | tr -d 'bw' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_values_5ghz[$(echo $count)]: /"
wl -i wl0 nrate | awk {'print $3,$6,$7,$8'} | tr -d 'bw' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_values_24ghz[$(echo $count)]: /"

physta_func wl0
physta_func wl1

# Capability
elif [ $1 = "-c" ]; then
#HOSTNAME=$2
radios="wl0 wl1"

# Fetch capabilites

capa_parse () {
input_radio=$1
sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_capa_$input_radio[$(echo $count)]: /"
}

capa_func () {
input_radio=$1
for macs in `wl -i $input_radio assoclist | awk {'print $2'}`; do
mac=`printf $macs | grep -v assoclist`
stamac_clean=`printf $mac | tr -d ':'`
        for radio in $input_radio;do
capfile="/var/wl_caps_${radio}_$stamac_clean"
wl -i $input_radio sta_info $mac | egrep 'flags|caps' > $capfile

# VHT Cap
vht=`grep VHT_CAP $capfile | wc -l`

# N Cap
if [ $vht -ge 1 ];then ht=0
else ht=`grep N_CAP $capfile | wc -l`
fi

# TXBF Cap
txbf=`grep SU-BFR $capfile | wc -l`

# BRCM Cap
brcm=`grep BRCM $capfile | wc -l`

# Determine legacy capabilites
if [ $vht -eq 0 ] && [ $ht -eq 0 ]; then legacy=1
else legacy=0
fi

# Create capability data
printf "$stamac_clean $vht $txbf $brcm $ht $legacy \n"

# Capabilites for both radios
#               for dualband in {24ghz,5ghz};do 
#if [ $brcm -eq 1 ] && [ $txbf -eq 1 ] && [ $ht -eq 1 ]; then
#echo $mac $ht $txbf $brcm | capa_parse $dualband
#elif [ $brcm -eq 0 ] && [ $txbf -eq 0 ] && [ $ht -eq 1 ]; then
#echo $mac $ht $brcm | capa_parse $dualband
#fi
#               done
        done
done

}
capa_func wl0 | capa_parse 24ghz
capa_func wl1 | capa_parse 5ghz

# Chanim
elif [ $1 = "-s" ]; then
wl0_file="/var/wl0_chanim"
wl1_file="/var/wl1_chanim"

fetch_data () {
cat $wl0_file;rm -f $wl0_file
cat $wl1_file;rm -f $wl1_file
}

wl_loop() {
if [ `pgrep -f 'sleep 2' | wc -l` -eq 0 ]; then # Only even attempt to start if there's nothing running.

# 2.4Ghz "daemon"
	while sleep 2;do wl -i wl0 chanim_stats | tail -1 | awk '$1=$1' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_chanim_24ghz[$(echo $count)]: /" >> $wl0_file
	if [ `ls -l1 $wl0_file | awk {'print $3'}` -ge 5000000 ]; then rm -f $wl0_file # Delete log on 5MB
	fi;done &

# 5Ghz "daemon"
	while sleep 2;do wl -i wl1 chanim_stats | tail -1 | awk '$1=$1' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_chanim_5ghz[$(echo $count)]: /" >> $wl1_file
	if [ `ls -l1 $wl1_file | awk {'print $3'}` -ge 5000000 ]; then rm -f $wl1_file
	fi;done &

fi
}

kill_loop () {
while [ `pgrep -f 'sleep 2' | wc -l` -ge 3 ]; do echo 'To many scripts running, killing all loops and restarting..'
kill $(pgrep -f 'sleep 2'); rm -f $wl0_file $wl1_file
done
sleep 1
wl_loop
}


	# Make sure just 1 script is running at all time
	if [ `pgrep -f 'sleep 2' | wc -l` -ge 3 ];then echo 'To many scripts running..'
	kill_loop

	# Run and daemonize one while loop for each radio
	wl_loop

        elif [ `pgrep -f 'sleep 2' | wc -l` -eq 1 ]; then kill_loop

	# If for some reason you don't want do fetch data if stuff went wrong, call the fetch_data function here instead
#	else
#	fetch_data
	fi

# Gather data
fetch_data | sort

# Reference
# chanspec tx   inbss   obss   nocat   nopkt   doze     txop     goodtx  badtx   glitch   badplcp  knoise  idle  timestamp

# Get Airtime average last minute
# awk {'print $13'} <input> | awk '{ total += $1; count++ } END { print total/count }'

# Trigger scan and get full environment data
elif [ $1 = "-t" ]; then # TODO
# sed -i 's@quick_scan=0@quick_scan=1@g' /etc/wireless_acs.conf # quick scan (needs hostapd reload)
# hostapd_cli "acs rescan" # Performs a scan (dangerous)
hostapd_cli "acs debug dumpacsmeas topic bss radio_id=0" | grep -v channel | awk '$1=$1' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_envchan24ghz_[$(echo $count)]: /"
hostapd_cli "acs debug dumpacsmeas topic bss radio_id=1" | grep -v channel | awk '$1=$1' | sed -e "s/^/$(date "+%b %d %H:%M:%S") $HOSTNAME 389ac_envchan5ghz_[$(echo $count)]: /"
# hostapd_cli "acs debug dumpacsmeas topic bsslist radio_id=0" # SSID/RSSI/capabilites etc

else echo 'no correct argument given, aborting' && exit 1
fi
