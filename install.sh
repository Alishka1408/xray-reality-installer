#!/usr/bin/env bash
set -euo pipefail

############################################
# Checks
############################################

if [[ $EUID -ne 0 ]]; then
  echo "❌ Please run as root (sudo -i)"
  exit 1
fi

echo "========================================="
echo " Xray VLESS + Reality installer"
echo "========================================="

############################################
# Variables
############################################

XRAY_DIR="/usr/local/etc/xray"
CONFIG="$XRAY_DIR/config.json"
KEYS="$XRAY_DIR/.keys"

############################################
# Step 1: Update system & install deps
############################################

echo "[1/8] Updating system and installing dependencies..."

apt update && apt upgrade -y
apt install -y curl jq qrencode ufw openssl

############################################
# Step 2: Install Xray
############################################

echo "[2/8] Installing Xray..."

bash -c "$(curl -4 -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

############################################
# Step 3: Generate Reality keys
############################################

echo "[3/8] Generating Reality keys..."

mkdir -p "$XRAY_DIR"
rm -f "$KEYS"
install -m 600 /dev/null "$KEYS"

echo "shortsid: $(openssl rand -hex 8)" >> "$KEYS"
echo "uuid: $(xray uuid)" >> "$KEYS"
/usr/local/bin/xray x25519 >> "$KEYS"

uuid="$(awk -F': ' '/^uuid:/ {print $2}' "$KEYS")"
privatekey="$(awk -F': ' '/^PrivateKey:/ {print $2}' "$KEYS")"
publickey="$(awk -F': ' '/^Password:/ {print $2}' "$KEYS")"
shortsid="$(awk -F': ' '/^shortsid:/ {print $2}' "$KEYS")"

############################################
# Step 4: Create config.json
############################################

echo "[4/8] Writing Xray config..."

cat <<EOF > "$CONFIG"
{
  "log": {
    "loglevel": "info"
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": []
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "tag": "vless_tls",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "email": "main@user",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.github.com:443",
          "xver": 0,
          "serverNames": [
            "www.github.com"
          ],
          "privateKey": "$privatekey",
          "shortIds": [
            "$shortsid"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

############################################
# Step 5: Enable & start Xray
############################################

echo "[5/8] Starting Xray..."

systemctl daemon-reload
systemctl enable xray
systemctl restart xray

############################################
# Step 6: Install helper scripts
############################################

echo "[6/8] Installing helper scripts..."

### newuser
cat <<'EOF' > /usr/local/bin/newuser
#!/bin/bash
set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"
KEYS="/usr/local/etc/xray/.keys"

read -p "Enter username (email): " email

if [[ -z "$email" || "$email" == *" "* ]]; then
  echo "Invalid username"
  exit 1
fi

exists="$(jq --arg email "$email" '.inbounds[0].settings.clients[]? | select(.email==$email)' "$CONFIG")"
if [[ -n "$exists" ]]; then
  echo "User already exists"
  exit 0
fi

uuid="$(xray uuid)"

jq --arg email "$email" --arg uuid "$uuid" \
  '.inbounds[0].settings.clients += [{"email":$email,"id":$uuid,"flow":"xtls-rprx-vision"}]' \
  "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"

systemctl restart xray

/usr/local/bin/sharelink "$email"
EOF
chmod +x /usr/local/bin/newuser

### rmuser
cat <<'EOF' > /usr/local/bin/rmuser
#!/bin/bash
set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"

emails=($(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"))

echo "Clients:"
select email in "${emails[@]}"; do
  [[ -n "$email" ]] || exit 1
  jq --arg email "$email" \
    '(.inbounds[0].settings.clients)|=map(select(.email!=$email))' \
    "$CONFIG" > /tmp/xray.json && mv /tmp/xray.json "$CONFIG"
  systemctl restart xray
  echo "Removed $email"
  break
done
EOF
chmod +x /usr/local/bin/rmuser

### sharelink
cat <<'EOF' > /usr/local/bin/sharelink
#!/bin/bash
set -euo pipefail

CONFIG="/usr/local/etc/xray/config.json"
KEYS="/usr/local/etc/xray/.keys"

email="${1:-}"

if [[ -z "$email" ]]; then
  emails=($(jq -r '.inbounds[0].settings.clients[].email' "$CONFIG"))
  select email in "${emails[@]}"; do break; done
fi

uuid="$(jq -r --arg email "$email" '.inbounds[0].settings.clients[]|select(.email==$email)|.id' "$CONFIG")"
port="$(jq -r '.inbounds[0].port' "$CONFIG")"
protocol="$(jq -r '.inbounds[0].protocol' "$CONFIG")"
sni="$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")"

pbk="$(awk -F': ' '/^Password:/ {print $2}' "$KEYS")"
sid="$(awk -F': ' '/^shortsid:/ {print $2}' "$KEYS")"

ip="$(ip -4 route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')"

link="$protocol://$uuid@$ip:$port?security=reality&sni=$sni&fp=firefox&pbk=$pbk&sid=$sid&spx=/&type=tcp&flow=xtls-rprx-vision&encryption=none#$email"

echo "$link"
echo "$link" | qrencode -t ansiutf8
EOF
chmod +x /usr/local/bin/sharelink

### mainuser
cat <<'EOF' > /usr/local/bin/mainuser
#!/bin/bash
/usr/local/bin/sharelink "main@user"
EOF
chmod +x /usr/local/bin/mainuser

############################################
# Step 7: Firewall
############################################

echo "[7/8] Configuring firewall..."

ufw allow 22/tcp
ufw allow 443/tcp
ufw --force enable

############################################
# Step 8: Done
############################################

ip="$(ip -4 route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1);exit}}')"

echo "========================================="
echo " ✅ Installation complete"
echo " Server IP: $ip"
echo ""
echo " Main user:"
/usr/local/bin/mainuser
echo ""
echo " Commands:"
echo "   newuser    - add client"
echo "   rmuser     - remove client"
echo "   sharelink  - show client link"
echo "========================================="