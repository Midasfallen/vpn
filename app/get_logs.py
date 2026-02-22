#!/usr/bin/env python3
"""Get Flutter logs and find errors"""
import subprocess
import sys

# Run logcat with grep for errors
print("Getting Flutter logs with ERROR pattern...")
result = subprocess.run(
    ["adb", "logcat", "-s", "flutter", "|", "findstr", "ERROR"],
    shell=True,
    capture_output=True,
    text=True
)

if result.stdout:
    print("Errors found:")
    print(result.stdout)
else:
    print("No errors in logs. Getting last 50 lines of flutter logs...")
    result = subprocess.run(
        ["adb", "logcat", "-s", "flutter", "-e", "flutter"],
        capture_output=True,
        text=True
    )
    lines = result.stdout.split('\n')
    for line in lines[-50:]:
        if line.strip():
            print(line)
