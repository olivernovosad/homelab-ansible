# 🚀 Gaia Homelab - Infrastructure as Code (Ansible)

Tento repozitár obsahuje kompletnú **Ansible** konfiguráciu pre automatizovanú správu, nasadenie a údržbu domáceho servera **Gaia** (`gaia-server`). Server beží na **Ubuntu Server** s využitím Docker kontajnerov pre izoláciu služieb.

---

## 🛠️ Hardvérová & Architektúrna špecifikácia

Server využíva trojúrovňové úložisko prispôsobené pre výkon, kapacitu a bezpečnosť dát:

| Disk / Zariadenie | Typ úložiska | Pripojenie (Mount point) | Účel |
| :--- | :--- | :--- | :--- |
| **NVMe (`nvme0n1`)** | Základný systém | `/` (Ubuntu LVM ~389 GB) | Operačný systém, Docker engine, rýchle systémové operácie. |
| **SATA SSD (`sda1`)** | Fast Storage | `/mnt/ssd` (~889 GB free) | Vysokorýchlostné dátové úložisko pre **Nextcloud AIO** (`/mnt/ssd/nextcloud-data`). |
| **8TB HDD (`sdb1`)** | Mass Storage | `/mnt/hdd8T` (~2.7 TB free) | Objemné dáta: knižnica médií (`/data`), torrenty a zálohy Kopia (`/backups`). |

---

## 🧩 Štruktúra Docker Sietí & Bezpečnosť

Aplikácie sú rozdelené do izolovaných Docker sietí na základe ich funkcie a bezpečnostného profilu:

                  ┌─────────────────────────────────────────┐
                  │          Internet / Cloudflare          │
                  └────────────────────┬────────────────────┘
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
      [ Cloudflared ]                                          [ NPM ]
     (Tunnel - tunnel_net)                                 (Proxy - proxy_net)
             │                                                    │
    ┌────────┴────────┬──────────────┐                    ┌───────┴────────┐
    ▼                 ▼              ▼                    ▼                ▼
    [Vaultwarden]  [Foundry VTT]   [DDB-Proxy]         [Nextcloud]      [Jellyfin]
                                                          │                │
                                                          └───────┬────────┘
                                                                  ▼
                                                             [media_net]
                                                                  │
                                                          ┌───────┴────────┐
                                                          ▼                ▼
                                                    [*arr Stack]      [Prowlarr]
                                                                           │
                                                                           ▼
                                                                     [torrent_net]
                                                                           │
                                                                           ▼
                                                                     [Gluetun VPN]
                                                                           │
                                                                           ▼
                                                                     [qBittorrent]

proxy_net: Smerovanie verejných služieb cez Nginx Proxy Manager.

tunnel_net: Bezpečné publikovanie interných služieb prostredníctvom Cloudflare Tunnela.

media_net: Interná komunikácia medzi media serverom (Jellyfin), požiadavkami (Jellyseerr) a správa médií (*arr aplikácie).

torrent_net: Izolovaná sieť pre sťahovanie. Všetok prevádzkový tok qBittorrent je povinne smerovaný cez Gluetun (Mullvad WireGuard VPN).

monitoring: Zber metrík prostredníctvom Prometheus, cAdvisor a Node Exporter.

📂 Prehľad Rölí a Služieb
1. connection (Smerovanie & Repery)
Nginx Proxy Manager (npm): Reverse proxy pre lokálny a verejný prístup (Porty 80, 443, 81).

Cloudflare Tunnel (cloudflared): Zabezpečené prepojenie služieb bez nutnosti otvárania portov na routeri.

2. vaultwarden (Správca hesiel)
Vaultwarden: Ľahká implementácia Bitwarden servera napojená na tunnel_net.

3. nextcloud (Osobné cloudové úložisko)
Nextcloud AIO Mastercontainer: Správa kompletného Nextcloud ekosystému. Dátový adresár umiestnený na rýchlom SSD (/mnt/ssd/nextcloud-data).

4. media (Multimediálny Stack & VPN)
Gluetun: WireGuard VPN klient (Mullvad) s automatickou kontrolou úniku verejnej IP.

qBittorrent: Sťahovací klient plne izolovaný v sieti gluetun kontajnera.

Prowlarr & FlareSolverr: Správa indexerov a obchádzanie Cloudflare ochrán.

Media Managers: Radarr (Filmy), Sonarr (Seriály), Lidarr (Hudba), Mylar3 (Komiksy), Bazarr (Titulky).

Jellyfin: Multimediálny prehrávač s hardvérovou akceleráciou transkódovania (Intel QuickSync passthrough /dev/dri).

Jellyseerr & Notifiarr: Správa používateľských požiadaviek a integrácia notifikácií.

5. monitoring (Dohľad & Metriky)
Prometheus: Zber a ukladanie časových radov metrík.

Grafana: Vizualizačné nástenky (Port 3333).

Node Exporter & cAdvisor: Zber metrík zo samotného Linux hostiteľa a Docker kontajnerov.

6. foundry (Virtuálny stolový systém)
Foundry VTT (v13): Server pre D&D / TTRPG hry.

Autoheal: Automatický reštart zamrznutých kontajnerov podľa healthchecku.

D&D Beyond Proxy (ddb-proxy): Pomocná služba pre integráciu podkladov.

7. system (Údržba & Bezpečnosť)
CrowdSec: Detekcia a blokovanie škodlivých požiadaviek z logov.

Watchtower: Automatická aktualizácia Docker obrazov.

Kopia Backup Server: Šifrované zálohovanie aplikačných dát a konfigurácií na 8TB HDD (/mnt/hdd8T/backups/kopia).

Unattended-Upgrades: Automatické bezpečnostné aktualizácie Ubuntu systému s nastaveným reštartom o 04:00.

## 🌲 Štruktúra Repozitára

```text
.
├── ansible.cfg                 # Globálna konfigurácia Ansible
├── hosts.ini                   # Inventár serverov
├── site.yml                    # Hlavný Ansible playbook
├── group_vars/
│   ├── all/
│   │   └── vars.yml            # Globálne premenné (cesty, časové pásmo)
│   └── homelab.yml             # Zašifrované tajné údaje (Ansible Vault)
└── roles/
    ├── connection/             # NPM & Cloudflared
    ├── foundry/                # Foundry VTT & DDB Proxy
    ├── media/                  # Jellyfin & *arr Stack & Gluetun VPN
    ├── monitoring/             # Grafana & Prometheus
    ├── nextcloud/              # Nextcloud AIO
    ├── system/                 # CrowdSec, Watchtower, Kopia, OS Updates
    └── vaultwarden/            # Vaultwarden
```


🚀 Spustenie a Nasadenie
Požiadavky:
Nainštalovaný Ansible na riadiacom počítači.

Nainštalovaná kolekcia pre Docker:
```text
ansible-galaxy collection install community.docker
```
Spustenie Playbooku:
Pre kompletné nasadenie alebo aktualizáciu celej infraštruktúry spusti:
```text
ansible-playbook -i hosts.ini site.yml --ask-vault-pass
```
Spustenie konkrétnej úlohy/role (napr. iba media stack):
```text
ansible-playbook -i hosts.ini site.yml --tags media --ask-vault-pass
```
