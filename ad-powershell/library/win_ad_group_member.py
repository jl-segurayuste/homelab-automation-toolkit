# -*- coding: utf-8 -*-

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_ad_group_member
short_description: Gestiona la pertenencia de un usuario a grupos de AD
description:
  - Anade (state=present) o retira (state=absent) un usuario de uno o varios
    grupos de Active Directory de forma idempotente.
  - El estado C(absent) sobre varios grupos es util en procesos de baja/offboarding.
options:
  user:
    description: SamAccountName del usuario.
    type: str
    required: true
  groups:
    description: Lista de grupos (SamAccountName).
    type: list
    elements: str
    required: true
  state:
    description: C(present) anade a los grupos; C(absent) los retira.
    type: str
    choices: [present, absent]
    default: present
author:
  - homelab-automation-toolkit
'''

EXAMPLES = r'''
- name: Anadir usuario a grupos
  win_ad_group_member:
    user: jdoe
    groups: [appgroup, appgroup01]
    state: present

- name: Offboarding - retirar de todos los grupos de aplicacion
  win_ad_group_member:
    user: jdoe
    groups: [appgroup, appgroup01, vpnusers]
    state: absent
'''

RETURN = r'''
changed:
  description: Si hubo cambios.
  type: bool
  returned: always
groups_added:
  description: Grupos a los que se anadio el usuario.
  type: list
  returned: when state=present
groups_removed:
  description: Grupos de los que se retiro al usuario.
  type: list
  returned: when state=absent
errors:
  description: Errores por grupo, si los hubo.
  type: list
  returned: on failure
'''
