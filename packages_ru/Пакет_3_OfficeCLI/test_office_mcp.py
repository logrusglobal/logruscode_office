# -*- coding: utf-8 -*-
"""Проверка подключения Office MCP-серверов (Word и Excel).

Запускает каждый сервер и выполняет реальный MCP-рукоshake (initialize).
Выводит HANDSHAKE OK / FAIL для каждого сервера.
"""
import json
import os
import shutil
import subprocess
import threading

UVX = shutil.which("uvx") or os.path.expanduser(r"~\.local\bin\uvx.exe")

SERVERS = {
    "office-word": ["--from", "office-word-mcp-server", "word_mcp_server"],
    "office-excel": ["excel-mcp-server", "stdio"],
}


def test(name, args):
    p = subprocess.Popen(
        [UVX] + args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    req = json.dumps({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "office-cli-test", "version": "1.0"},
        },
    })
    out = []

    def reader():
        try:
            out.append(p.stdout.readline().decode("utf-8", "replace"))
        except Exception:
            pass

    t = threading.Thread(target=reader, daemon=True)
    t.start()
    try:
        p.stdin.write((req + "\n").encode())
        p.stdin.flush()
        t.join(timeout=60)
    finally:
        p.kill()

    ok = bool(out) and '"serverInfo"' in out[0]
    print(f"{name}: {'HANDSHAKE OK' if ok else 'HANDSHAKE FAIL'}")
    return ok


def main():
    print(f"uvx: {UVX}")
    results = [test(n, a) for n, a in SERVERS.items()]
    print()
    if all(results):
        print("Все серверы работают. Перезапустите OpenCode Desktop.")
        return 0
    print("Один или несколько серверов не прошли проверку.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
