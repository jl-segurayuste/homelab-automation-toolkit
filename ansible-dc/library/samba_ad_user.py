#!/usr/bin/python
# -*- coding: utf-8 -*-
# Modulo Ansible para gestionar usuarios de un Samba AD DC mediante samba-tool.
# Orientado a seguridad: la contrasena se marca no_log, soporta cuentas deshabilitadas
# y "debe cambiar la contrasena en el proximo inicio de sesion".
# Licencia: MIT

from __future__ import annotations

DOCUMENTATION = r"""
---
module: samba_ad_user
short_description: Gestiona usuarios en un Samba Active Directory DC
description:
  - Crea, elimina, habilita/deshabilita usuarios de un dominio Samba AD usando samba-tool.
options:
  name:
    description: Nombre de inicio de sesion (sAMAccountName).
    required: true
    type: str
  password:
    description: Contrasena inicial (solo se usa al crear). No se registra en logs.
    type: str
  state:
    description: Estado deseado.
    choices: [present, absent]
    default: present
    type: str
  enabled:
    description: Si la cuenta debe estar habilitada.
    type: bool
    default: true
  must_change_password:
    description: Forzar cambio de contrasena en el proximo inicio de sesion.
    type: bool
    default: false
  given_name:
    description: Nombre de pila.
    type: str
  surname:
    description: Apellido.
    type: str
  mail:
    description: Direccion de correo.
    type: str
  description:
    description: Descripcion de la cuenta.
    type: str
author:
  - homelab-automation-toolkit
"""

EXAMPLES = r"""
- name: Crear usuario deshabilitado que debe cambiar la contrasena
  samba_ad_user:
    name: jdoe
    password: "{{ vault_jdoe_initial_password }}"
    given_name: Juan
    surname: Doe
    mail: jdoe@example.lan
    enabled: false
    must_change_password: true

- name: Eliminar usuario
  samba_ad_user:
    name: jdoe
    state: absent
"""

RETURN = r"""
changed:
  description: Si hubo cambios.
  type: bool
  returned: always
"""

from ansible.module_utils.basic import AnsibleModule


def user_exists(module, name):
    rc, _out, _err = module.run_command(["samba-tool", "user", "show", name])
    return rc == 0


def user_is_enabled(module, name):
    # Si 'user disable' devolveria error porque ya esta deshabilitado no es fiable;
    # se inspecciona userAccountControl via 'user show'.
    rc, out, _err = module.run_command(["samba-tool", "user", "show", name])
    if rc != 0:
        return None
    for line in out.splitlines():
        if line.lower().startswith("useraccountcontrol"):
            try:
                val = int(line.split(":")[1].strip())
                # 0x2 = ACCOUNTDISABLE
                return not bool(val & 0x2)
            except (ValueError, IndexError):
                return None
    return True


def main():
    module = AnsibleModule(
        argument_spec=dict(
            name=dict(type="str", required=True),
            password=dict(type="str", no_log=True),
            state=dict(type="str", default="present", choices=["present", "absent"]),
            enabled=dict(type="bool", default=True),
            must_change_password=dict(type="bool", default=False),
            given_name=dict(type="str"),
            surname=dict(type="str"),
            mail=dict(type="str"),
            description=dict(type="str"),
        ),
        supports_check_mode=True,
    )

    p = module.params
    name = p["name"]
    changed = False

    if not module.get_bin_path("samba-tool"):
        module.fail_json(msg="samba-tool no encontrado. Ejecuta este modulo en el DC.")

    exists = user_exists(module, name)

    # --- state: absent ---
    if p["state"] == "absent":
        if exists:
            if not module.check_mode:
                rc, _o, err = module.run_command(["samba-tool", "user", "delete", name])
                if rc != 0:
                    module.fail_json(msg="No se pudo eliminar el usuario: %s" % err)
            changed = True
        module.exit_json(changed=changed)

    # --- state: present ---
    if not exists:
        if not p.get("password"):
            module.fail_json(msg="Se requiere 'password' para crear el usuario.")
        cmd = ["samba-tool", "user", "create", name, p["password"]]
        for flag, key in (("--given-name", "given_name"),
                          ("--surname", "surname"),
                          ("--mail-address", "mail"),
                          ("--description", "description")):
            if p.get(key):
                cmd += [flag, p[key]]
        if p["must_change_password"]:
            cmd.append("--must-change-at-next-login")
        if not module.check_mode:
            rc, _o, err = module.run_command(cmd)
            if rc != 0:
                module.fail_json(msg="No se pudo crear el usuario: %s" % err)
        changed = True

    # Estado habilitado/deshabilitado (idempotente)
    current_enabled = user_is_enabled(module, name) if (exists or module.check_mode) else True
    if exists and current_enabled is not None and current_enabled != p["enabled"]:
        action = "enable" if p["enabled"] else "disable"
        if not module.check_mode:
            rc, _o, err = module.run_command(["samba-tool", "user", action, name])
            if rc != 0:
                module.fail_json(msg="No se pudo %s el usuario: %s" % (action, err))
        changed = True
    elif not exists and not p["enabled"]:
        # Recien creado pero debe quedar deshabilitado
        if not module.check_mode:
            module.run_command(["samba-tool", "user", "disable", name])
        changed = True

    module.exit_json(changed=changed)


if __name__ == "__main__":
    main()
