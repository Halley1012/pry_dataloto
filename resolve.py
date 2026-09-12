import re

with open('eterlotto_backend/app/infrastructure/repositories/jugada_repository.py', 'r', encoding='utf-8') as f:
    text = f.read()

# 1. create_jugada: Use HEAD
conflict1_regex = re.compile(r'<<<<<<< HEAD\n\s*resolved_loteria_id: Optional\[int\].*?=======\n.*?>>>>>>> dev\n', re.DOTALL)
match1 = conflict1_regex.search(text)
if match1:
    head_content = re.search(r'<<<<<<< HEAD\n(.*?)\n=======', match1.group(0), re.DOTALL).group(1)
    text = text[:match1.start()] + head_content + '\n' + text[match1.end():]

# 2. list_jugadas (with fecha): Use Dev's logic but adapt it
conflict2_regex = re.compile(r'<<<<<<< HEAD\n\s*AND \(\$2 = \'\' OR LOWER\(loteria_route\) = \$2\)\n\s*AND \(\$3::int IS NULL OR loteria_id = \$3::int\)\n\s*AND \(fecha_sorteo = \$4.*?\n=======\n.*?\n>>>>>>> dev\n', re.DOTALL)
match2 = conflict2_regex.search(text)
if match2:
    new_sql = '''                          AND (
                              ($3::int IS NOT NULL AND loteria_id = $3::int)
                              OR
                              ($3::int IS NULL AND ($2 = '' OR LOWER(loteria_route) = $2))
                          )
                          AND (fecha_sorteo = $4 OR (fecha_sorteo IS NULL AND (fecha_guardado::date = $4 OR (fecha_guardado AT TIME ZONE 'America/Bogota')::date = $4)))
                        ORDER BY COALESCE(fecha_sorteo, fecha_guardado::date) DESC, id DESC
                    """, user_id, loteria_route, loteria_id, clean_date)'''
    text = text[:match2.start()] + new_sql + '\n' + text[match2.end():]

# 3. list_jugadas (without fecha try catch block fallback): Use Dev's logic
conflict3_regex = re.compile(r'<<<<<<< HEAD\n\s*AND \(\$2 = \'\' OR LOWER\(loteria_route\) = \$2\)\n\s*AND \(\$3::int IS NULL OR loteria_id = \$3::int\)\n=======\n.*?\n>>>>>>> dev\n', re.DOTALL)
# There are two of these (exception fallback and without fecha branch)
while True:
    match3 = conflict3_regex.search(text)
    if not match3:
        break
    new_sql2 = '''                          AND (
                              ($3::int IS NOT NULL AND loteria_id = $3::int)
                              OR
                              ($3::int IS NULL AND ($2 = '' OR LOWER(loteria_route) = $2))
                          )'''
    text = text[:match3.start()] + new_sql2 + '\n' + text[match3.end():]

# 4. list_active_lotteries: Use Dev
conflict4_regex = re.compile(r'<<<<<<< HEAD\n\s*SELECT DISTINCT j\.loteria_id, LOWER\(j\.loteria_route\) AS route.*?\n=======\n(.*?)\n>>>>>>> dev\n', re.DOTALL)
match4 = conflict4_regex.search(text)
if match4:
    dev_content = match4.group(1)
    text = text[:match4.start()] + dev_content + '\n' + text[match4.end():]

# 5. list_active_lotteries_counts: Use Dev
conflict5_regex = re.compile(r'<<<<<<< HEAD\n\s*SELECT j\.loteria_id, LOWER\(j\.loteria_route\) AS route, COUNT\(\*\)::int AS count.*?\n=======\n(.*?)\n>>>>>>> dev\n', re.DOTALL)
match5 = conflict5_regex.search(text)
if match5:
    dev_content = match5.group(1)
    text = text[:match5.start()] + dev_content + '\n' + text[match5.end():]

# 6. list_active_lotteries_info: Use HEAD
conflict6_regex = re.compile(r'<<<<<<< HEAD\n\s*SELECT\n\s*j\.loteria_id,.*?\n=======\n.*?\n>>>>>>> dev\n', re.DOTALL)
match6 = conflict6_regex.search(text)
if match6:
    head_content = re.search(r'<<<<<<< HEAD\n(.*?)\n=======', match6.group(0), re.DOTALL).group(1)
    text = text[:match6.start()] + head_content + '\n' + text[match6.end():]

conflict7_regex = re.compile(r'<<<<<<< HEAD\n\s*for r in rows if r\[\'loteria_id\'\] is not None\n=======\n\s*for r in rows if \(r\[\'loteria_id\'\] or r\[\'route\'\]\)\n>>>>>>> dev\n', re.DOTALL)
match7 = conflict7_regex.search(text)
if match7:
    text = text[:match7.start()] + '                for r in rows if r[\'loteria_id\'] is not None\n' + text[match7.end():]

with open('eterlotto_backend/app/infrastructure/repositories/jugada_repository.py', 'w', encoding='utf-8') as f:
    f.write(text)
