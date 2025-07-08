# Teleport Client Auto Updates

They call the node software "agent" software and they call the software we run
on our computers "client tools". There are autoupdates for both. "Managed
updates" is what they call the automatic updates for the "agent" software.

## Reference

https://goteleport.com/docs/upgrading/client-tools-autoupdate/

https://goteleport.com/docs/upgrading/agent-managed-updates/

## Commands

```
# list nodes with managed updates enabled
tctl inventory ls --upgrader=binary

# list notes with managed updates disabled
tctl inventory ls --upgrader=none

# count SSH agent nodes
tctl inventory ls --services=node | tail -n +2 | wc -l

# enable on a node
sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops
```

## Notes

For future reference, we can create groups of nodes with:
```
teleport-update enable --group <group name>
```
Which would allow us to set production nodes, staging nodes, testing nodes, 
etc. Also, you can make it so that certain groups won't update until N hours 
after another group. For example: update `dev` group first, then wait 72 hours
and then update `staging` group, then wait another 72 hours, then update `prod`
group. The timings and group names are arbitrary and configurable.

---

We'll need to start uploading checksums to the Nexus repo. Output here:
```
website@as.aopstest.com ~ $ sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops
2025-07-08T16:26:37.696-04:00 INFO [UPDATER]   Initiating installation. target_version:17.5.4 active_version:17.5.4 agent/updater.go:409
2025-07-08T16:26:37.727-04:00 ERRO [UPDATER]   Command failed. error:[
ERROR REPORT:
Original Error: *errors.errorString checksum not found: https://nexus-anon.aops.tools/repository/devops/teleport-v17.5.4-linux-amd64-bin.tar.gz.sha256
Stack Trace:
	github.com/gravitational/teleport/lib/autoupdate/agent/installer.go:260 github.com/gravitational/teleport/lib/autoupdate/agent.(*LocalInstaller).getChecksum
	github.com/gravitational/teleport/lib/autoupdate/agent/installer.go:137 github.com/gravitational/teleport/lib/autoupdate/agent.(*LocalInstaller).Install
	github.com/gravitational/teleport/lib/autoupdate/agent/updater.go:961 github.com/gravitational/teleport/lib/autoupdate/agent.(*Updater).update
	github.com/gravitational/teleport/lib/autoupdate/agent/updater.go:412 github.com/gravitational/teleport/lib/autoupdate/agent.(*Updater).Install
	github.com/gravitational/teleport/tool/teleport-update/main.go:365 main.cmdInstall
	github.com/gravitational/teleport/tool/teleport-update/main.go:218 main.Run
	github.com/gravitational/teleport/tool/teleport-update/main.go:67 main.main
	runtime/proc.go:272 runtime.main
	runtime/asm_amd64.s:1700 runtime.goexit
User Message: failed to install
	failed to download checksum from https://nexus-anon.aops.tools/repository/devops/teleport-v17.5.4-linux-amd64-bin.tar.gz.sha256
		checksum not found: https://nexus-anon.aops.tools/repository/devops/teleport-v17.5.4-linux-amd64-bin.tar.gz.sha256] teleport-update/main.go:249
```

---

Teleport somehow does not lose connection when you update it. It hands off the 
connection to the new agent service and you stay connected. So if it succeeds,
it doesn't cause any disruption.
