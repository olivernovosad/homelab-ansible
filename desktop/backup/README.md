# Desktop-side backup pull

Pulls a read-only mirror of the Kopia repository from `gaia-server` via
SFTP. Not rsync — the server-side `kopia-offsite` account is locked to
`ForceCommand internal-sftp` (no shell, no arbitrary commands), and rsync's
protocol has nothing to talk to there.

## One-time setup

1. Generate a dedicated key (unchanged from before):
   `ssh-keygen -t ed25519 -f ~/.ssh/kopia-pull -N ""`
2. Add the public key as `desktop_ssh_pubkey` in
   `ansible/group_vars/all/vars.yml` and run the `backup` role against the
   homelab host.
3. Install rclone: `sudo dnf install rclone` (Fedora) — no `rclone.conf`
   needed. This setup uses an inline SFTP remote; credentials never leave
   this script and the SSH key file.
4. Trust the server's host key once, so rclone doesn't need an insecure
   skip-verify flag:
   `ssh-keyscan -H <gaia-server-ip> >> ~/.ssh/known_hosts`
   (or just connect once manually with
   `sftp -i ~/.ssh/kopia-pull kopia-offsite@<gaia-server-ip>` and accept the
   prompt — either way populates `~/.ssh/known_hosts`)
5. Copy `kopia-pull.sh` and `kopia-sync-external.sh` to `$HOME`, `chmod +x` both.
6. Copy `systemd/*.service` and `systemd/*.timer` to `~/.config/systemd/user/`.
7. `systemctl --user daemon-reload && systemctl --user enable --now kopia-pull.timer`
8. `sudo loginctl enable-linger $USER` so the timer runs even when logged out.

## Why rclone instead of Kopia's native `sync-to`

Kopia ships its own `kopia repository sync-to sftp` command, built exactly
for this kind of replication. It's deliberately not used here: connecting
to a repository — even just to copy its opaque blobs — requires the Kopia
master password on whichever machine runs the command. This desktop is a
personal, not-always-on machine; putting the repository password on it
would mean a compromised desktop exposes the ability to decrypt every
backup, not just steal an encrypted copy of one.

rclone's SFTP backend only ever moves already-encrypted blob bytes — same
data the old rsync setup moved — but over a protocol the chrooted
`internal-sftp` account actually supports, and without ever needing the
master password on this machine. The SSH key it uses is scoped to
read-only SFTP access only (see `ansible/roles/backup/tasks/main.yml`).

If the destination were ever a second hardened, IT-managed server instead
of a personal desktop, `kopia repository sync-to` would be the better
choice there — it understands Kopia's manifest structure and can prune
orphaned blobs on the destination. The tooling choice follows the trust
level of the machine it runs on, not a fixed "best tool" rule.
