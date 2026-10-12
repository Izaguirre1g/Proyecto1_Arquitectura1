#!/usr/bin/env python3
"""Adapta ALU/LSU y saltos directos, con separación conservadora de dependencias."""
import re

if __package__:
    from .assembler import AssemblyError, BRU_OPS, assemble_source, encode_instruction
else:
    from assembler import AssemblyError, BRU_OPS, assemble_source, encode_instruction


def bundle_control(source: str) -> str:
    entries, names = [], set()
    for line, raw in enumerate(source.splitlines(), 1):
        code = re.split(r'#|;|//', raw, maxsplit=1)[0].strip()
        if not code:
            continue
        match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$', code)
        if match:
            name, code = match.groups()
            if name in names:
                raise AssemblyError(f'línea {line}: etiqueta duplicada: {name}')
            names.add(name)
            entries.append((line, name, None))
        if code:
            if '|' in code:
                raise AssemblyError(f'línea {line}: se esperan instrucciones sin bundles')
            entries.append((line, None, code))
    rows, pending = [], []
    labels = dict.fromkeys(names, 0)
    for line, label, code in entries:
        if label is not None:
            pending.append(label)
            continue
        try:
            ins = encode_instruction(code, labels=labels)
            mnemonic = code.split()[0].lower()
            if ins.slot not in (0, 1) and mnemonic not in BRU_OPS and mnemonic != 'sye':
                raise AssemblyError('solo se admiten ALU, LSU y saltos directos')
            # El destino apunta a los NOP, para proteger también las vueltas del bucle.
            if pending:
                rows.extend(name + ':' for name in pending)
                rows.extend(['nop', 'nop'])
                pending.clear()
            elif rows:
                rows.extend(['nop', 'nop'])
            slots = ['nop'] * 4
            slots[ins.slot] = code
            rows.append(' | '.join(slots))
        except AssemblyError as exc:
            raise AssemblyError(f'línea {line}: {exc}') from exc
    if pending:
        rows.extend(name + ':' for name in pending)
        rows.extend(['nop', 'nop'])
    output = '\n'.join(rows) + '\n'
    assemble_source(output)
    return output
