#!/usr/bin/env python3
"""
Set unique heroTag values for FloatingActionButton and FloatingActionButton.extended
across known Flutter screen files, to avoid Hero tag collisions.
Usage:
    python set_fab_herotags.py /path/to/project/root
"""
from pathlib import Path
import re
import sys
import json

TAG_MAP = {
  "inicio_screen.dart": "fab_inicio",
  "clientes_screen.dart": "fab_clientes",
  "cliente_detalle_screen.dart": "fab_cliente_detalle",
  "prestamos_screen.dart": "fab_prestamos",
  "pagos_screen.dart": "fab_pagos",
  "nuevo_prestamo_screen.dart": "fab_nuevo_prestamo",
  "nuevo_cliente_screen.dart": "fab_nuevo_cliente",
  "editar_cliente_screen.dart": "fab_editar_cliente",
  "solicitudes_screen.dart": "fab_solicitudes",
  "panel_principal_screen.dart": "fab_panel",
  "home_shell.dart": "fab_shell",
  "login_screen.dart": "fab_login",
  "prestamo_detalle_screen.dart": "fab_prestamo_detalle",
  "agregar_pago_screen.dart": "fab_agregar_pago",
  "calculadora_screen.dart": "fab_calculadora"
}

FAB_PATTERNS = [
    # FloatingActionButton(...)
    (re.compile(r"(FloatingActionButton\s*\()(?![^)]*heroTag\s*:)"),
     "FloatingActionButton(heroTag: '{tag}', "),
    # FloatingActionButton.extended(...)
    (re.compile(r"(FloatingActionButton\s*\.\s*extended\s*\()(?![^)]*heroTag\s*:)"),
     "FloatingActionButton.extended(heroTag: '{tag}', "),
]

# Replace existing heroTag values to our canonical tag
REPLACE_EXISTING = re.compile(r"heroTag\s*:\s*([^\s,)\]]+)")

def patch_file(path: Path, tag: str) -> bool:
    try:
        src = path.read_text(encoding="utf-8")
    except Exception:
        return False

    original = src

    # If there's already a heroTag, normalize it to our tag (only inside this file)
    def replace_existing(m):
        return f"heroTag: '{tag}'"

    src = REPLACE_EXISTING.sub(replace_existing, src)

    # Inject heroTag when missing
    for pat, repl in FAB_PATTERNS:
        src = pat.sub(lambda m: repl.format(tag=tag), src)

    if src != original:
        path.write_text(src, encoding="utf-8")
        return True
    return False

def main():
    if len(sys.argv) != 2:
        print("Usage: python set_fab_herotags.py /path/to/project/root")
        sys.exit(1)
    root = Path(sys.argv[1]).resolve()
    if not root.exists():
        print(f"Path not found: {root}")
        sys.exit(1)

    total = 0
    modified = []
    for fname, tag in TAG_MAP.items():
        fpath = root / "lib" / "screens" / fname
        if fpath.exists():
            if patch_file(fpath, tag):
                modified.append(str(fpath.relative_to(root)))
                total += 1

    print(json.dumps({"modified_count": total, "modified_files": modified}, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
