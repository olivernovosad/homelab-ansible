# Desktop-side backup pull

Manual one-time setup on the desktop machine:

1. Generate a dedicated key: `ssh-keygen -t ed25519 -f ~/.ssh/kopia-pull -N ""`
2. Add the public key as `desktop_ssh_pubkey` in `ansible/group_vars/all/vars.yml`
   and run the `system` role against the homelab host.
3. Copy `kopia-pull.sh` and `kopia-sync-external.sh` to `$HOME`, `chmod +x` both.
4. Copy `systemd/*.service` and `systemd/*.timer` to `~/.config/systemd/user/`.
5. `systemctl --user daemon-reload && systemctl --user enable --now kopia-pull.timer`
6. `sudo loginctl enable-linger $USER` so the timer runs even when logged out.
