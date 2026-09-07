import os

def fix_exceptions(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # If file doesn't have logging imported, add it
    if 'import logging' not in content:
        content = "import logging\n" + content

    # Replace `except Exception:` with `except Exception as e:` and a logger
    # This regex is a bit simplistic, but we can do it safer by iterating lines
    lines = content.split('\n')
    new_lines = []
    
    for i, line in enumerate(lines):
        if line.strip() == "except Exception:":
            indent = line[:len(line) - len(line.lstrip())]
            new_lines.append(f"{indent}except Exception as e:")
            new_lines.append(f"{indent}    logging.getLogger(__name__).error(f'Error capturado: {{e}}')")
            
            # If the next line is `pass`, we can skip it, but keeping it is fine
        elif line.strip() == "except Exception as e:":
            # Let's see if the next line is `pass`
            new_lines.append(line)
            if i + 1 < len(lines) and lines[i+1].strip() == "pass":
                indent = line[:len(line) - len(line.lstrip())]
                new_lines.append(f"{indent}    logging.getLogger(__name__).error(f'Error silenciado: {{e}}')")
        else:
            new_lines.append(line)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(new_lines))

for root, _, files in os.walk('app/infrastructure/repositories'):
    for file in files:
        if file.endswith('.py'):
            fix_exceptions(os.path.join(root, file))

fix_exceptions('app/infrastructure/db_connection.py')
print("Excepciones arregladas en repositorios.")
