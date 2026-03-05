#cloud-config
#
# Terraform templatefile() substitutions:
#   ${wg_server_address}  -> WireGuard interface address (e.g. 10.100.0.1/24)
#   ${wg_port}            -> WireGuard UDP listen port  (e.g. 51820)
#
# Inside the shell script, "$$VAR" becomes "$VAR" after Terraform renders the
# template (double-dollar is the templatefile escape for a literal dollar sign).

write_files:
  # ---- WireGuard config skeleton (key filled in by setup script) ----------
  - path: /etc/wireguard/wg0.conf.tpl
    permissions: "0600"
    content: |
      [Interface]
      Address    = ${wg_server_address}
      ListenPort = ${wg_port}
      PrivateKey = __PLACEHOLDER_PRIVATE_KEY__
      PostUp   = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
      PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

  # ---- Setup script -------------------------------------------------------
  - path: /usr/local/bin/wireguard-setup.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail

      echo ">>> Installing WireGuard ($(date))..."
      export DEBIAN_FRONTEND=noninteractive
      # ForceIPv4 avoids IPv6 timeout on Azure; Lock::Timeout waits for any
      # concurrent apt process (e.g. unattended-upgrades) to finish.
      apt-get -o Acquire::ForceIPv4=true -o DPkg::Lock::Timeout=300 update -y
      apt-get -o Acquire::ForceIPv4=true -o DPkg::Lock::Timeout=300 install -y --no-install-recommends wireguard

      WG_DIR=/etc/wireguard
      WG_IFACE=wg0

      echo ">>> Generating WireGuard server keys..."
      wg genkey | tee "$WG_DIR/server_private.key" | wg pubkey > "$WG_DIR/server_public.key"
      chmod 600 "$WG_DIR/server_private.key" "$WG_DIR/server_public.key"

      echo ">>> Writing wg0.conf..."
      PRIVATE_KEY=$(cat "$WG_DIR/server_private.key")
      sed "s|__PLACEHOLDER_PRIVATE_KEY__|$PRIVATE_KEY|" \
          "$WG_DIR/$WG_IFACE.conf.tpl" > "$WG_DIR/$WG_IFACE.conf"
      chmod 600 "$WG_DIR/$WG_IFACE.conf"
      rm "$WG_DIR/$WG_IFACE.conf.tpl"

      echo ">>> Enabling IP forwarding..."
      echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
      sysctl -p /etc/sysctl.d/99-wireguard.conf

      echo ">>> Starting WireGuard..."
      systemctl enable "wg-quick@$WG_IFACE"
      systemctl start  "wg-quick@$WG_IFACE"

      echo "=== WireGuard setup complete ==="
      echo "Server public key: $(cat $WG_DIR/server_public.key)"

  # ---- systemd service (runs setup script outside cloud-init supervision) -
  - path: /etc/systemd/system/wireguard-setup.service
    content: |
      [Unit]
      Description=WireGuard First-Boot Setup
      After=network-online.target
      Wants=network-online.target
      ConditionPathExists=!/etc/wireguard/wg0.conf

      [Service]
      Type=oneshot
      ExecStart=/usr/local/bin/wireguard-setup.sh
      StandardOutput=append:/var/log/wireguard-setup.log
      StandardError=append:/var/log/wireguard-setup.log
      RemainAfterExit=yes

      [Install]
      WantedBy=multi-user.target

runcmd:
  - systemctl daemon-reload
  - systemctl enable wireguard-setup.service
  - systemctl start wireguard-setup.service
