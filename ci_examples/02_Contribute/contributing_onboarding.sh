#!/bin/bash
echo "=== CognitiveInsight.ai Developer Onboarding ==="
echo "[+] Checking environment..."
python3 --version || { echo "[-] Python3 required"; exit 1; }
echo "[+] Creating virtual environment..."
python3 -m venv venv && source venv/bin/activate
echo "[+] Installing JCS library..."
pip install jcs cryptography PyYAML
echo "[+] Running local canonicalization test..."
python3 06_Canonicalization/canonicalize_and_hash.py
echo "[+] Onboarding complete!"
