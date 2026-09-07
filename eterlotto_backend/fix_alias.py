
path = "app/infrastructure/repositories/jugada_repository.py"
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace duplicated alias logic
alias_logic = 'alias_loteria = "miloto" if loteria_nombre == "mloto" else ("baloto" if loteria_nombre == "bloto" else ("colorloto" if loteria_nombre == "cloto" else loteria_nombre))'
alias_logic_clean = 'alias_loteria = "miloto" if clean_tipo == "mloto" else ("baloto" if clean_tipo == "bloto" else ("colorloto" if clean_tipo == "cloto" else clean_tipo))'

helper_func = '''
    def _get_alias(self, name: str) -> str:
        mapping = {"mloto": "miloto", "bloto": "baloto", "cloto": "colorloto"}
        return mapping.get(name, name)
'''

# Add helper func inside class if not exists
if "_get_alias" not in content:
    content = content.replace("    def get_predicciones_historico_completas(", helper_func + "\n    def get_predicciones_historico_completas(")

content = content.replace(alias_logic, 'alias_loteria = self._get_alias(loteria_nombre)')
content = content.replace(alias_logic_clean, 'alias_loteria = self._get_alias(clean_tipo)')

with open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("Fix applied to jugada_repository.py")
