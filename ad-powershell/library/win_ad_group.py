# -*- coding: utf-8 -*-

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_ad_group
short_description: Gestiona grupos de Active Directory con gidNumber (POSIX)
description:
  - Crea o elimina grupos de AD con gidNumber para entornos integrados con Linux.
  - No sobrescribe un gidNumber existente distinto del solicitado (prevencion de
    error humano); solo lo anade si el grupo no lo tiene.
  - Comprueba que el GID no este en uso por otro grupo antes de crear.
options:
  name:
    description: SamAccountName del grupo.
    type: str
    required: true
  state:
    description: C(present) crea o ajusta; C(absent) elimina.
    type: str
    choices: [present, absent]
    default: present
  gid_number:
    description: gidNumber POSIX. Requerido con state=present.
    type: int
  organizational_unit:
    description: DN de la OU donde crear el grupo. Requerido con state=present.
    type: str
  description:
    description: Descripcion del grupo.
    type: str
  scope:
    description: Ambito del grupo.
    type: str
    choices: [Global, Universal, DomainLocal]
    default: Global
  category:
    description: Categoria del grupo.
    type: str
    choices: [Security, Distribution]
    default: Security
author:
  - homelab-automation-toolkit
'''

EXAMPLES = r'''
- name: Crear grupo funcional con GID
  win_ad_group:
    name: appgroup
    gid_number: 10625
    organizational_unit: "OU=grupos,DC=example,DC=lan"
    description: Grupo funcional de ejemplo

- name: Eliminar grupo
  win_ad_group:
    name: appgroup
    state: absent
'''

RETURN = r'''
changed:
  description: Si hubo cambios.
  type: bool
  returned: always
action:
  description: Accion realizada (created, updated, none).
  type: str
  returned: when state=present
msg:
  description: Mensaje descriptivo del resultado.
  type: str
  returned: always
'''
