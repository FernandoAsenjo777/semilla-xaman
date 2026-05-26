#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

REPO = Path(__file__).resolve().parents[1]
SOURCE_MAP = REPO / "data" / "source_map.json"
INBOX = REPO / "runtime" / "inbox"
MEMORY = REPO / "runtime" / "memory"
STATUS = REPO / "runtime" / "status"
EVIDENCE = REPO / "evidence" / "learning"

def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

def stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")

def read_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))

def write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

def append_jsonl(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(payload, ensure_ascii=False) + "\n")

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()

def load_sources() -> List[Dict[str, Any]]:
    data = read_json(SOURCE_MAP)
    return data.get("sources", [])

def already_processed(source_id: str) -> bool:
    log = MEMORY / "learning_events.jsonl"
    if not log.exists():
        return False
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except Exception:
            continue
        if event.get("source_id") == source_id:
            return True
    return False

def choose_source(sources: List[Dict[str, Any]], source_id: Optional[str]) -> Dict[str, Any]:
    if source_id:
        for source in sources:
            if source.get("id") == source_id:
                return source
        raise SystemExit(f"No existe source id: {source_id}")

    priority_order = {"alta": 0, "media-alta": 1, "media": 2, "baja": 3}
    pending = [
        s for s in sources
        if str(s.get("status", "")).startswith("pendiente")
        and not already_processed(str(s.get("id")))
    ]

    if not pending:
        raise SystemExit("No hay fuentes pendientes nuevas en source_map.")

    pending.sort(key=lambda s: priority_order.get(str(s.get("priority", "")).lower(), 9))
    return pending[0]

def build_task(source: Dict[str, Any]) -> str:
    modules = ", ".join(source.get("modules", []))
    return f"""# Microtarea de aprendizaje · {source.get("id")}

## Objetivo

Destilar esta fuente para enseñar a Qwen Semilla.

## Fuente

- ID: {source.get("id")}
- Fuente: {source.get("source")}
- Tipo: {source.get("type")}
- Enseña: {source.get("teaches")}
- Pierna: {source.get("leg")}
- Módulos inspirados: {modules}

## Preguntas cerradas

1. ¿Qué patrón principal debe aprender Qwen de esta fuente?
2. ¿Qué módulo de Semilla Xaman debe mejorar con este patrón?
3. ¿Qué riesgo hay si Qwen aplica mal este patrón?
4. ¿Qué regla concreta añadirías a la escuela de Qwen?
5. Veredicto: DESCARTAR / DESTILAR / PROBAR / INTEGRAR.

## Formato obligatorio

| Patrón aprendido | Módulo afectado | Riesgo | Regla para Qwen | Veredicto |
|---|---|---|---|---|

## Límites

No copies código externo.
No propongas instalaciones.
No conectes credenciales.
No hables de otros proyectos.
No des teoría genérica.
No inventes haber leído archivos que no se te han pasado.

## Criterio de éxito

La respuesta debe convertirse en aprendizaje guardable para Qwen Semilla.
"""

def main() -> int:
    parser = argparse.ArgumentParser(description="Semilla Xaman learning harness")
    parser.add_argument("--source-id", default=None)
    args = parser.parse_args()

    for path in [INBOX, MEMORY, STATUS, EVIDENCE]:
        path.mkdir(parents=True, exist_ok=True)

    source = choose_source(load_sources(), args.source_id)
    task = build_task(source)
    task_hash = sha(task)
    task_name = f"{stamp()}_{source.get('id')}.learning_task.md"
    task_path = INBOX / task_name

    event = {
        "timestamp": now_iso(),
        "event": "LEARNING_TASK_CREATED",
        "source_id": source.get("id"),
        "source": source,
        "task_file": str(task_path.relative_to(REPO)),
        "task_hash": task_hash,
        "status": "READY_FOR_QWEN",
        "dangerous_actions_executed": False
    }

    task_path.write_text(task, encoding="utf-8")
    append_jsonl(MEMORY / "learning_events.jsonl", event)

    write_json(STATUS / "semilla_learning_status.json", {
        "timestamp": now_iso(),
        "last_event": event,
        "next": "Process task with Qwen."
    })

    write_json(EVIDENCE / f"learning_task_{stamp()}_{source.get('id')}.json", {
        "created_at": now_iso(),
        "tool": "semilla_learning_harness",
        "version": "0.2",
        "event": event
    })

    print(f"[SEMILLA-LEARNING] Task: {task_path}")
    print(f"[SEMILLA-LEARNING] Source: {source.get('id')}")
    print("[SEMILLA-LEARNING] Status: READY_FOR_QWEN")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
