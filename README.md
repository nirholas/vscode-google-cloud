# ☁️ GCP VS Code

**Run unlimited VS Code instances in your browser using Google Cloud.**

GitHub Codespaces limits you to 2 concurrent instances. With Google Cloud, you can run as many as you want — each one a full VS Code environment with its own terminal, filesystem, Docker, and dev tools.

![VS Code in Browser](https://raw.githubusercontent.com/coder/code-server/main/docs/assets/screenshot.png)

## Why?

| | GitHub Codespaces | GCP VS Code |
|---|---|---|
| **Max instances** | 2 (free) / 4 (pro) | **Unlimited** |
| **Max CPU** | 4 cores | **Up to 96 cores** |
| **Max RAM** | 16 GB | **Up to 384 GB** |
| **Storage** | 32 GB | **Up to 64 TB** |
| **Cost** | $0.18/hr (4-core) | **$0.13/hr (4-core)** |
| **Customization** | Limited | **Full root access** |
| **Docker** | Limited | **Full Docker support** |

## Quick Start

```bash
# Clone this repo
git clone https://github.com/YOUR_USERNAME/gcp-vscode.git
cd gcp-vscode

# Make executable
chmod +x gcp-vscode.sh

# One-time setup (installs gcloud CLI, authenticates you)
./gcp-vscode.sh setup

# Set your project ID
export GCP_PROJECT_ID=your-project-id

# Create your first VS Code instance
./gcp-vscode.sh create my-vscode-1

# Wait ~2 min, then get the URL and password
./gcp-vscode.sh url my-vscode-1
./gcp-vscode.sh password my-vscode-1

# Open the URL in your browser, enter the password — done!
```

## What You Get

Each VM comes pre-installed with:

- **VS Code** in your browser (via [code-server](https://github.com/coder/code-server))
- **Node.js 20** + npm
- **Bun** runtime
- **Docker** + Docker Compose
- **Python 3** + pip
- **Git**, curl, wget, jq, build-essential
- **100% root access** — install anything you want

## Commands

| Command | Description |
|---------|-------------|
| `./gcp-vscode.sh setup` | One-time: install gcloud, authenticate, set project |
| `./gcp-vscode.sh create [name] [zone]` | Create a new VS Code VM |
| `./gcp-vscode.sh list` | List all your VS Code VMs |
| `./gcp-vscode.sh url [name] [zone]` | Get the browser URL |
| `./gcp-vscode.sh password [name] [zone]` | Get the login password |
| `./gcp-vscode.sh ssh [name] [zone]` | SSH directly into a VM |
| `./gcp-vscode.sh stop [name] [zone]` | Stop a VM (saves money) |
| `./gcp-vscode.sh start [name] [zone]` | Start a stopped VM |
| `./gcp-vscode.sh resize [name] [type] [zone]` | Resize VM (e.g., `e2-standard-8`) |
| `./gcp-vscode.sh delete [name] [zone]` | Delete a VM permanently |

**Defaults:** name=`vscode-dev-1`, zone=`us-central1-a`, machine=`e2-standard-4`

## Configuration

Configure via environment variables (add to `~/.bashrc` for persistence):

```bash
export GCP_PROJECT_ID=your-project-id      # Required
export GCP_ZONE=us-central1-a              # Default zone
export GCP_MACHINE_TYPE=e2-standard-4      # VM size
export GCP_DISK_SIZE=50                    # Disk in GB
```

## Machine Types & Pricing

| Machine Type | vCPU | RAM | $/hour | $/day (24/7) | $/month |
|-------------|------|-----|--------|-------------|---------|
| `e2-standard-2` | 2 | 8 GB | $0.07 | $1.61 | $48 |
| `e2-standard-4` | 4 | 16 GB | $0.13 | $3.17 | $95 |
| `e2-standard-8` | 8 | 32 GB | $0.27 | $6.34 | $190 |
| `e2-standard-16` | 16 | 64 GB | $0.54 | $12.96 | $389 |
| `n2-standard-4` | 4 | 16 GB | $0.19 | $4.68 | $140 |
| `n2-standard-8` | 8 | 32 GB | $0.39 | $9.36 | $281 |

> **Tip:** Stop VMs when not using them. Stopped VMs only cost ~$0.17/day for disk storage.

To change the size of an existing VM:
```bash
./gcp-vscode.sh resize my-vscode-1 e2-standard-8
```

## Zones

Choose a zone close to you for the best latency:

| Zone | Location |
|------|----------|
| `us-central1-a` | Iowa, USA **(default)** |
| `us-east1-b` | South Carolina, USA |
| `us-west1-a` | Oregon, USA |
| `europe-west1-b` | Belgium |
| `europe-west2-a` | London |
| `asia-east1-a` | Taiwan |
| `asia-northeast1-a` | Tokyo |
| `australia-southeast1-a` | Sydney |

```bash
# Create a VM in London
./gcp-vscode.sh create uk-dev europe-west2-a
```

Full list: `gcloud compute zones list`

## Examples

### Run 5 instances for different projects
```bash
./gcp-vscode.sh create frontend-app
./gcp-vscode.sh create backend-api
./gcp-vscode.sh create ml-training e2-standard-16  # beefier VM
./gcp-vscode.sh create mobile-app
./gcp-vscode.sh create devops-infra

# See all of them
./gcp-vscode.sh list
```

### Daily workflow
```bash
# Morning — start your VMs
./gcp-vscode.sh start frontend-app
./gcp-vscode.sh start backend-api

# Get URLs
./gcp-vscode.sh url frontend-app
./gcp-vscode.sh url backend-api

# Evening — stop to save money
./gcp-vscode.sh stop frontend-app
./gcp-vscode.sh stop backend-api
```

### Clone repos into your VM
Once in VS Code (browser), open the terminal and:
```bash
git clone https://github.com/you/your-repo.git
cd your-repo
npm install  # or bun install, pip install, etc.
```

## Advanced

### Add HTTPS with a custom domain

SSH into the VM and set up Caddy:
```bash
./gcp-vscode.sh ssh my-vscode-1
```

Then on the VM:
```bash
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update && apt-get install caddy

cat > /etc/caddy/Caddyfile << EOF
vscode.yourdomain.com {
    reverse_proxy localhost:8080
}
EOF

systemctl restart caddy
```

Point your DNS A record to the VM's external IP.

### Use a static IP

```bash
# Reserve a static IP in the VM's region
gcloud compute addresses create my-static-ip --region=us-central1

# Get the reserved IP
gcloud compute addresses describe my-static-ip --region=us-central1 --format='get(address)'

# Assign it (VM must be stopped)
./gcp-vscode.sh stop my-vscode-1
gcloud compute instances delete-access-config my-vscode-1 --zone=us-central1-a
gcloud compute instances add-access-config my-vscode-1 --zone=us-central1-a --address=YOUR_STATIC_IP
./gcp-vscode.sh start my-vscode-1
```

### Change the password
```bash
./gcp-vscode.sh ssh my-vscode-1
nano ~/.config/code-server/config.yaml   # edit the password field
systemctl restart code-server@root
```

### Install additional VS Code extensions
Through the browser UI, or via SSH:
```bash
code-server --install-extension github.copilot
code-server --install-extension ms-azuretools.vscode-docker
```

## Prerequisites

- A [Google Cloud account](https://cloud.google.com/) (free tier includes $300 credits)
- A GCP project with billing enabled
- Linux or macOS terminal (or WSL on Windows)

## How It Works

1. The script creates a Google Compute Engine VM with Ubuntu 24.04
2. A startup script automatically installs code-server, Node.js, Bun, Docker, and dev tools
3. A firewall rule opens port 8080 for browser access
4. code-server runs on port 8080 with password authentication
5. You access VS Code at `http://VM_IP:8080`

## Troubleshooting

**"serviceAccount not found" error**  
Your project's default service account was deleted. The script uses `--no-service-account` to avoid this — make sure you have the latest version.

**Can't connect to the URL**  
Wait 2-3 minutes after creation for code-server to install. Check VM status with `./gcp-vscode.sh list`.

**Forgot the password**  
Run `./gcp-vscode.sh password my-vscode-1`

**IP changed after restart**  
Ephemeral IPs change on stop/start. Run `./gcp-vscode.sh url my-vscode-1` for the new IP, or set up a static IP.

**Quota limit reached**  
Request a quota increase at [console.cloud.google.com/iam-admin/quotas](https://console.cloud.google.com/iam-admin/quotas).

## License

All rights reserved. See [LICENSE](LICENSE).

## Contributing

PRs welcome! Ideas for improvements:
- [ ] Terraform/Pulumi config for infrastructure-as-code
- [ ] Preemptible/spot instance support (even cheaper)
- [ ] Auto-stop after idle timeout
- [ ] Multi-user support with individual passwords
- [ ] Tailscale integration for private access
- [ ] Snapshot/restore for VM state
