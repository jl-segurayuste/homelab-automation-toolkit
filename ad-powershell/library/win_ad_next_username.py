# -*- coding: utf-8 -*-

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_ad_next_username
short_description: Calcula el siguiente SamAccountName libre en AD
description:
  - Dado un nombre base, propone el siguiente SamAccountName disponible usando
    sufijo numerico 01-99 y, agotado, alfabetico a-z.
  - Solo lectura (changed siempre false).
options:
  username:
    description: Nombre base o existente (SamAccountName).
    type: str
    required: true
author:
  - homelab-automation-toolkit
'''

EXAMPLES = r'''
- name: Calcular siguiente usuario libre
  win_ad_next_username:
    username: jdoe
  register: nextu

- debug:
    var: nextu.next_username
'''

RETURN = r'''
found:
  description: Si se encontro un candidato.
  type: bool
  returned: always
next_username:
  description: Siguiente SamAccountName disponible.
  type: str
  returned: success
'''
