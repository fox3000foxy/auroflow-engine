import json
import os
import socket
import time

root = os.environ["VM_ROOT"]
deadline = int(os.environ["DEADLINE"])

s = socket.socket(socket.AF_UNIX)
s.settimeout(10)
s.connect(root + "/qmp.sock")

f = s.makefile("rwb")
json.loads(f.readline())

def cmd(name):
    f.write(json.dumps({"execute": name}).encode() + b"\n")
    f.flush()

    while True:
        line = f.readline()

        if not line:
            raise RuntimeError("QMP disconnected")

        response = json.loads(line)

        if "error" in response:
            raise RuntimeError(response["error"])

        if "return" in response:
            return response["return"]

cmd("qmp_capabilities")

requested = False

print("[VM] Waiting for guest shutdown", flush=True)

while True:
    status = cmd("query-status")["status"]

    if status == "shutdown":
        cmd("quit")
        print("[VM] Clean shutdown confirmed", flush=True)
        break

    if time.time() >= deadline and not requested:
        print("[VM] Requesting ACPI shutdown", flush=True)
        cmd("system_powerdown")
        requested = True

    if time.time() >= deadline + 120:
        raise RuntimeError("Guest shutdown timeout")

    time.sleep(2)
