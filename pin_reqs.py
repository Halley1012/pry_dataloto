import subprocess
import re

out = subprocess.check_output([r'd:\pry_dataloto\.venv\Scripts\pip.exe', 'freeze'], text=True)
versions = {}
for line in out.splitlines():
    if '==' in line:
        k, v = line.split('==', 1)
        versions[k.lower()] = v.strip()

req_file = r'd:\pry_dataloto\eterlotto_backend\requirements.txt'
with open(req_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    clean = line.split('#')[0].strip()
    if clean and not clean.startswith('-'):
        match = re.match(r'^([a-zA-Z0-9_\-]+)', clean)
        if match:
            pkg = match.group(1).lower()
            if pkg in versions:
                new_lines.append(f"{clean.split('<')[0].split('=')[0].split('>')[0]}=={versions[pkg]}\n")
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(req_file, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
print('Done!')
