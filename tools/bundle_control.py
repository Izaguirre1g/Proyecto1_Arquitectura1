#!/usr/bin/env python3
"""Adapta ALU/LSU y control, con separación conservadora de dependencias."""
import re

if __package__:
    from .assembler import AssemblyError, BRU_OPS, assemble_source, encode_instruction
else:
    from assembler import AssemblyError, BRU_OPS, assemble_source, encode_instruction


INVERSE = {'igualsi': 'igualno', 'igualno': 'igualsi',
           'menora': 'mayoroigual', 'mayoroigual': 'menora'}


def _layout(entries, names):
    rows, pending, positions = [], [], {}
    labels = dict.fromkeys(names, 0)
    bundles = 0
    for index, (line, label, code) in enumerate(entries):
        if label is not None:
            pending.append(label)
            continue
        try:
            ins = encode_instruction(code, labels=labels)
            mnemonic = code.split()[0].lower()
            if ins.slot not in (0, 1) and mnemonic not in BRU_OPS and mnemonic not in ('sye', 'syer', 'ret'):
                raise AssemblyError('solo se admiten ALU, LSU y saltos del ISA')
            # Los destinos incluyen los NOP que protegen las vueltas del bucle.
            if pending:
                rows.extend(name + ':' for name in pending)
                rows.extend(['nop', 'nop'])
                bundles += 2
                pending.clear()
            elif rows:
                rows.extend(['nop', 'nop'])
                bundles += 2
            positions[index] = bundles * 16
            slots = ['nop'] * 4
            slots[ins.slot] = code
            rows.append(' | '.join(slots))
            bundles += 1
        except AssemblyError as exc:
            raise AssemblyError(f'línea {line}: {exc}') from exc
    if pending:
        rows.extend(name + ':' for name in pending)
        rows.extend(['nop', 'nop'])
    addresses, pc = {}, 0
    for row in rows:
        if row.endswith(':'):
            addresses[row[:-1]] = pc
        else:
            pc += 16
    return '\n'.join(rows) + '\n', positions, addresses


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
    serial = 0
    while True:
        output, positions, addresses = _layout(entries, names)
        expanded = []
        changed = False
        for index, (line, label, code) in enumerate(entries):
            parts = code.split(None, 1) if code else []
            op = parts[0].lower() if parts else ''
            operands = [s.strip() for s in parts[1].split(',')] if len(parts) == 2 else []
            if op in INVERSE and len(operands) == 3 and operands[2] in addresses:
                offset = addresses[operands[2]] - positions[index]
                if not -1024 <= offset <= 1023:
                    skip = f'__bc_skip_{serial}'
                    while skip in names:
                        serial += 1
                        skip = f'__bc_skip_{serial}'
                    names.add(skip)
                    serial += 1
                    # Condición inversa corta; el salto directo cubre el destino largo.
                    expanded.extend([(line, None, f'{INVERSE[op]} {operands[0]}, {operands[1]}, {skip}'),
                                     (line, None, f'sye x0, {operands[2]}'),
                                     (line, skip, None)])
                    changed = True
                    continue
            expanded.append((line, label, code))
        if not changed:
            assemble_source(output)
            return output
        entries = expanded
