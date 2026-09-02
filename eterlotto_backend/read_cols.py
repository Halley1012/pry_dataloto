import json
with open('schema_dump.json', 'r') as f:
    schema = json.load(f)

for col in schema['user_subscriptions']['columns']:
    print(f"{col['column_name']} ({col['data_type']}) - null: {col['is_nullable']} - def: {col['column_default']}")
