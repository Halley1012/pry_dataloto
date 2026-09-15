import json
with open('schema_dump.json', 'r') as f:
    schema = json.load(f)

for table, data in schema.items():
    if 'error' in data:
        print(f'\n=== TABLE: {table} ===')
        print('  ERROR: ', data['error'])
        continue
    
    count = data.get('row_count', 0)
    print(f'\n=== TABLE: {table} (Row Count: {count}) ===')
    
    print('  FOREIGN KEYS:')
    if not data['foreign_keys']:
        print('    None')
    else:
        for fk in data['foreign_keys']:
            print(f'    {fk["column_name"]} -> {fk["foreign_table_name"]}({fk["foreign_column_name"]}) ON DELETE {fk["delete_rule"]}')
            
    print('  CONSTRAINTS:')
    if not data['constraints']:
        print('    None')
    else:
        for con in data['constraints']:
            print(f'    {con["name"]}: {con["def"]}')
            
    print('  INDEXES:')
    if not data['indexes']:
        print('    None')
    else:
        for idx in data['indexes']:
            print(f'    {idx["indexname"]}')
