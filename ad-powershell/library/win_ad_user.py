# -*- coding: utf-8 -*-

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_ad_user
short_description: Gestiona usuarios de Active Directory con atributos POSIX
description:
  - Crea, actualiza o elimina usuarios de Active Directory con atributos POSIX
    (uidNumber, gidNumber, unixHomeDirectory, loginShell, gecos) para entornos
    AD integrados con Linux/Unix.
  - Comprueba conflictos de UID antes de crear y gestiona la pertenencia a grupos.
options:
  name:
    description: SamAccountName del usuario.
    type: str
    required: true
  state:
    description: C(present) crea o actualiza; C(absent) elimina.
    type: str
    choices: [present, absent]
    default: present
  uid_number:
    description: uidNumber POSIX. Requerido con state=present.
    type: int
  gid_number:
    description: gidNumber del grupo primario. Requerido con state=present.
    type: int
  unix_home_directory:
    description: Directorio home UNIX. Requerido con state=present.
    type: str
  login_shell:
    description: Shell de login. Requerido con state=present.
    type: str
  gecos:
    description: Campo GECOS. Requerido con state=present.
    type: str
  description:
    description: Descripcion del usuario.
    type: str
  organizational_unit:
    description: DN de la OU donde crear el usuario. Requerido con state=present.
    type: str
  password:
    description: Contrasena inicial. Usa no_log en la tarea.
    type: str
  generate_password:
    description: Si no se da C(password) y es true, genera una conforme a la politica.
    type: bool
    default: false
  password_length:
    description: Longitud de la contrasena generada.
    type: int
    default: 15
  change_password_at_logon:
    description: Forzar cambio de contrasena en el primer inicio de sesion.
    type: bool
    default: false
  password_never_expires:
    description: La contrasena no expira (util en cuentas funcionales).
    type: bool
    default: true
  update_mode:
    description:
      - C(safe) solo rellena atributos POSIX vacios y avisa si difieren.
      - C(force) sobrescribe los atributos POSIX existentes.
    type: str
    choices: [safe, force]
    default: safe
  groups:
    description: Grupos a los que asegurar la pertenencia del usuario.
    type: list
    elements: str
    default: []
  extension_attribute10:
    description: Valor opcional para extensionAttribute10 (convencion interna).
    type: str
  upn_suffix:
    description: Sufijo del UPN. Por defecto el DNSRoot del dominio.
    type: str
author:
  - homelab-automation-toolkit
'''

EXAMPLES = r'''
- name: Alta de usuario con POSIX y contrasena generada
  win_ad_user:
    name: jdoe
    uid_number: 75434
    gid_number: 10625
    unix_home_directory: /home/jdoe
    login_shell: /bin/bash
    gecos: Usuario de ejemplo
    organizational_unit: "OU=usuarios,DC=example,DC=lan"
    generate_password: true
    groups:
      - appgroup
  no_log: true

- name: Baja de usuario
  win_ad_user:
    name: jdoe
    state: absent
'''

RETURN = r'''
changed:
  description: Si hubo cambios.
  type: bool
  returned: always
msg:
  description: Mensaje descriptivo del resultado.
  type: str
  returned: always
changes:
  description: Lista de atributos POSIX modificados.
  type: list
  returned: when updated
groups_added:
  description: Grupos a los que se anadio el usuario.
  type: list
  returned: when changed
generated_password:
  description: Contrasena generada (si generate_password). Protegela con no_log.
  type: str
  returned: when generated
'''
