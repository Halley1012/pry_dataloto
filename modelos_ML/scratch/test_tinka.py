import sys
import requests
import re
from bs4 import BeautifulSoup

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'es-PE,es-419;q=0.9,es;q=0.8,en;q=0.7',
}

urls_to_test = [
    "https://www.latinka.com.pe/p/juega-tinka.html",
    "https://www.latinka.com.pe/p/resultados-tinka.html",
    "https://www.combinacionganadora.com/pe/la-tinka/resultados/",
    "https://www.intralot.com.pe/",
]

for url in urls_to_test:
    try:
        r = requests.get(url, headers=headers, timeout=10, verify=False)
        print(f"\nURL: {url} -> status={r.status_code}, len={len(r.text)}")
        soup = BeautifulSoup(r.text, 'html.parser')
        print("  Title:", soup.title.string if soup.title else "No title")
        
        # Check for scripts or API endpoints or JSON-LD
        scripts = soup.find_all('script')
        api_endpoints = []
        for s in scripts:
            if s.string:
                matches = re.findall(r'https?://[^\s"\'\<\>]+(?:api|sorteo|resultado|draw|game)[^\s"\'\<\>]*', s.string, re.IGNORECASE)
                api_endpoints.extend(matches)
        if api_endpoints:
            print("  Found API matches in scripts:", api_endpoints[:5])
            
        # Check text keywords like 'Pozo', 'Millones', 'S/', 'Boliyapa'
        text_sample = soup.get_text()
        pozo_match = re.findall(r'(?:Pozo|Jackpot|Estimado)[^\n\r]{0,60}', text_sample, re.IGNORECASE)
        if pozo_match:
            print("  Pozo sample:", pozo_match[:3])

    except Exception as e:
        print(f"Error {url}: {e}")
