import requests
from bs4 import BeautifulSoup

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'es-ES,es;q=0.9,pt;q=0.8,en;q=0.7',
    'Referer': 'https://www.megasena.com/es/resultados'
}

s = requests.Session()
s.headers.update(headers)

# Test Portuguese vs Spanish URLs
for url in [
    'https://www.megasena.com/resultados',
    'https://www.megasena.com/es/resultados',
    'https://www.megasena.com/en/results',
]:
    r = s.get(url, timeout=10)
    print(f"{url} -> status={r.status_code}")
    soup = BeautifulSoup(r.text, 'html.parser')
    tables = soup.find_all('table', class_='_results')
    print(f"  tables count: {len(tables)}")
    if len(tables) > 1:
        print(f"  table 1 rows: {len(tables[1].find_all('tr'))}")
