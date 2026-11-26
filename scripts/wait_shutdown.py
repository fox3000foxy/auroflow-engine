import json
import os
import socket
import time
from pathlib import Path

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
        qemu_pid = int(Path(root, "qemu.pid").read_text())

        cmd("quit")
        f.close()
        s.close()

        for _ in range(300):
            try:
                os.kill(qemu_pid, 0)
                stat = Path(f"/proc/{qemu_pid}/stat").read_text()
                running = stat.rsplit(") ", 1)[1][0] != "Z"
            except (ProcessLookupError, FileNotFoundError):
                running = False

            if not running and Path(root, "tpm-stopped").exists():
                Path(root, "clean").touch()
                print("[VM] Clean QEMU and TPM shutdown confirmed",
                      flush=True)
                break

            time.sleep(0.1)
        else:
            raise RuntimeError("QEMU or TPM shutdown timeout")

        break

    if time.time() >= deadline and not requested:
        print("[VM] Requesting ACPI shutdown", flush=True)
        cmd("system_powerdown")
        requested = True

    if time.time() >= deadline + 120:
        raise RuntimeError("Guest shutdown timeout")

    time.sleep(2)
