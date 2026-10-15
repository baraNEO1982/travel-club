#!/usr/bin/env python3
# coding: utf-8
"""Enter email settings locally; never save or print the API key."""
import getpass
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

project = Path(__file__).resolve().parent.parent
node = shutil.which('node')
if not node:
    candidate = Path.home() / '.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node'
    if candidate.is_file():
        node = str(candidate)
if not node:
    sys.exit('Не найден Node.js. Откройте этот проект в чате для настройки.')
print('Почта для писем клуба. Карта и платный тариф не нужны.')
print('Адрес отправителя должен быть подтверждён в Brevo.')
sender = input('Email отправителя: ').strip()
if '@' not in sender or any(c in sender for c in '\r\n<>'):
    sys.exit('Проверьте адрес отправителя.')
key = getpass.getpass('API-ключ Brevo (ввод скрыт): ').strip()
if not key:
    sys.exit('Ключ не введён. Изменений нет.')
environment = dict(os.environ)
environment['PATH'] = str(Path(node).parent) + os.pathsep + environment.get('PATH', '')
result = subprocess.run([node, 'node_modules/wrangler/bin/wrangler.js', 'secret', 'bulk', '--config', 'wrangler.club.jsonc'], cwd=project, env=environment, input=json.dumps({'BREVO_API_KEY': key, 'EMAIL_FROM': sender}), text=True)
sys.exit(result.returncode)
