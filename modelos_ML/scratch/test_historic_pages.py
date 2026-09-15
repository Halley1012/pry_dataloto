import requests
from bs4 import BeautifulSoup
import re

headers = {'User-Agent': 'Mozilla/5.0'}

for num in [3000, 2900, 2800, 2700, 2600]:
    url = f"https://www.megasena.com/es/resultados/{num}"
    r = requests.get(url, headers=headers, timeout=5)
    soup = BeautifulSoup(r.text, 'html.parser')
    title = soup.title.string if soup.title else ""
    balls = [b.get_text(strip=True) for b in soup.find_all('li', class_='ball')]
    print(f"Draw {num}: status={r.status_code}, title='{title}', balls={balls}")
