---
name: gcp-code-server
description: Create, list, start, stop, resize and delete browser-based VS Code (code-server) VMs on Google Compute Engine using gcp-vscode.sh. Use when the user wants a cloud dev environment without Codespaces limits.
---

# gcp-code-server

`gcp-vscode.sh` in `nirholas/vscode-google-cloud` wraps `gcloud compute` to run code-server (VS Code in the browser) on Ubuntu 24.04 VMs. Each VM gets Node.js 20, Bun, Docker, Python 3 and a random code-server password.

## Get the script

```bash
git clone https://github.com/nirholas/vscode-google-cloud.git
cd vscode-google-cloud
chmod +x gcp-vscode.sh
```

Read the script before running it; it installs software and creates billable cloud resources.

## Commands

All commands use the active gcloud account. `[zone]` defaults to `GCP_ZONE`.

| Command | What it does |
|---|---|
| `./gcp-vscode.sh setup` | Installs the gcloud CLI if missing, runs `gcloud auth login --no-launch-browser`, sets the project and enables the Compute Engine API. Interactive. |
| `./gcp-vscode.sh create [name] [zone]` | Creates a VM (default name `vscode-dev-1`), tagged `code-server`, and creates the `allow-code-server` firewall rule for tcp:8080 if it does not exist. |
| `./gcp-vscode.sh list` | Lists VMs tagged `code-server`. |
| `./gcp-vscode.sh url [name] [zone]` | Prints `http://<external-ip>:8080`. |
| `./gcp-vscode.sh password [name] [zone]` | Reads the code-server password over `gcloud compute ssh`. Prints a "still installing" notice for the first minutes. |
| `./gcp-vscode.sh ssh [name] [zone]` | Opens an SSH session. |
| `./gcp-vscode.sh stop [name] [zone]` | Stops the VM (no compute charge while stopped). |
| `./gcp-vscode.sh start [name] [zone]` | Starts a stopped VM. |
| `./gcp-vscode.sh resize [name] [type] [zone]` | Stops, changes machine type (default `e2-standard-8`), starts. |
| `./gcp-vscode.sh delete [name] [zone]` | Permanently deletes the VM after a y/N prompt. |

## Environment variables

- `GCP_PROJECT_ID`: required for every command except `setup`.
- `GCP_ZONE`: default zone, `us-central1-a`.
- `GCP_MACHINE_TYPE`: default `e2-standard-4` (about $0.13 per hour per the script's own estimate table).
- `GCP_DISK_SIZE`: boot disk in GB, default 50 (pd-ssd).

## Workflow

1. `./gcp-vscode.sh setup`, then `export GCP_PROJECT_ID=<project>`.
2. Tell the user the machine type, zone, disk and estimated hourly cost, and get their go-ahead before `create` or `resize`. Both bill their Google Cloud project.
3. `./gcp-vscode.sh create my-vscode-1`, wait 2 to 3 minutes for the startup script to finish.
4. `./gcp-vscode.sh url my-vscode-1` and `./gcp-vscode.sh password my-vscode-1`. Give the user the URL and let them read the password; do not paste it elsewhere.
5. When the session is done, `stop` to pause billing or `delete` to remove the VM. Confirm with the user before `delete`: it destroys the VM and its disk.

## Security notes

The script serves code-server over plain HTTP on port 8080 and the firewall rule allows `0.0.0.0/0`, protected only by the generated password. For anything sensitive, tell the user to narrow the rule, for example:

```bash
gcloud compute firewall-rules update allow-code-server --source-ranges=<their-ip>/32 --project=$GCP_PROJECT_ID
```

or to reach the VM through an SSH tunnel instead. The VM is created with `--no-service-account --no-scopes`, so it has no Google Cloud credentials of its own.
