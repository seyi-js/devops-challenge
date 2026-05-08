#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${aws_region}"
LOG_GROUP="${log_group_name}"

# ── System ────────────────────────────────────────────────────────────────────
dnf update -y
dnf install -y docker

systemctl enable --now docker

# ── SSM agent (pre-installed on AL2023, but ensure it is running) ─────────────
dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────
if ! command -v aws &>/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip
  unzip -q /tmp/awscli.zip -d /tmp
  /tmp/aws/install
  rm -rf /tmp/aws /tmp/awscli.zip
fi

# ── CloudWatch agent ──────────────────────────────────────────────────────────
dnf install -y amazon-cloudwatch-agent

cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/devops-app.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/app",
            "timestamp_format": "%Y-%m-%dT%H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["disk_used_percent"], "resources": ["/"] }
    },
    "append_dimensions": { "InstanceId": "$${aws:InstanceId}" },
    "aggregation_dimensions": [["InstanceId"]]
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# ── Docker daemon: send container logs to local file (CWA picks them up) ──────
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "3" }
}
EOF
systemctl restart docker

# ── Log rotation for app log ──────────────────────────────────────────────────
cat > /etc/logrotate.d/devops-app << 'EOF'
/var/log/devops-app.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  copytruncate
}
EOF

echo "Bootstrap complete. Waiting for first deploy via GitHub Actions."
