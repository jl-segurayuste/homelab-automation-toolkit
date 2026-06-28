#!/usr/bin/python
# -*- coding: utf-8 -*-
# Modulo Ansible para gestionar grupos y su membresia en un Samba AD DC.
# Licencia: MIT

from __future__ import annotations

DOCUMENTATION = r"""
---
module: samba_ad_group
short_description: Gestiona grupos y membresia en un Samba Active Directory DC
description:
  - Crea/elimina grupos y reconcilia su lista de miembros usando samba-tool.
options:
  name:
    description: Nombre del grupo.
    required: true
    type: str
  state:
    description: Estado deseado del grupo.
    choices: [present, absent]
    default: present
    type: str
  members:
    description: Lista de usuarios que deben pertenecer al grupo.
    type: list
    elements: str
    default: []
  purge_members:
    description: Si C(true), elimina del grupo a quien no este en C(members).
    type: bool
    default: false
author:
  - homelab-automation-toolkit
"""

EXAMPLES = r"""
- name: Asegurar grupo de administradores de copias y su membresia exacta
  samba_ad_group:
    name: BackupAdmins
    members: [alice, bob]
    purge_members: true
"""

RETURN = r"""
changed:
  description: Si hubo cambios.
  type: bool
  returned: always
added:
  description: Miembros anadidos.
  type: list
  returned: always
removed:
  description: Miembros eliminados.
  type: list
  returned: always
"""

from ansible.module_utils.basic import AnsibleModule


def group_exists(module, name):
    rc, _o, _e = module.run_command(["samba-tool", "group", "show", name])
    return rc == 0


def list_members(module, name):
    rc, out, _e = module.run_command(["samba-tool", "group", "listmembers", name])
    if rc != 0:
        return []
    return [line.strip() for line in out.splitlines() if line.strip()]


def main():
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type="str", required=True),
            state=dict(type="str", default="present", choices=["present", "absent"]),
            members=dict(type="list", elements="str", default=[]),
            purge_members=dict(type="bool", default=False),
        ),
        supports_check_mode=True,
    )

    p = module.params
    name = p["name"]
    changed = False
    added, removed = [], []

    if not module.get_bin_path("samba-tool"):
        module.fail_json(msg="samba-tool no encontrado. Ejecuta este modulo en el DC.")

    exists = group_exists(module, name)

    if p["state"] == "absent":
        if exists:
            if not module.check_mode:
                rc, _o, err = module.run_command(["samba-tool", "group", "delete", name])
                if rc != 0:
                    module.fail_json(msg="No se pudo eliminar el grupo: %s" % err)
            changed = True
        module.exit_json(changed=changed, added=added, removed=removed)

    # state: present
    if not exists:
        if not module.check_mode:
            rc, _o, err = module.run_command(["samba-tool", "group", "add", name])
            if rc != 0:
                module.fail_json(msg="No se pudo crear el grupo: %s" % err)
        changed = True

    current = [] if (not exists and module.check_mode) else list_members(module, name)
    desired = p["members"]

    to_add = [m for m in desired if m not in current]
    to_remove = [m for m in current if m not in desired] if p["purge_members"] else []

    for m in to_add:
        if not module.check_mode:
            rc, _o, err = module.run_command(["samba-tool", "group", "addmembers", name, m])
            if rc != 0:
                module.fail_json(msg="No se pudo anadir %s: %s" % (m, err))
        added.append(m)
        changed = True

    for m in to_remove:
        if not module.check_mode:
            rc, _o, err = module.run_command(["samba-tool", "group", "removemembers", name, m])
            if rc != 0:
                module.fail_json(msg="No se pudo quitar %s: %s" % (m, err))
        removed.append(m)
        changed = True

    module.exit_json(changed=changed, added=added, removed=removed)


if __name__ == "__main__":
    main()
