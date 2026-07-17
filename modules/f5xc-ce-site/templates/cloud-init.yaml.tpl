#cloud-config
# ---------------------------------------------------------------------------
# Bootstrap file for the F5 Distributed Cloud Secure Mesh Site v2 CE node.
# F5's software reads /etc/vpm/user_data on first boot to register the node
# with F5 Distributed Cloud Console using the one-time node token, and to
# pin the SLO interface to a known static IP/gateway so it matches the
# Elastic IP association and TGW-facing routing we configure in Terraform.
# ---------------------------------------------------------------------------
write_files:
  - path: /etc/vpm/user_data
    permissions: '0644'
    owner: root
    content: |
      token: ${token}
      slo_ip: ${slo_ip}/${slo_prefix_length}
      slo_gateway: ${slo_gateway}
