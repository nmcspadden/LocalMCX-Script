LocalMCX-Script
===============
These are the pieces necessary to get an idempotent Local MCX install setup.  I used Iceberg to generate a package that installs the ChangeMCXLion.sh script to /usr/local/libexec/ChangeMCXLion.sh, and place the launchdaemon plist into /Library/LaunchDaemons/ and then the runs the postflight which triggers the loading of the launchdaemon.

This way, ChangeMCXLion.sh executes immediately upon on install, and always on startup.  It's idempotent, so it's okay to run every startup without causing any additional changes - and it fixes any problems or configuration changes.

This way, any further MCX settings can be simply deployed into /private/var/db/dslocal/nodes/MCX/computergroups/ and will simply work upon restart.
