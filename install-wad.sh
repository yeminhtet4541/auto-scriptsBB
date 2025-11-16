#!/usr/bin/env bash
# WAD PANEL Auto Installer (Ubuntu 20.04 / 22.04)
# Usage:
#   sudo bash install-wad.sh
# NOTE: Run as root.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

WAD_DIR="/var/www/wad"
BACKEND_DIR="/opt/wad-backend"
FRONTEND_DIR="$WAD_DIR"
NODE_PORT=6969

echo "== WAD PANEL Installer =="
echo "[*] Updating system..."
apt update -y
apt upgrade -y

echo "[*] Install base packages..."
apt install -y curl wget git unzip build-essential netcat jq

echo "[*] Install Node.js (LTS) ..."
# Install Node 18 LTS (works with Ubuntu 20/22)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

echo "[*] Install nginx..."
apt install -y nginx
systemctl enable --now nginx

echo "[*] Create directories..."
mkdir -p $WAD_DIR
mkdir -p /etc/wad
mkdir -p /etc/wad/users
mkdir -p $BACKEND_DIR

echo "[*] Deploy backend files..."
# If you prefer git clone, replace with git clone. Here we create files directly.
cat > $BACKEND_DIR/package.json <<'EOF'
{
  "name": "wad-backend",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "body-parser": "^1.20.2",
    "jsonwebtoken": "^9.0.0",
    "node-cron": "^3.0.2",
    "basic-auth": "^2.0.1",
    "bcrypt": "^5.1.1"
  }
}
EOF

cat > $BACKEND_DIR/index.js <<'EOF'
/**
 * WAD Backend - NodeJS (Express)
 * Simple JSON-file storage for users (/etc/wad/users.json)
 * Provides basic API for:
 *  - /api/login (admin)
 *  - /api/xray/users (list)
 *  - /api/xray/create
 *  - /api/xray/delete
 *  - /api/ssh/create
 *
 * WARNING: This is a reference implementation. Hardening and production DB recommended.
 */
const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { exec } = require('child_process');
const cron = require('node-cron');
const bcrypt = require('bcrypt');

const USERS_FILE = '/etc/wad/users.json';
const ADMIN_FILE = '/etc/wad/admin.json';
const JWT_SECRET = process.env.JWT_SECRET || 'change_this_jwt_secret';
const PORT = process.env.PORT || 6969;

if (!fs.existsSync(USERS_FILE)) {
  fs.writeFileSync(USERS_FILE, JSON.stringify({ xray: [], ssh: [] }, null, 2));
}
if (!fs.existsSync(ADMIN_FILE)) {
  // default admin: admin / admin123 (change ASAP)
  const pwdHash = bcrypt.hashSync('admin123', 10);
  fs.writeFileSync(ADMIN_FILE, JSON.stringify({ username: 'admin', password: pwdHash }, null, 2));
}

const app = express();
app.use(bodyParser.json());

function readUsers() {
  return JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
}
function writeUsers(data) {
  fs.writeFileSync(USERS_FILE, JSON.stringify(data, null, 2));
}

function authMiddleware(req, res, next) {
  const token = req.headers['authorization'] && req.headers['authorization'].split(' ')[1];
  if (!token) return res.status(401).json({ error: 'no token' });
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'invalid token' });
  }
}

// Admin login
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body || {};
  const admin = JSON.parse(fs.readFileSync(ADMIN_FILE));
  const ok = (username === admin.username) && (await bcrypt.compare(password, admin.password));
  if (!ok) return res.status(401).json({ error: 'invalid credentials' });
  const token = jwt.sign({ user: username }, JWT_SECRET, { expiresIn: '12h' });
  res.json({ token });
});

// Xray users list
app.get('/api/xray/users', authMiddleware, (req, res) => {
  const data = readUsers();
  res.json({ xray: data.xray || [] });
});

// Create xray user (basic)
app.post('/api/xray/create', authMiddleware, (req, res) => {
  const { username, days } = req.body || {};
  if (!username || !days) return res.status(400).json({ error: 'username, days required' });

  const expireDate = new Date();
  expireDate.setDate(expireDate.getDate() + Number(days));
  const id = crypto.randomBytes(6).toString('hex');

  const entry = { id, username, expire: expireDate.toISOString().slice(0,10), created: new Date().toISOString() };

  const data = readUsers();
  data.xray.push(entry);
  writeUsers(data);

  // TODO: integrate with xray config generation / call xray json edit
  // Example: create config file or run xray commands here

  res.json({ ok: true, entry });
});

// Delete xray user
app.delete('/api/xray/delete/:id', authMiddleware, (req, res) => {
  const id = req.params.id;
  const data = readUsers();
  const before = data.xray.length;
  data.xray = data.xray.filter(u => u.id !== id);
  writeUsers(data);
  res.json({ ok: true, removed: before - data.xray.length });
});

// SSH user create (system user)
app.post('/api/ssh/create', authMiddleware, (req, res) => {
  const { username, password, days } = req.body || {};
  if (!username || !password || !days) return res.status(400).json({ error: 'username,password,days required' });

  const expireDate = new Date();
  expireDate.setDate(expireDate.getDate() + Number(days));
  // create system user (no shell)
  exec(`useradd -M -N -s /usr/sbin/nologin ${username} || true; echo '${username}:${password}' | chpasswd`, (err, sout, serr) => {
    if (err) {
      return res.status(500).json({ error: 'useradd failed', details: serr });
    }
    const data = readUsers();
    data.ssh.push({ username, expire: expireDate.toISOString().slice(0,10), created: new Date().toISOString() });
    writeUsers(data);
    res.json({ ok: true, username, expire: expireDate.toISOString().slice(0,10) });
  });
});

// Expire cleanup (also scheduled by cron)
app.post('/api/expire/run', authMiddleware, (req, res) => {
  const today = new Date().toISOString().slice(0,10);
  const data = readUsers();
  let removed = { xray: 0, ssh: 0 };
  data.xray = data.xray.filter(u => {
    if (u.expire < today) { removed.xray++; return false; }
    return true;
  });
  const oldSSH = data.ssh || [];
  data.ssh = oldSSH.filter(s => {
    if (s.expire < today) {
      // optionally delete system user: userdel -r <user>
      exec(`userdel ${s.username} || true`);
      removed.ssh++;
      return false;
    }
    return true;
  });
  writeUsers(data);
  res.json({ ok: true, removed });
});

// Simple stats endpoints (dummy)
app.get('/api/stats', authMiddleware, (req, res) => {
  const data = readUsers();
  const stats = {
    xray_total: data.xray.length,
    ssh_total: data.ssh.length,
    server_time: new Date().toISOString()
  };
  res.json(stats);
});

app.listen(PORT, () => {
  console.log('WAD Backend listening on', PORT);
});

// Schedule hourly expire just in case (node-cron)
cron.schedule('0 * * * *', () => {
  const today = new Date().toISOString().slice(0,10);
  const data = JSON.parse(fs.readFileSync(USERS_FILE));
  data.xray = data.xray.filter(u => u.expire >= today);
  data.ssh = (data.ssh || []).filter(s => {
    if (s.expire < today) {
      exec(`userdel ${s.username} || true`);
      return false;
    }
    return true;
  });
  fs.writeFileSync(USERS_FILE, JSON.stringify(data, null, 2));
  console.log('[cron] expire cleanup done', new Date().toISOString());
});
EOF

echo "[*] Create default admin and env..."
cat > /etc/wad/admin.json <<'EOF'
{ "username": "admin", "password": "$2b$10$RANDOM_REPLACE_ME" }
EOF
# replace admin password with bcrypt hash of admin123
ADMIN_PASS_HASH=$(node -e "const bcrypt = require('bcrypt'); bcrypt.hash('admin123',10).then(h=>console.log(h))")
sed -i "s/\\$2b\\$10\\$RANDOM_REPLACE_ME/$(echo $ADMIN_PASS_HASH | sed 's/\\//\\\\\\//g')/" /etc/wad/admin.json

cat > $BACKEND_DIR/.env <<EOF
PORT=${NODE_PORT}
JWT_SECRET=change_this_jwt_secret
EOF

echo "[*] Install backend dependencies..."
cd $BACKEND_DIR
# write users.json initial
mkdir -p /etc/wad
echo '{"xray":[],"ssh":[]}' > /etc/wad/users.json
npm install --production

echo "[*] Create systemd service for backend..."
cat > /etc/systemd/system/wad-backend.service <<EOF
[Unit]
Description=WAD Backend Service
After=network.target

[Service]
Environment=PORT=${NODE_PORT}
Environment=JWT_SECRET=change_this_jwt_secret
WorkingDirectory=${BACKEND_DIR}
ExecStart=$(which node) ${BACKEND_DIR}/index.js
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now wad-backend

echo "[*] Deploy frontend (Bootstrap 5 minimal dashboard)..."
cat > $FRONTEND_DIR/index.html <<'EOF'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>WAD Panel</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body>
<!-- Simple Login & Dashboard skeleton -->
<div id="app" class="container py-4">
  <div id="loginBox" style="max-width:420px;margin:40px auto;">
    <h3>WAD Panel - Login</h3>
    <div class="mb-3">
      <input id="username" class="form-control" placeholder="admin">
    </div>
    <div class="mb-3">
      <input id="password" type="password" class="form-control" placeholder="password">
    </div>
    <button id="loginBtn" class="btn btn-primary">Login</button>
    <div id="loginMsg" class="mt-2 text-danger"></div>
  </div>

  <div id="dashboard" style="display:none;">
    <div class="d-flex justify-content-between align-items-center">
      <h3>Dashboard</h3>
      <button id="logoutBtn" class="btn btn-outline-secondary">Logout</button>
    </div>

    <div class="row mt-3">
      <div class="col-md-3">
        <div class="card p-3">
          <h5 id="statXray">XRAY: 0</h5>
          <button id="btnXray" class="btn btn-sm btn-success">Manage XRAY Users</button>
        </div>
      </div>
      <div class="col-md-3">
        <div class="card p-3">
          <h5 id="statSSH">SSH: 0</h5>
          <button id="btnSSH" class="btn btn-sm btn-success">Manage SSH Users</button>
        </div>
      </div>
      <div class="col-md-6">
        <div class="card p-3">
          <canvas id="chartBandwidth" height="80"></canvas>
        </div>
      </div>
    </div>

    <div id="panels" class="mt-4"></div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
const API_BASE = '/api';
let token = null;

document.getElementById('loginBtn').onclick = async () => {
  const u = document.getElementById('username').value;
  const p = document.getElementById('password').value;
  const res = await fetch(API_BASE + '/login', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ username: u, password: p })
  });
  if (res.ok) {
    const j = await res.json();
    token = j.token;
    document.getElementById('loginBox').style.display='none';
    document.getElementById('dashboard').style.display='block';
    loadStats();
  } else {
    document.getElementById('loginMsg').innerText = 'Invalid credentials';
  }
};

document.getElementById('logoutBtn').onclick = () => {
  token = null;
  document.getElementById('loginBox').style.display='block';
  document.getElementById('dashboard').style.display='none';
};

async function loadStats(){
  const res = await fetch(API_BASE + '/stats', { headers: { 'Authorization': 'Bearer '+token }});
  if (!res.ok) return;
  const s = await res.json();
  document.getElementById('statXray').innerText = 'XRAY: ' + s.xray_total;
  document.getElementById('statSSH').innerText = 'SSH: ' + s.ssh_total;
}
// simple chart
const ctx = document.getElementById('chartBandwidth').getContext('2d');
new Chart(ctx, {
  type: 'line',
  data: { labels:['t-5','t-4','t-3','t-2','t-1','now'], datasets:[{label:'Bandwidth', data:[10,12,8,14,11,15], fill:false}] },
  options:{responsive:true, plugins:{legend:{display:false}}}
});
</script>
</body>
</html>
EOF

echo "[*] Configure nginx site..."
cat > /etc/nginx/sites-available/wad <<EOF
server {
    listen 80;
    server_name _;

    root ${FRONTEND_DIR};
    index index.html;

    location /api/ {
        proxy_pass http://127.0.0.1:${NODE_PORT}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

ln -sf /etc/nginx/sites-available/wad /etc/nginx/sites-enabled/wad
nginx -t && systemctl reload nginx

echo "[*] Create cron for expire job (runs hourly)"
# Use curl to trigger backend expire endpoint via root token not configured here. Also backend has internal cron.
# We'll add system cron to call node script directly (node cron already runs). No extra cron required.

echo "== Installer finished =="
echo "Visit: http://<SERVER_IP>/"
echo "Backend: http://<SERVER_IP>:${NODE_PORT}"
echo "Default admin username: admin"
echo "Default admin password: admin123 (please change in /etc/wad/admin.json)"
echo "Service: systemctl status wad-backend"
