import os
import re

d = 'app/api/routers'
for f in os.listdir(d):
    if not f.endswith('.py'): continue
    filepath = os.path.join(d, f)
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # The corrupted string from the regex replacement looks like:
    # logging.error("Internal error: {e
    # raise HTTPException(status_code=500, detail="Error interno del servidor")}")
    
    # Or in some places:
    # logging.error("Internal error: {e")
    # raise HTTPException(status_code=500, detail="Error interno del servidor")
    
    # Let's just fix the trailing syntax errors blindly:
    # 1. Fix missing closing brackets in logging
    content = re.sub(r'logging\.error\("Internal error: \{e\s*\n', 'logging.error(f"Internal error: {e}")\n', content)
    content = re.sub(r'logging\.error\(f"Error interno: \{e\s*\n', 'logging.error(f"Error interno: {e}")\n', content)
    
    # 2. Fix corrupted raises
    content = re.sub(r'raise HTTPException\(status_code=500, detail="Error interno del servidor"\)\}\"\)', 'raise HTTPException(status_code=500, detail="Error interno del servidor")', content)
    content = re.sub(r'raise HTTPException\(status_code=500, detail="Error interno del servidor"\)\"\)', 'raise HTTPException(status_code=500, detail="Error interno del servidor")', content)
    content = re.sub(r'raise HTTPException\(status_code=500, detail="Error interno del servidor"\)\)', 'raise HTTPException(status_code=500, detail="Error interno del servidor")', content)
    
    # 3. Fix corrupted router paths like @router.get("/users/{user_id
    content = re.sub(r'@router\.(get|post|put|delete)\("([^"]+)(\n)', r'@router.\1("\2")\3', content)

    with open(filepath, 'w', encoding='utf-8') as file:
        file.write(content)
print('Done fixing')
