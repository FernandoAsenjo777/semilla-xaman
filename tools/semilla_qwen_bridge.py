#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import hashlib
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, List

REPO = Path(__file__).resolve().parents[1]
INBOX = REPO / "runtime" / "inbox"
OUTBOX = REPO / "runtime" / "outbox"
PROCESSED = REPO / "runtime" / "processed"
STATUS = REPO / "runtime" / "status"
EVIDENCE = REPO / "evidence" / "cycle"
MODEL = "qwen-local"

def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()

def write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

def pending_tasks() -> List[Path]:
    INBOX.mkdir(parents=True, exist_ok=True)
    return sorted(INBOX.glob("*.md"), key=lambda p: p.stat().st_mtime)

def run_qwen(prompt: str) -> str:
    system = """Eres Qwen Semilla, una IA local en entrenamiento para evolucionar hacia Xaman local.
Tu tarea es responder de forma concreta, útil y estructurada.
No inventes haber leído archivos externos.
No copies código externo.
No propongas acciones peligrosas.
Respeta el formato pedido.
Si falta información, dilo.
"""
    full_prompt = system + "\n\n" + prompt

    completed = subprocess.run(
        ["ollama", "run", MODEL, full_prompt],
        cwd=str(REPO),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=300
    )

    if completed.returncode != 0:
        raise RuntimeError(completed.stderr.strip() or f"Ollama failed with code {completed.returncode}")

    return completed.stdout.strip()

def main() -> int:
    for p in [INBOX, OUTBOX, PROCESSED, STATUS, EVIDENCE]:
        p.mkdir(parents=True, exist_ok=True)

    tasks = pending_tasks()
    if not tasks:
        status = {
            "timestamp": now_iso(),
            "status": "IDLE",
            "message": "No pending tasks."
        }
        write_json(STATUS / "semilla_qwen_bridge_status.json", status)
        print("[SEMILLA-QWEN] IDLE: no pending tasks")
        return 0

    task = tasks[0]
    prompt = task.read_text(encoding="utf-8-sig", errors="replace")
    response = run_qwen(prompt)

    out_name = task.name.replace(".learning_task.md", ".qwen_response.md")
    out_path = OUTBOX / out_name
    out_content = f"""# Qwen Semilla response · {task.stem}

Task hash: `{sha(prompt)}`
Response hash: `{sha(response)}`
Created at: `{now_iso()}`

---

{response}
"""
    out_path.write_text(out_content, encoding="utf-8")

    processed_path = PROCESSED / task.name
    task.replace(processed_path)

    event = {
        "timestamp": now_iso(),
        "status": "OK",
        "model": MODEL,
        "task": str(processed_path.relative_to(REPO)),
        "outbox": str(out_path.relative_to(REPO)),
        "task_hash": sha(prompt),
        "response_hash": sha(response),
        "dangerous_actions_executed": False
    }

    write_json(STATUS / "semilla_qwen_bridge_status.json", event)
    write_json(EVIDENCE / f"semilla_cycle_{stamp()}.json", event)

    print(f"[SEMILLA-QWEN] Processed: {processed_path}")
    print(f"[SEMILLA-QWEN] Outbox: {out_path}")
    print("[SEMILLA-QWEN] Status: OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
