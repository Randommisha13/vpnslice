# vpnslice

A solution for per-app split routing through TUN interfaces. 

Core idea was taken from [occasion-2/netslice](https://github.com/occasion-2/netslice).

## Requirements

- `systemd` for managing slices/cgroups
- `iproute2` for policy-based routing
- `nftables` for marking packets based on cgroup
- `jq` for loading configs
- `(p)locate` as a fast alternative to find
- `dex` for parsing and executing .desktop files
- `pkexec` and `polkit` for privilege elevation

## Usage

vpnslice is launched using two systemd services --
`vpnslice-system-setup@.service` and `vpnslice-user-setup@.service` (the reason
for splitting the service is explained in the Architecture section).

Both of these units are template units, `vpnslice-system-setup@.service`
expects the name of the config file (without `.json` extension), and
`vpnlice-user-setup@.service` expects the name of the slice that was previously
prepared by system-setup.

To activate slice `secrets` for user `johndoe` you will need to put
configuration file, in configuration directory (`/etc/vpnslice/` or
`/etc/local/vpnslice/` by default). You can use any name, except
(`global.json`), in this example `1000-johndoe-secrets` will be used:

Contents of `1000-johndoe-secrets.json`:
```json
{
    "username": "johndoe",
    "user_slice_name": "secrets",
    "vpn_tun_name": "tun0"
}

```

`username` and `user_slice_name` are mainly used for bookkeeping and isolation
of diferent users' configuration, but should be set correctly because script
launched by `vpnslice-user-setup@.service` checks that
`vpnslice-system-setup@.service` was invoked with the same username and slice
name.

`vpn_tun_name` is the name of the interface which will be used as a default
route for applications inside `secrets` slice.

After writing the configuration file you need to

1. Launch your VPN of choice (and ensure that interface name is correct)

2. Start system setup:
   `systemctl --system start vpnslice-system-setup@1000-johndoe-secrets.service`

3. Finalize user setup:
   `systemctl --user start vpnslice-user-setup@secrets.service`

Step 3 will fail without step 2, and should automatically start the
corresponding user slice.

To launch a application inside vpnslice you can either use  
`vpnslice-launch --slice secrets command ...`  
or  
`DESKTOP_ENTRY_ID=app.desktop vpnslice-launch --slice secrets`

## Tips and tricks

#### Using GUI to launch apps

`miscellaneous` folder contains an example secrets-launch.desktop entry that
uses fuzzel to choose which application to launch.

You can copy it to `$XDG_DATA_HOME/applications`
(`~/.local/share/applications`) and edit the slice name in the `Exec=` entry.

#### Ordering TUN device startup

If your TUN device is set up via systemd unit, you can add it as a dependency:

Open systemd's edit dialog
```
systemctl edit vpnslice-system-setup@1000-johndoe-secrets.service
```

Insert the following into override file:

```
[Unit]
Requires=myvpn-unit.service
```

## Architecture

### How vpnslice does routing

`nftables` support matching packets by cgroup they belong to, and setting
fwmark as one of the actions:

```
# nft list ruleset
table inet vpnslice-1000-johndoe-secrets {
	chain output {
		type route hook output priority mangle; policy accept;
		socket cgroupv2 level 4 "user.slice/user-1000.slice/user@1000.service/secrets.slice" meta mark set 0x00001010
	}
}
```

`iproute2` includes policy-based routing, which can redirect route lookup to a
different route table if it matches some condition, including fwmarks:

```
$ ip rule show
0:	from all lookup local
32765:	from all fwmark 0x1010 lookup 1010
32766:	from all lookup main
32767:	from all lookup default
```

Said table can contain a route that forwards all traffic through TUN interface:

```
# ip route show table 1010
default dev tun0 scope link
```

### How vpnslice is set up

`vpnslice-system-setup` creates necessary infrastructure -- it adds routing
rule and table with default route through TUN, but because vpnslice uses user
slices, it can't immediately setup nftables rules, because the slice might be
not up yet, so it only records which fwmark was chosen.

This is solved with helpers, `vpnslice-user-finalize` and
`vpnslice-user-flatpak-helper`.  
The former checks if the routing for the slice was set up, and adds nftables
rules. Requires the name of the slice as an argument.   
The latter is invoked to add rules for flatpak scopes, which is required
because flatpak will only launch as a child of app.slice, which would mean
routing all running apps through a VPN. Requires the name of the slice and at
lease one flatpak scope as arguments.

Because manipulating nftables requires root privileges, helpers are required to
be launched through `sudo` or `pkexec` (systemd units use the former); build
process also creates `pkexec`/polkit rules file that allow any member of group
'`wheel`' to launch them without a password.

### How vpnslices launches apps

`vpnslice-launch` works in three modes, all three require either `--slice
SLICE_NAME` or `--config CONFIG_FILE` as arguments before any others:

1) `run_systemd` for CLI usage, passes all arguments following
`--slice`/`--config` to systemd-run.

2) `run_desktop_noflatpak` expects `DESKTOP_ENTRY_ID` environment variable to
be set (with launcher like fuzzel). It finds which command does .desktop file
execute, and if it is not `/usr/bin/flatpak`, then it executes .desktop file
like `run_systemd`.

3) `run_systemd` if .desktop file executes `/usr/bin/flatpak`, then script
records every running flapak scope, executes desktop file, and, after waiting
for some 3 seconds, finds running scopes again to pass any new ones to
`vpnslice-user-flapak-helper`.

## Configuration

`vpnslice-system-setup`'s configuration is stored in
"`$(sysconfigdir)/vpnlice`" ("`/etc/vpnslice` with built package"), each file
should specify user, slice name and TUN device to route traffic through.
(example config is available in `examples/`). `global.json` is a reserved name
for config that specifies parameters related to the script's operation,
currently only fwmark range and state dir (is not read by helpers).

## Standalone scripts

TODO: Write information about standalone scripts
