# Privacy-First Fedora Dotfiles

A rock-solid, minimal-bloat, keyboard-driven starting point for Fedora Workstation
with strong privacy and security defaults.

> **Scope:** This repo automates system settings, hardening, app installation, and
> browser policy. It is intentionally opinionated. Read the "What breaks" and
> "Revert" sections before running.

## Why this exists

I have been a Linux user for over a decade. Omedora was inspired by David Heinemeier Hansson's project, Omarchy. DHH's sense of aesthetics is inspiring, but I wanted something closer to my own principles: stable, predictable, focused, and pragmatic.

The desktop is becoming even more clearly a workstation. With AI, a computer is a place for deep work and productivity, not for entertainment or social media. Phones are normally the better choice for consumption. Omedora reflects that: it removes consumption-oriented defaults and keeps the tools you need to build, write, and think.

I chose Fedora over Arch for everyday work and productivity. Fedora stays current while providing a predictable release cycle, solid testing, and a clear upgrade path. For a business owner and software developer, that stability matters more than bleeding-edge packages.

This is an opinionated baseline. It reflects my own context, but the modules are small and composable. I hope an ecosystem of recipes can grow on top of it for different use cases.

## Quick start

```bash
git clone https://github.com/tedmartin/.dotfiles ~/.dotfiles
cd ~/.dotfiles
./setup/bin/setup --help          # see all commands
./setup/bin/setup balanced        # or strict / minimal
./setup/bin/setup audit           # verify the result
```

> Do not run the setup as root — it calls `sudo` itself and applies per-user settings.

Run without arguments for an interactive menu.

## Setup profiles

Profiles are the easiest way to run everything with a coherent posture.

| Profile  | Posture                                                                 |
|----------|-------------------------------------------------------------------------|
| `strict` | IPv6 off, aggressive hosts blocklist, all extras                        |
| `balanced` | Full hosts blocklist, curated apps, extras                              |
| `minimal` | Basic hardening only, small blocklist, no curated apps or extras        |

```bash
./setup/bin/setup strict
./setup/bin/setup balanced
./setup/bin/setup minimal
```

You can also set profile knobs yourself before running `all`:

```bash
SETUP_DISABLE_IPV6=1 \
SETUP_INSTALL_CURATED_APPS=1 \
SETUP_INSTALL_EXTRAS=1 \
SETUP_HOSTS_CATEGORIES="ads trackers social porn" \
  ./setup/bin/setup all
```

## Module reference

### System & UX

- `settings` — dark mode, battery percentage, traditional scroll, Nautilus list view, Papirus icon theme.
- `gnome-keyboard` — Super+number workspaces, Alt window management, fast key repeat (150 ms delay / 18 ms interval), animations off.
- `gnome` — camera/mic/recent-files/location off, screen lock, suspend timeouts, masks GNOME Online Accounts and Evolution.
- `terminal` — Ptyxis Dracula palette and 0xProto Nerd Font Mono.

### Hardening

- `network` — firewalld public zone, random MAC, IPv6 privacy extensions, no connectivity check.
- `harden` — sysctl knobs, disable services, authenticated time sync (chrony + NTS), dnf-automatic (security updates downloaded **and applied**, no auto-reboot), sudo timeout 5 min, SELinux check.
- `fingerprint` — *opt-in.* Enroll a fingerprint and enable fingerprint unlock (fprintd via authselect). Additive — your password still works everywhere.
- `fido2` — *opt-in.* Register a FIDO2/U2F security key and enable key-based auth (pam-u2f via authselect). 1FA by default (key **or** password); set `SETUP_FIDO2_2FA=1` for 2FA (key **and** password). Never enabled without a registered key.
- `telemetry` — disable ABRT, fwupd reporting, coredump, PackageKit offline updates.
- `bloat` — remove Fedora defaults (Boxes, parental controls, tour, connections, mediawriter, LibreOffice, GNOME Software, Flatpak, etc.).
- `ipv6-disable` / `ipv6-enable` — disable or re-enable IPv6 via sysctl and GRUB.

### Browser & DNS

- `firefox` — install Firefox, set default browser, apply managed policies (uBlock Origin force-installed), telemetry/Firefox accounts/Pocket off, HTTPS-only on, third-party cookies blocked, DoH off (system DoT used instead). Cookies, history, and your session are kept across restarts and the previous session is restored; WebRTC and WebGL are disabled (see "What breaks").
- `libredns` — configure LibreDNS ad-blocking over TLS via systemd-resolved.
- `hosts` — build and apply `/etc/hosts` blocklist from categories.
  - `hosts list`
  - `hosts enable|disable|toggle <category>`

### Apps & dev

- `thunderbird` — install Thunderbird and apply managed policies for minimal, private, secure email.
- `curated-apps` — ripgrep, fzf, fd, fastfetch, mpv, Zathura.
- `extras` — fstrim.timer, `countme=false` in dnf, USBGuard, TLP.
- `opencode`, `mise`, `node`, `pnpm`, `docker`.

### Audit & rollback

- `audit` — final privacy/security checklist.
- `rollback hosts|dns|firefox|all` — restore `/etc/hosts`, DNS, or Firefox policies.

## What breaks / known side effects

- **Firefox only.** Firefox is the bundled browser with hardened policies.
- **No Flatpak.** Removed entirely. Install apps via dnf.
- **No GNOME Software.** Updates are CLI/dnf-automatic only. `dnf-automatic` downloads and applies **security** updates automatically (no auto-reboot); run `sudo dnf upgrade` + reboot for everything else.
- **WebRTC and WebGL are disabled in Firefox.** Video/voice calls (Meet, Jitsi, Discord web) and WebGL apps (maps, 3D) will not work until you re-enable them. To allow calls, set `media.peerconnection.enabled` to `true` (and `webgl.disabled` to `false`) in `setup/lib/firefox.sh` and re-run `setup firefox`, or unlock them in `about:config` after removing the locked policy.
- **DNS is strict DoT.** Resolution uses LibreDNS over TLS with Quad9 (also over TLS) as fallback. Captive portals that intercept DNS may need you to temporarily relax DNS; networks blocking port 853 fail over to Quad9.
- **SSH off.** `sshd` is disabled on desktops.
- **CUPS off.** Printing services are disabled; re-enable if you need a printer.
- **USBGuard.** After `extras`, new USB devices are blocked until added to `/etc/usbguard/rules.conf`.
- **IPv6 disable** may break IPv6-only networks or some VPNs. Reboot required for GRUB change.
- **Docker group** grants effective root. Consider rootless Docker if that matters for your threat model.
- **/etc/hosts blocklist** can block sites you want. Use `setup hosts disable social` or edit `~/.config/hosts-blocklist/whitelist.txt`.

## Revert / rollback

Most changes are reversible from the CLI:

```bash
./setup/bin/setup rollback hosts        # restore /etc/hosts
./setup/bin/setup rollback dns          # remove LibreDNS drop-in
./setup/bin/setup rollback firefox      # remove managed policies
./setup/bin/setup rollback fingerprint  # disable fingerprint PAM feature
./setup/bin/setup rollback fido2        # disable FIDO2/U2F PAM feature
./setup/bin/setup rollback all          # hosts + dns + firefox + thunderbird (not auth)
```

Manual reverts for items not covered by rollback helpers:

- **Sysctl:** remove `/etc/sysctl.d/99-hardening.conf` and `/etc/sysctl.d/99-disable-ipv6.conf`, then `sudo sysctl --system`.
- **Sudo timeout:** remove `/etc/sudoers.d/timeout`.
- **NetworkManager privacy:** remove `/etc/NetworkManager/conf.d/privacy.conf` and restart NetworkManager.
- **firewalld:** `sudo firewall-cmd --set-default-zone=public` and re-add services you need.
- **IPv6 GRUB param:** `sudo grubby --update-kernel=ALL --remove-args="ipv6.disable=1"`.
- **Services re-enabled:** `sudo systemctl enable --now sshd cups` etc. (time sync is left on by default).
- **Time-sync / NTS:** remove `/etc/chrony/conf.d/20-nts.conf` to drop the NTS sources, or `sudo systemctl disable --now chronyd` to turn off time sync entirely.
- **GNOME settings:** review `Settings > Privacy & Security` and `Settings > Keyboard`.

## File layout

```text
.dotfiles/
├── setup/
│   ├── bin/setup          # entry point
│   └── lib/               # modules (one per concern)
├── hosts-blocklist/       # /etc/hosts category files (used by `setup hosts`)
├── opencode/              # opencode config (stowed by `setup opencode`)
├── tmux/                  # tmux config (stow tmux)
└── README.md
```

## Development notes

- All setup modules are `shellcheck` clean.
- Each module sources `common.sh` so it can also be run standalone for testing.
- Use `setup audit` after major changes to verify state.
