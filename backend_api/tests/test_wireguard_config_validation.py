"""
E2E Test: WireGuard Config Validation
Tests the critical fix for VPN internet access issue.
"""
import os
import pytest
from fastapi.testclient import TestClient


def test_wireguard_config_has_server_public_key(client: TestClient, auth_headers: dict):
    """Test that generated WireGuard config contains SERVER public key, not client key."""
    # Create a peer
    response = client.post("/vpn_peers/self", json={}, headers=auth_headers)
    assert response.status_code == 200
    peer_data = response.json()

    peer_id = peer_data["id"]
    client_public_key = peer_data["wg_public_key"]

    # Get the config
    config_response = client.get("/vpn_peers/self/config", headers=auth_headers)
    assert config_response.status_code == 200

    config_data = config_response.json()
    wg_config = config_data["wg_quick"]

    # Critical validation: config must NOT contain client's public key in [Peer] section
    # It should contain SERVER's public key instead
    lines = wg_config.split("\n")
    peer_section_started = False
    peer_public_key = None

    for line in lines:
        line = line.strip()
        if line == "[Peer]":
            peer_section_started = True
            continue
        if peer_section_started and line.startswith("PublicKey"):
            peer_public_key = line.split("=")[1].strip()
            break

    # The PUBLIC KEY in [Peer] section must be SERVER key, NOT client key
    server_public_key = os.getenv("WG_SERVER_PUBLIC_KEY", "")
    assert peer_public_key is not None, "No PublicKey found in [Peer] section"
    assert peer_public_key == server_public_key, \
        f"Config contains client key {peer_public_key}, should contain server key {server_public_key}"
    assert peer_public_key != client_public_key, \
        f"CRITICAL: Config contains client public key in [Peer] section! This breaks internet access."


def test_wireguard_config_has_endpoint(client: TestClient, auth_headers: dict):
    """Test that WireGuard config contains Endpoint."""
    response = client.post("/vpn_peers/self", json={}, headers=auth_headers)
    assert response.status_code == 200

    config_response = client.get("/vpn_peers/self/config", headers=auth_headers)
    assert config_response.status_code == 200

    wg_config = config_response.json()["wg_quick"]

    # Check for Endpoint
    assert "Endpoint" in wg_config, "Missing Endpoint in config"

    # Parse endpoint
    for line in wg_config.split("\n"):
        if line.strip().startswith("Endpoint"):
            endpoint = line.split("=")[1].strip()
            assert ":" in endpoint, f"Endpoint {endpoint} missing port"
            host, port = endpoint.split(":")
            assert len(host) > 0, "Endpoint host is empty"
            assert port.isdigit(), f"Endpoint port {port} is not a number"
            assert int(port) > 0, f"Endpoint port {port} is invalid"
            break


def test_wireguard_config_has_dns(client: TestClient, auth_headers: dict):
    """Test that WireGuard config contains DNS."""
    response = client.post("/vpn_peers/self", json={}, headers=auth_headers)
    assert response.status_code == 200

    config_response = client.get("/vpn_peers/self/config", headers=auth_headers)
    assert config_response.status_code == 200

    wg_config = config_response.json()["wg_quick"]

    # Check for DNS in [Interface] section
    assert "DNS" in wg_config, "Missing DNS in config"

    # Parse DNS
    for line in wg_config.split("\n"):
        if line.strip().startswith("DNS"):
            dns = line.split("=")[1].strip()
            # DNS can be comma-separated list
            dns_servers = [d.strip() for d in dns.split(",")]
            assert len(dns_servers) > 0, "No DNS servers specified"
            for dns_server in dns_servers:
                # Basic IP validation
                parts = dns_server.split(".")
                assert len(parts) == 4, f"Invalid DNS IP: {dns_server}"
            break


def test_wireguard_config_format(client: TestClient, auth_headers: dict):
    """Test that WireGuard config has correct wg-quick format."""
    response = client.post("/vpn_peers/self", json={}, headers=auth_headers)
    assert response.status_code == 200

    config_response = client.get("/vpn_peers/self/config", headers=auth_headers)
    assert config_response.status_code == 200

    wg_config = config_response.json()["wg_quick"]

    # Check sections
    assert "[Interface]" in wg_config, "Missing [Interface] section"
    assert "[Peer]" in wg_config, "Missing [Peer] section"

    # Check required fields in Interface
    assert "PrivateKey" in wg_config, "Missing PrivateKey"
    assert "Address" in wg_config, "Missing Address"
    assert "DNS" in wg_config, "Missing DNS"

    # Check required fields in Peer
    assert "PublicKey" in wg_config, "Missing PublicKey in [Peer]"
    assert "AllowedIPs" in wg_config, "Missing AllowedIPs"
    assert "Endpoint" in wg_config, "Missing Endpoint"

    # Validate AllowedIPs for full tunnel
    lines = wg_config.split("\n")
    peer_section = False
    for line in lines:
        line = line.strip()
        if line == "[Peer]":
            peer_section = True
            continue
        if peer_section and line.startswith("AllowedIPs"):
            allowed_ips = line.split("=")[1].strip()
            # For full VPN tunnel, should be 0.0.0.0/0
            assert "0.0.0.0/0" in allowed_ips, \
                f"AllowedIPs should contain 0.0.0.0/0 for full tunnel, got: {allowed_ips}"
            break


def test_wireguard_config_environment_vars():
    """Test that required environment variables are set."""
    server_key = os.getenv("WG_SERVER_PUBLIC_KEY")
    endpoint = os.getenv("WG_ENDPOINT")
    dns = os.getenv("WG_DNS")

    assert server_key, "WG_SERVER_PUBLIC_KEY environment variable not set"
    assert endpoint, "WG_ENDPOINT environment variable not set"
    assert dns, "WG_DNS environment variable not set"

    # Validate endpoint format
    assert ":" in endpoint, f"WG_ENDPOINT {endpoint} missing port"
    host, port = endpoint.split(":")
    assert len(host) > 0, "WG_ENDPOINT host is empty"
    assert port.isdigit(), f"WG_ENDPOINT port {port} is not a number"

    # Validate DNS format
    dns_servers = [d.strip() for d in dns.split(",")]
    assert len(dns_servers) > 0, "WG_DNS has no servers"
