# S3 / MinIO Object Storage (WIP)

Self-hosted S3-compatible storage for backups: game saves (e.g. Palworld), Proxmox, or any file backup. This guide covers MinIO and rclone so you can push backups from your game server or host to a bucket without relying on a specific cloud vendor.

## Overview

- **MinIO**: S3-compatible object storage you run yourself (Docker, VM, or bare metal).
- **rclone**: CLI tool to copy files to/from S3, MinIO, GCS, and many other remotes.
- **Use cases**: Palworld (and other game) save backups, Proxmox Backup Server (PBS) backing store, general file archives.

## Prerequisites

- Docker (or a VM) to run MinIO, or a hosted S3-compatible endpoint.
- Storage for the bucket (local disk, NFS, or network volume).
- On the client (game server or backup host): `rclone` installed and configured.

## Install MinIO (placeholder)

*(Content to be added: Docker run example, minimal compose, or native install.)*

- Run MinIO server (single node or distributed).
- Expose API port (e.g. 9000) and optional console (9001).
- Use HTTPS in production; PBS and some clients require TLS.

## Create a bucket (placeholder)

*(Content to be added: mc alias, mc mb, or web console steps.)*

- Create a bucket (e.g. `palworld-backups` or `pbs-backups`).
- Set lifecycle or retention if desired.

## Configure rclone (placeholder)

*(Content to be added: rclone config for S3/MinIO endpoint, access key, secret key.)*

- Run `rclone config`, choose S3, set endpoint (e.g. `http://minio:9000` or your MinIO URL).
- Name the remote (e.g. `minio`). Use it as `minio:bucketname` in commands.

## Use with palworld-save-export.sh

The script [palworld-save-export.sh](../scripts/local-game-servers/palworld-save-export.sh) creates a local zip of the Palworld world save and optionally uploads it via rclone.

1. Install and configure rclone with an S3/MinIO remote (e.g. `minio`).
2. Set the environment variable to the remote and path:
   ```bash
   export PALWORLD_BACKUP_REMOTE=minio:palworld-backups
   ```
3. Run the export script on the game server (with sudo, as documented in the script):
   ```bash
   sudo PALWORLD_BACKUP_REMOTE=minio:palworld-backups ./palworld-save-export.sh
   ```
4. Backups are also written locally; see the script and [scripts/local-game-servers/README.md](../scripts/local-game-servers/README.md) for paths and options.

## Proxmox / PBS integration (future)

*(Placeholder: Proxmox Backup Server with S3 backing store or sync to MinIO; PBS requires HTTPS on the S3 endpoint.)*

- PBS can use S3-compatible storage as a backing store (with appropriate setup and TLS).
- Alternative: use `vzdump` plus rclone to copy backup files to MinIO after creation.

## See also

- [Local game servers (Palworld, Satisfactory)](../scripts/local-game-servers/README.md) — World save management, SCP/SFTP, import/export scripts.
- [AGENTS.md](../AGENTS.md) — For security review of scripts before use.
