#!/bin/bash

# define script version
vers="20150330.01"

# define printer package version
currentVersion="20150330.01"

# define name of file containing printers to process
printerlistfile="SDOB printerlist-20150330.01.csv"


##################
### Documentation
###

## 1. update SDOB_printerlist-MASTER Google Spreadsheet
## 1b. can export list of printers from AD, ie: dscl "/Active Directory/AD/All Domains" -list Printers > printerlist_all.txt
## 1c. to find OSX printer driver file, ie: zgrep -r "iR5050" /Library/Printers/PPDs
## 1c1. If zgrep finds nothing, correct driver needs to be downloaded
## 1c1a. http://support.apple.com/kb/ht3669 lists OSX printer driver sources
## 1c2. add new printer driver to drivers package in munki!
## 1c3. install driver locally then re-zgrep!

## 2. export SDOB_printerlist-MASTER as CSV
## 2b. copy to {scriptfolder}
## 2c. create printerlist-{date}.csv by extracting only printers needing updated from printerdrivers-MASTER.txt
## 2c1. delete header row; leave one <return> at the end of the final line

## 3. edit build_printers_with_options-{date}.{ver}.sh to reflect correct vers, currentVersion and printerlistfile
## 3b. run build_printers_with_options-{date}.{ver} script to build new printer packages
## 3c. run postinstall.sh for each printer under new printers.custom-{date}.{ver} folder to create printers, without custom options

## 4. customize printers using cups web interface (http://localhost:631/printers/) to match printer options
## 4b. select printer, under Administration drop select Set Default Options
## 4b1. set options, click "Set Default Options" button below list of options
## 4b2. Click Color "tab", dis/en/able color, click "Set Default Options" button below list of options
## 4c. copy customized PPDs from /etc/cups/ppd to {scriptfolder}/new_ppds
####### cd ~/Documents/scripting/fix_printer_list/; for i in $(find /etc/cups/ppd -type f -mtime -1); do cp $i new_ppds/; done

## 5. rerun build_printers_with_options-{date}.{ver} script to rebuild pkginfos with options

## 6. copy .pkginfo files from printers.custom-{date}.{ver}/pkginfo to {munki_repo}/pkgsinfo/printers
## 6b. for each new pkginfo, set Autoremove and Uninstallable
## 6b. munki makecatalogs

### 20140226- added "2>/dev/null" to lpstat -p commands to suppress errors when stat'ing printer not on machine
###
##################

## module to create installcheck scripts
create_installcheck_script()
{
thisscript="$installcheck_script_name"

	echo "#!/bin/bash" > "$thisscript"
	echo "printername=\"$printername\"" >> "$thisscript"
	echo "location=\"$printername\"" >> "$thisscript"
	echo "gui_display_name=\"$printername\"" >> "$thisscript"
	echo "address=\"smb://$print_server.ad.barabooschools.net/$printername\"" >> "$thisscript"
	echo "driver_ppd=\"$originalppd\"" >> "$thisscript"
	echo "options=\"$printeroptions\"" >> "$thisscript"
	echo "currentVersion=\"$currentVersion\"" >> "$thisscript"

	cat >> "$thisscript" <<\EOF

### Determine if receipt is installed ###
if [ -e /private/etc/cups/deployment/receipts/$printername.plist ]; then
        storedVersion=`/usr/libexec/PlistBuddy -c "Print :version" /private/etc/cups/deployment/receipts/$printername.plist`
        echo "Stored version: $storedVersion"
else
        storedVersion="0"
fi

versionComparison=`echo "$storedVersion < $currentVersion" | bc -l`
# This will be 0 if the current receipt is greater than or equal to current version of the script

### Printer Install ###
# If the queue already exists (returns 0), we don't need to reinstall it.
/usr/bin/lpstat -p $printername 2>/dev/null
if [ $? -eq 0 ]; then
        if [ $versionComparison == 0 ]; then
                # We are at the current or greater version
                exit 1
        fi
    # We are of lesser version, and therefore we should delete the printer and reinstall.
    exit 0
fi

EOF

chmod a+x "$thisscript"


}

## module to create postinstall scripts
create_postinstall_script()
{
thisscript="$postinstall_script_name"

	echo "#!/bin/bash" > "$thisscript"
	echo "printername=\"$printername\"" >> "$thisscript"
	echo "location=\"$printername\"" >> "$thisscript"
	echo "gui_display_name=\"$printername\"" >> "$thisscript"
	echo "address=\"smb://$print_server.ad.barabooschools.net/$printername\"" >> "$thisscript"
	echo "driver_ppd=\"$originalppd\"" >> "$thisscript"
	echo "options=\"$printeroptions\"" >> "$thisscript"
	echo "currentVersion=\"$currentVersion\"" >> "$thisscript"

	cat >> "$thisscript" <<\EOF

##logger -t [create_$printername] "Creating printer"

### Determine if receipt is installed ###
if [ -e /private/etc/cups/deployment/receipts/$printername.plist ]; then
        storedVersion=`/usr/libexec/PlistBuddy -c "Print :version" /private/etc/cups/deployment/receipts/$printername.plist`
        echo "Stored version: $storedVersion"
else
        storedVersion="0"
fi

versionComparison=`echo "$storedVersion < $currentVersion" | bc -l`
# This will be 0 if the current receipt is greater than or equal to current version of the script

##logger -t [create_$printername] "Stored Version= $storedVersion"
##logger -t [create_$printername] "Current Version= $currentVersion"
##logger -t [create_$printername] "Version Comparison= $versionComparison"


### Printer Install ###
# If the queue already exists (returns 0), we don't need to reinstall it.
/usr/bin/lpstat -p $printername 2>/dev/null
if [ $? -eq 0 ]; then
        if [ $versionComparison == 0 ]; then
				##logger -t [create_$printername] "at current or greater version, exiting"
				exit 0
        fi
	##logger -t [create_$printername] "removing printer to reinstall"
    /usr/sbin/lpadmin -x $printername
fi


echo "printername:$printername; printerqueue:$printerqueue; driverppd:$driver_ppd"

 /usr/sbin/lpadmin \
        -p "$printername" \
        -L "$location" \
        -D "$gui_display_name" \
        -v "$address" \
        -P "$driver_ppd" \
        -o printer-is-shared=false \
        -o printer-error-policy=abort-job \
        -o auth-info-required=negotiate $options -E
        
# Enable and start the printers on the system (after adding the printer initially it is paused).
/usr/sbin/cupsenable $(lpstat -p | grep -w "printer" | awk '{print$2}')

# Create a receipt for the printer
mkdir -p /private/etc/cups/deployment/receipts
/usr/libexec/PlistBuddy -c "Add :version string" /private/etc/cups/deployment/receipts/$printername.plist
/usr/libexec/PlistBuddy -c "Set :version $currentVersion" /private/etc/cups/deployment/receipts/$printername.plist


# Permission the directories properly.
chown -R root:_lp /private/etc/cups/deployment
chmod -R 700 /private/etc/cups/deployment

##logger -t [create_$printername] Created printer

exit 0
EOF

chmod a+x "$thisscript"
}

## Module to create uninstall scripts
create_uninstall_script()
{
thisscript="$uninstall_script_name"

	echo "#!/bin/bash" > "$thisscript"
	echo "printername=\"$printername\"" >> "$thisscript"
	cat >> "$thisscript" <<-\EOF
		/usr/sbin/lpadmin -x $printername
		rm -f /private/etc/cups/deployment/receipts/$printername.plist
		
		exit 0
	EOF

chmod a+x "$thisscript"
}

## Module to create pkginfo files
make_pkginfo()
{
/usr/local/munki/makepkginfo --name="ptr_$printername_pkginfo" --displayname="ptr_$printername_pkginfo" \
 --minimum_os_version="10.8" \
 --catalog="testing" \
 --unattended_install \
 --autoremove \
 --nopkg \
 --pkgvers="$currentVersion" \
 --installcheck_script="$installcheck_script_name" \
 --postinstall_script="$postinstall_script_name" \
 --uninstall_script="$uninstall_script_name" > "$pkginfofoldername/ptr_$printername_pkginfo-$currentVersion.pkginfo"

}

###
## main body of script
###

## change to script folder directory
cd "$( dirname "${BASH_SOURCE[0]}" )"

outputfoldername="printers.custom-$currentVersion"

echo "executing ${BASH_SOURCE[0]} from $printerlistfile with output to $outputfoldername..."

while IFS=, read date_last_updated printer ad_print_server ad_driver ppd osx_driver model comment
do
    echo "$printer:$ppd"
	printername="$printer"
	printername_pkginfo="${printername//-/_}"
	pkginfofoldername="$outputfoldername/_pkginfo"
	printerfoldername="$outputfoldername/ptr_$printername"
#	printerscriptname="$printerfoldername/postflight"
	installcheck_script_name="$printerfoldername/installcheck_script.sh"
	postinstall_script_name="$printerfoldername/postinstall_script.sh"
	uninstall_script_name="$printerfoldername/uninstall_script.sh"
	originalppd="$ppd"
	targetppd="/etc/cups/ppd/$printername.ppd"
	customppd="new_ppds/$printername.ppd"
#	customppd="$targetppd"

echo "customppd=$customppd"

	if [ -e "$customppd" ] ; then
		printeroptions=$(./zdiff.108 "$originalppd" "$customppd" | grep "> [*]Default" | sed 's/> [*]Default/-o /g' | sed 's/: /=/g' | awk '{printf("%s ", $0)}' )
	else
		printeroptions=""
	fi
	
	print_server="$ad_print_server"

	mkdir -p "$printerfoldername"
	mkdir -p "$pkginfofoldername"

	create_installcheck_script
	create_postinstall_script
	create_uninstall_script
	make_pkginfo
	
done < "$printerlistfile"

echo "completed..."

exit 0
