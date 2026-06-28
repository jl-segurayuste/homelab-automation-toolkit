# -*- coding: utf-8 -*-

# Copyright: (c) 2026, homelab-automation-toolkit
# MIT License

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: win_ad_random_password
short_description: Genera una contrasena aleatoria conforme a la politica de AD
description:
  - Genera una contrasena con mayuscula, minuscula, numero y caracter especial,
    de longitud configurable, que no contiene el nombre de usuario.
  - No realiza cambios (changed siempre false). Protege la salida con no_log.
options:
  username:
    description: Usuario; la contrasena no lo contendra.
    type: str
    required: true
  length:
    description: Longitud de la contrasena (8-128).
    type: int
    default: 15
author:
  - homelab-automation-toolkit
'''

EXAMPLES = r'''
- name: Generar contrasena para un alta
  win_ad_random_password:
    username: jdoe
    length: 16
  register: pw
  no_log: true
'''

RETURN = r'''
password:
  description: Contrasena generada. Protegela con no_log.
  type: str
  returned: success
attempts:
  description: Intentos necesarios.
  type: int
  returned: success
'''
