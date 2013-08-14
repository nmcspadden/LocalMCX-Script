#!/bin/sh
# This script sets up and configures LocalMCX
# this version 16 May 2012 Greg Neagle
# updated for Mountain Lion compatibility

# these GUIDs must match those referred to in the /ComputerGroups groupmembership
local_desktop_GUID="B4247B97-F249-4409-8EA3-BA8E168BA0DA"
local_laptop_GUID="15BEE70A-A32D-4A33-B740-93CBE95F75A4"

changedMCX=false

# first make sure /Local/MCX node exists
# mkdir -p doesn't report an error if the directory
# already exists
# under Lion, alternate Local DS nodes must have
# users and groups directories or they are rejected as
# invalid
/bin/mkdir -p -m 700 /private/var/db/dslocal/nodes/MCX
/bin/mkdir -p -m 700 /private/var/db/dslocal/nodes/MCX/users
/bin/mkdir -p -m 700 /private/var/db/dslocal/nodes/MCX/groups
/bin/mkdir -p -m 700 /private/var/db/dslocal/nodes/MCX/computers
/bin/mkdir -p -m 700 /private/var/db/dslocal/nodes/MCX/computergroups
/usr/sbin/chown -R root:wheel /private/var/db/dslocal/nodes/MCX

# get the major OS version, we need it a few places later
# 9 = Leopard
# 10 = Snow Leopard
# 11 = Lion
# 12 = Mountain Lion
OSVERS=`/usr/bin/uname -r | /usr/bin/cut -d'.' -f1`

# does DirectoryService/opendirectoryd know about the
# /Local/MCX node?
output=`/usr/bin/dscl /Local/MCX list /`
if [ "$?" -ne "0" ]; then
    # non-zero return code from dscl
    # hopefully because we just created the node and 
    # DirectoryService/opendirectoryd doesn't know about it yet
    # so kill DirectoryService/opendirectoryd
    # they restart automatically and check for new nodes
    if [ "$OSVERS" -gt "10" ] ; then
        /usr/bin/killall opendirectoryd
    else
        /usr/bin/killall DirectoryService
    fi
    # check with dscl again and fail if we can't access the /Local/MCX node
    output=`/usr/bin/dscl /Local/MCX list /`
    if [ "$?" -ne "0" ] ; then
        echo "/Local/MCX node not accessible!"
        exit 0
    fi
fi

# now make sure /Local/MCX is in the search path, after /Local/Default /BSD/local
localMCXinSearchPath=`/usr/bin/dscl /Search read / CSPSearchPath | /usr/bin/grep "/Local/MCX"`
if [ "$localMCXinSearchPath" == "" ] ; then
    currentSearchPathContainsBSDlocal=`/usr/bin/dscl /Search read / CSPSearchPath | /usr/bin/grep "/BSD/local"`
    if [ "$currentSearchPathContainsBSDlocal" != "" ] ; then
        currentSearchPathBegin="/Local/Default /BSD/local"
        currentSearchPathEnd=`/usr/bin/dscl /Search read / CSPSearchPath | /usr/bin/cut -d" " -f4-`
    else
        currentSearchPathBegin="/Local/Default"
        currentSearchPathEnd=`/usr/bin/dscl /Search read / CSPSearchPath | /usr/bin/cut -d" " -f3-`
    fi
    /usr/bin/dscl /Search create / SearchPolicy CSPSearchPath
    /usr/bin/dscl /Search create / CSPSearchPath $currentSearchPathBegin /Local/MCX $currentSearchPathEnd
    changedMCX=true
fi

# Mountain Lion (through DP3) doesn't let us use dscl to write to the /Local/MCX node, 
# so we will do our editing in the Local/Default node, then copy the resulting files 
# to the /Local/MCX node
if [ "$OSVERS" -gt "11" ] ; then
    MCXNODE="/Local/Default"
else
    MCXNODE="/Local/MCX"
fi

current_local_desktop_GUID=`/usr/bin/dscl /Local/MCX -read /Computers/local_desktop GeneratedUID | cut -f2 -d " "`
current_local_laptop_GUID=`/usr/bin/dscl /Local/MCX -read /Computers/local_laptop GeneratedUID | cut -f2 -d " "`

if [ "$current_local_desktop_GUID" != "$local_desktop_GUID" ] ; then
    echo "Updating GUID for /Computers/local_desktop..."
    if [ "$OSVERS" -gt "11" ]; then
        /bin/rm -f /private/var/db/dslocal/nodes/MCX/Computers/local_desktop.plist
    fi
    echo "was: $current_local_desktop_GUID"
    echo "now: $local_desktop_GUID"
    /usr/bin/dscl "$MCXNODE" -create /Computers/local_desktop GeneratedUID $local_desktop_GUID
    changedMCX=true
fi
if [ "$current_local_laptop_GUID" != "$local_laptop_GUID" ] ; then  
    echo "Updating GUID for /Computers/local_laptop..."
    if [ "$OSVERS" -gt "11" ]; then
        /bin/rm -f /private/var/db/dslocal/nodes/MCX/Computers/local_laptop.plist
    fi
    echo "was: $current_local_laptop_GUID"
    echo "now: $local_laptop_GUID"
    /usr/bin/dscl "$MCXNODE" -create /Computers/local_laptop GeneratedUID $local_laptop_GUID
    changedMCX=true
fi

macAddress=`/sbin/ifconfig en0 | /usr/bin/awk '/ether/ {print $2}'`
if [ "$macAddress" == "" ]; then
    sleep 2
    # try again
    macAddress=`/sbin/ifconfig en0 | /usr/bin/awk '/ether/ {print $2}'`
fi
if [ "$macAddress" == "" ]; then
    echo "Can't get MAC layer address of en0!"
    exit 0
fi
IS_LAPTOP=`/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book"`

if [ "$IS_LAPTOP" != "" ]; then
    computerRecordName=local_laptop
    otherRecordName=local_desktop
else
    computerRecordName=local_desktop
    otherRecordName=local_laptop
fi

storedMacAddress=`/usr/bin/dscl /Local/MCX -read /Computers/$computerRecordName ENetAddress | cut -f2 -d " "`
if [ "$storedMacAddress" != "$macAddress" ] ; then
    echo "Updating MAC address for /Computers/$computerRecordName..."
    echo "was: $storedMacAddress"
    echo "now: $macAddress"
    /usr/bin/dscl "$MCXNODE" -create /Computers/$computerRecordName ENetAddress $macAddress
    /usr/bin/dscl "$MCXNODE" -create /Computers/$computerRecordName comment "Auto-Created"
    /usr/bin/dscl "$MCXNODE" -delete /Computers/$otherRecordName ENetAddress
    changedMCX=true
fi

storedHardwareUUID=`/usr/bin/dscl /Local/MCX -read /Computers/$computerRecordName hardwareuuid | cut -f2 -d " "`
thisHardwareUUID=`/usr/sbin/system_profiler SPHardwareDataType | grep "Hardware UUID:" | cut -d":" -f2 | cut -d " " -f2`
if [ "$storedHardwareUUID" != "$thisHardwareUUID" ] ; then
    echo "Updating Hardware UUID for /Computers/$computerRecordName..."
    echo "was: $storedHardwareUUID"
    echo "now: $thisHardwareUUID"
    if [ "$thisHardwareUUID" ] ; then
        /usr/bin/dscl "$MCXNODE" -create /Computers/$computerRecordName hardwareuuid "$thisHardwareUUID"
    else
        /usr/bin/dscl "$MCXNODE" -delete /Computers/$computerRecordName hardwareuuid
    fi
    /usr/bin/dscl "$MCXNODE" -delete /Computers/$otherRecordName hardwareuuid
    changedMCX=true
fi

if [ "$changedMCX" == "true" ] ; then
    echo "MCX settings were changed."
    
    if [ "$OSVERS" -gt "11" ] ; then
        # Mountain Lion, move our local computer records from Local/Default to the Local/MCX node
        /bin/mv /private/var/db/dslocal/nodes/Default/computers/local_desktop.plist /private/var/db/dslocal/nodes/MCX/computers/
        /bin/mv /private/var/db/dslocal/nodes/Default/computers/local_laptop.plist /private/var/db/dslocal/nodes/MCX/computers/
    fi
    
    if [ "$OSVERS" -gt "10" ] ; then
        /usr/bin/killall opendirectoryd
    else
        /usr/bin/killall DirectoryService
    fi
fi