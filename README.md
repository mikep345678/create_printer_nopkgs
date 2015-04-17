# create_printer_nopkgs

##################
### Documentation
###

1. update SDOB_printerlist-MASTER Google Spreadsheet

 1b. can export list of printers from AD, ie: dscl "/Active Directory/AD/All Domains" -list Printers > printerlist_all.txt

 1c. to find OSX printer driver file, ie: zgrep -r "iR5050" /Library/Printers/PPDs

  1c1. If zgrep finds nothing, correct driver needs to be downloaded

   1c1a. http://support.apple.com/kb/ht3669 lists OSX printer driver sources

  1c2. add new printer driver to drivers package in munki!

  1c3. install driver locally then re-zgrep!

2. export SDOB_printerlist-MASTER as CSV

 2b. copy to {scriptfolder}
 
 2c. create printerlist-{date}.csv by extracting only printers needing updated from printerdrivers-MASTER.txt
 
  2c1. delete header row; leave one <return> at the end of the final line

3. edit build_printers_with_options-{date}.{ver}.sh to reflect correct vers, currentVersion and printerlistfile

 3b. run build_printers_with_options-{date}.{ver} script to build new printer packages

 3c. run postinstall.sh for each printer under new printers.custom-{date}.{ver} folder to create printers, without custom options

4. customize printers using cups web interface (http://localhost:631/printers/) to match printer options

  4b. select printer, under Administration drop select Set Default Options

   4b1. set options, click "Set Default Options" button below list of options
   
   4b2. Click Color "tab", dis/en/able color, click "Set Default Options" button below list of options
   
  4c. copy customized PPDs from /etc/cups/ppd to {scriptfolder}/new_ppds
  
cd ~/Documents/scripting/fix_printer_list/; for i in $(find /etc/cups/ppd -type f -mtime -1); do cp $i new_ppds/; done

5. rerun build_printers_with_options-{date}.{ver} script to rebuild pkginfos with options

6. copy .pkginfo files from printers.custom-{date}.{ver}/pkginfo to {munki_repo}/pkgsinfo/printers

  6b. for each new pkginfo, set Autoremove and Uninstallable
  
  6c. munki makecatalogs
