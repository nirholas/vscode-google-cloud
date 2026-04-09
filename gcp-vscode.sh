#!/bin/bash
set -e

# ============================================
# GCP VS Code (code-server) Setup Script
# ============================================
# Spin up unlimited VS Code instances in your browser
# using Google Cloud Compute Engine + code-server
#
# Usage:
#   ./gcp-vscode.sh setup                   # First-time setup
#   ./gcp-vscode.sh create [name] [zone]    # Create a VS Code VM
#   ./gcp-vscode.sh list                    # List all VMs
#   ./gcp-vscode.sh url [name] [zone]       # Get browser URL
#   ./gcp-vscode.sh ssh [name] [zone]       # SSH into VM
#   ./gcp-vscode.sh stop [name] [zone]      # Stop VM (save money)
#   ./gcp-vscode.sh start [name] [zone]     # Start stopped VM
#   ./gcp-vscode.sh delete [name] [zone]    # Delete VM
#   ./gcp-vscode.sh password [name] [zone]  # Get code-server password
# ============================================

# ---- Configuration (edit these) ----
PROJECT_ID="${GCP_PROJECT_ID:-}"
DEFAULT_ZONE="${GCP_ZONE:-us-central1-a}"
MACHINE_TYPE="${GCP_MACHINE_TYPE:-e2-standard-4}"
DISK_SIZE="${GCP_DISK_SIZE:-50}"  # GB
IMAGE_FAMILY="ubuntu-2404-lts-amd64"
IMAGE_PROJECT="ubuntu-os-cloud"
# ------------------------------------

# Add gcloud to PATH if installed locally
export PATH="$HOME/google-cloud-sdk/bin:$PATH"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}✅ $1${NC}"; }
info()  { echo -e "${BLUE}ℹ️  $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ---- Startup script that runs on each new VM ----
read -r -d '' STARTUP_SCRIPT << 'STARTUP_EOF' || true
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Update and install essentials
apt-get update -y
apt-get install -y curl git build-essential python3 python3-pip unzip wget \
  apt-transport-https ca-certificates gnupg lsb-release jq

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Bun
curl -fsSL https://bun.sh/install | bash
ln -sf /root/.bun/bin/bun /usr/local/bin/bun

# Install Docker
curl -fsSL https://get.docker.com | bash
systemctl enable docker
systemctl start docker

# Install code-server (VS Code in browser)
curl -fsSL https://code-server.dev/install.sh | sh

# Configure code-server with random password
mkdir -p /root/.config/code-server
RANDOM_PASS=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 20)
cat > /root/.config/code-server/config.yaml << CSEOF
bind-addr: 0.0.0.0:8080
auth: password
password: $RANDOM_PASS
cert: false
CSEOF
echo "CODE_SERVER_PASSWORD=$RANDOM_PASS" > /root/.code-server-credentials

# Install common VS Code extensions
code-server --install-extension ms-python.python 2>/dev/null || true
code-server --install-extension esbenp.prettier-vscode 2>/dev/null || true
code-server --install-extension dbaeumer.vscode-eslint 2>/dev/null || true

# Create workspace directory
mkdir -p /root/workspace

# Enable and start code-server
systemctl enable --now code-server@root

echo "=== code-server setup complete ==="
STARTUP_EOF

# ---- Helper Functions ----

check_gcloud() {
  if ! command -v gcloud &>/dev/null; then
    error "gcloud CLI not found. Run: $0 setup"
  fi
}

check_project() {
  if [[ -z "$PROJECT_ID" ]]; then
    error "No project set. Either:\n  1. Set GCP_PROJECT_ID env var: export GCP_PROJECT_ID=your-project-id\n  2. Edit PROJECT_ID in this script\n  3. Run: $0 setup"
  fi
}

get_cost_estimate() {
  case "$MACHINE_TYPE" in
    e2-standard-2)  echo "~\$0.07/hr (\$1.61/day)" ;;
    e2-standard-4)  echo "~\$0.13/hr (\$3.17/day)" ;;
    e2-standard-8)  echo "~\$0.27/hr (\$6.34/day)" ;;
    e2-standard-16) echo "~\$0.54/hr (\$12.96/day)" ;;
    n2-standard-4)  echo "~\$0.19/hr (\$4.68/day)" ;;
    n2-standard-8)  echo "~\$0.39/hr (\$9.36/day)" ;;
    *)               echo "see https://cloud.google.com/compute/pricing" ;;
  esac
}

# ---- Commands ----

cmd_setup() {
  echo ""
  echo "🚀 GCP VS Code Setup"
  echo "===================="
  echo ""

  # Step 1: Install gcloud
  if command -v gcloud &>/dev/null; then
    log "gcloud already installed: $(gcloud --version 2>&1 | head -1)"
  else
    info "Installing Google Cloud SDK..."
    curl -sSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz \
      | tar -xz -C "$HOME"
    "$HOME/google-cloud-sdk/install.sh" --quiet --path-update true
    export PATH="$HOME/google-cloud-sdk/bin:$PATH"
    log "gcloud installed"
    warn "Run 'source ~/.bashrc' after setup completes to update your PATH"
  fi

  # Step 2: Authenticate
  echo ""
  info "Authenticating with Google Cloud..."
  gcloud auth login --no-launch-browser

  # Step 3: Set project
  echo ""
  if [[ -z "$PROJECT_ID" ]]; then
    echo "Your available projects:"
    gcloud projects list --format="table(projectId,name)"
    echo ""
    read -rp "Enter your GCP Project ID: " PROJECT_ID
  fi
  gcloud config set project "$PROJECT_ID"

  # Step 4: Enable Compute Engine API
  info "Enabling Compute Engine API..."
  gcloud services enable compute.googleapis.com --project="$PROJECT_ID"

  echo ""
  log "Setup complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Export your project ID (add to ~/.bashrc for persistence):"
  echo "     export GCP_PROJECT_ID=$PROJECT_ID"
  echo ""
  echo "  2. Create your first VM:"
  echo "     $0 create my-vscode-1"
  echo ""
}

cmd_create() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"
  local COST
  COST=$(get_cost_estimate)

  echo ""
  echo "🚀 Creating VS Code VM"
  echo "  Name:    $NAME"
  echo "  Zone:    $ZONE"
  echo "  Machine: $MACHINE_TYPE"
  echo "  Disk:    ${DISK_SIZE}GB SSD"
  echo "  Cost:    $COST"
  echo ""

  gcloud compute instances create "$NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type=pd-ssd \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --tags=code-server \
    --metadata=startup-script="$STARTUP_SCRIPT" \
    --no-service-account \
    --no-scopes

  # Create firewall rule if it doesn't exist
  if ! gcloud compute firewall-rules describe allow-code-server --project="$PROJECT_ID" &>/dev/null; then
    echo ""
    info "Creating firewall rule for port 8080..."
    gcloud compute firewall-rules create allow-code-server \
      --project="$PROJECT_ID" \
      --allow=tcp:8080 \
      --target-tags=code-server \
      --source-ranges=0.0.0.0/0 \
      --description="Allow code-server access on port 8080"
  fi

  echo ""
  log "VM '$NAME' created!"
  echo ""
  echo "⏳ Wait 2-3 minutes for code-server to install, then:"
  echo "  $0 url $NAME $ZONE       # Get the browser URL"
  echo "  $0 password $NAME $ZONE  # Get the password"
  echo ""
}

cmd_url() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  local IP
  IP=$(gcloud compute instances describe "$NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null)

  if [[ -z "$IP" || "$IP" == "None" ]]; then
    error "VM '$NAME' has no external IP. Is it running? Check: $0 list"
  fi

  echo ""
  echo "🌐 VS Code URL: http://$IP:8080"
  echo ""
  echo "Get the password: $0 password $NAME $ZONE"
  echo ""
}

cmd_password() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  echo ""
  info "Fetching password from $NAME..."
  local PASS
  PASS=$(gcloud compute ssh "$NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --command="cat /root/.code-server-credentials 2>/dev/null || echo 'NOT_READY'" \
    -- -o StrictHostKeyChecking=no 2>/dev/null)

  if [[ "$PASS" == *"NOT_READY"* ]]; then
    warn "code-server is still installing. Wait a minute and try again."
  else
    echo "🔑 $PASS"
  fi
  echo ""
}

cmd_ssh() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  gcloud compute ssh "$NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE"
}

cmd_list() {
  check_gcloud
  check_project

  echo ""
  echo "📋 Your VS Code VMs:"
  echo ""
  gcloud compute instances list \
    --project="$PROJECT_ID" \
    --filter="tags.items=code-server" \
    --format="table(name,zone.basename(),machineType.basename(),status,networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"
  echo ""
}

cmd_stop() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  info "Stopping VM: $NAME (no compute charges while stopped)"
  gcloud compute instances stop "$NAME" --project="$PROJECT_ID" --zone="$ZONE"
  log "Stopped. Resume with: $0 start $NAME $ZONE"
}

cmd_start() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  info "Starting VM: $NAME"
  gcloud compute instances start "$NAME" --project="$PROJECT_ID" --zone="$ZONE"
  log "Started. Get URL: $0 url $NAME $ZONE"
}

cmd_delete() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local ZONE="${2:-$DEFAULT_ZONE}"

  warn "This will permanently delete VM '$NAME' and all its data."
  read -rp "Are you sure? (y/N): " CONFIRM
  if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    gcloud compute instances delete "$NAME" \
      --project="$PROJECT_ID" \
      --zone="$ZONE" \
      --quiet
    log "Deleted VM: $NAME"
  else
    info "Cancelled."
  fi
}

cmd_resize() {
  check_gcloud
  check_project

  local NAME="${1:-vscode-dev-1}"
  local NEW_TYPE="${2:-e2-standard-8}"
  local ZONE="${3:-$DEFAULT_ZONE}"

  info "Stopping VM for resize..."
  gcloud compute instances stop "$NAME" --project="$PROJECT_ID" --zone="$ZONE"

  info "Resizing to $NEW_TYPE..."
  gcloud compute instances set-machine-type "$NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type="$NEW_TYPE"

  info "Starting VM..."
  gcloud compute instances start "$NAME" --project="$PROJECT_ID" --zone="$ZONE"

  log "Resized $NAME to $NEW_TYPE"
}

# ---- Main ----
case "${1:-help}" in
  setup)    cmd_setup ;;
  create)   cmd_create "$2" "$3" ;;
  list)     cmd_list ;;
  url)      cmd_url "$2" "$3" ;;
  password) cmd_password "$2" "$3" ;;
  ssh)      cmd_ssh "$2" "$3" ;;
  stop)     cmd_stop "$2" "$3" ;;
  start)    cmd_start "$2" "$3" ;;
  delete)   cmd_delete "$2" "$3" ;;
  resize)   cmd_resize "$2" "$3" "$4" ;;
  *)
    echo ""
    echo "☁️  GCP VS Code — Unlimited VS Code instances in your browser"
    echo ""
    echo "Usage: $0 <command> [args]"
    echo ""
    echo "Setup:"
    echo "  setup                        Install gcloud, authenticate, configure project"
    echo ""
    echo "VM Management:"
    echo "  create [name] [zone]         Create a new VS Code VM"
    echo "  list                         List all VS Code VMs"
    echo "  url [name] [zone]            Get the browser URL for a VM"
    echo "  password [name] [zone]       Get the code-server password"
    echo "  ssh [name] [zone]            SSH into a VM"
    echo "  stop [name] [zone]           Stop a VM (saves money)"
    echo "  start [name] [zone]          Start a stopped VM"
    echo "  resize [name] [type] [zone]  Resize a VM (e.g., e2-standard-8)"
    echo "  delete [name] [zone]         Delete a VM permanently"
    echo ""
    echo "Environment Variables:"
    echo "  GCP_PROJECT_ID     Your Google Cloud project ID (required)"
    echo "  GCP_ZONE           Default zone (default: us-central1-a)"
    echo "  GCP_MACHINE_TYPE   VM size (default: e2-standard-4)"
    echo "  GCP_DISK_SIZE      Disk size in GB (default: 50)"
    echo ""
    echo "Quick Start:"
    echo "  1. $0 setup"
    echo "  2. export GCP_PROJECT_ID=your-project-id"
    echo "  3. $0 create my-vscode-1"
    echo "  4. $0 url my-vscode-1"
    echo "  5. $0 password my-vscode-1"
    echo "  6. Open the URL in your browser and enter the password"
    echo ""
    ;;
esac
