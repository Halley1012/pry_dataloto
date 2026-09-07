import re

def fix_use_cases():
    path = "app/application/subscription_use_cases.py"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Import config
    if "from app.core import config" not in content:
        content = content.replace("from app.domain.ports import", "from app.core import config\nfrom app.domain.ports import")

    content = re.sub(r'ALLOWED_PRODUCTS\s*=\s*\{[^}]*\}\n', '', content)
    content = content.replace('self.ALLOWED_PRODUCTS', 'config.ALLOWED_PRODUCTS')
    content = content.replace('"com.lumieter.eterlotto"', 'config.PACKAGE_NAME')
    content = content.replace('"eterlotto_monthly_sub"', 'list(config.ALLOWED_PRODUCTS)[0]') # or we could just leave it or handle it better. Wait, we want to replace fallback to default product.
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

def fix_metadata():
    path = "app/api/routers/metadata.py"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    if "from app.core import config" not in content:
        content = "from app.core import config\n" + content
        
    content = content.replace(
        '"store_url_android": "https://play.google.com/store/apps/details?id=com.lumieter.eterlotto"',
        'f"store_url_android": "https://play.google.com/store/apps/details?id={config.PACKAGE_NAME}"'
    )
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

fix_use_cases()
fix_metadata()
print("Fixed hardcoded values.")
