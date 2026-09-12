import asyncio
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from httpx import AsyncClient, ASGITransport
from main import app, lifespan

async def run_tests():
    async with lifespan(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            print("--- Testing /mis_loterias_info?user_id=83 ---")
            resp = await client.get("/mis_loterias_info?user_id=83")
            assert resp.status_code == 200, f"Status: {resp.status_code}, Body: {resp.text}"
            data = resp.json()
            print("mis_loterias_info response:", data)
            # Should contain key "36" (France)
            assert "36" in data, f"Expected key '36' in info: {data}"
            assert data["36"]["route"] == "euromillones", f"Expected route 'euromillones', got {data['36']['route']}"
            assert data["36"]["pais_id"] == 36, f"Expected pais_id 36, got {data['36']['pais_id']}"
            # Must NOT contain key "25" (Spain) or "40" (Ireland)
            assert "25" not in data, f"Key '25' (Spain) should not be in info: {data}"
            assert "40" not in data, f"Key '40' (Ireland) should not be in info: {data}"
            assert "euromillones" not in data, f"Keys should be loteria_id strings, not routes: {data}"
            print("PASS: /mis_loterias_info returns canonical loteria_id key '36' only!")

            print("\n--- Testing /mis_loterias_activas?user_id=83 ---")
            resp_activas = await client.get("/mis_loterias_activas?user_id=83")
            assert resp_activas.status_code == 200
            activas = resp_activas.json()
            print("mis_loterias_activas response:", activas)
            assert "36" in activas, f"Expected '36' in activas: {activas}"
            assert "25" not in activas, f"'25' should not be in activas: {activas}"
            print("PASS: /mis_loterias returns canonical loteria_id '36' only!")

            print("\n--- Testing /jugadas_euromillones filtering by loteria_id ---")
            resp_francia = await client.get("/jugadas_euromillones?user_id=83&loteria_id=36")
            assert resp_francia.status_code == 200, f"Status: {resp_francia.status_code}, Body: {resp_francia.text}"
            jugadas_fr = resp_francia.json()
            print(f"France (loteria_id=36) plays count: {len(jugadas_fr)}")
            assert len(jugadas_fr) >= 1
            assert all(j.get("loteria_id") == 36 for j in jugadas_fr)

            resp_espana = await client.get("/jugadas_euromillones?user_id=83&loteria_id=25")
            assert resp_espana.status_code == 200, f"Status: {resp_espana.status_code}, Body: {resp_espana.text}"
            jugadas_es = resp_espana.json()
            print(f"Spain (loteria_id=25) plays count: {len(jugadas_es)}")
            assert len(jugadas_es) == 0, f"Expected 0 plays for Spain, got {len(jugadas_es)}"
            print("PASS: /jugadas_euromillones strictly separates plays by loteria_id!")

            print("\n--- Testing unified /jugadas endpoint with loteria_id ---")
            resp_unif_fr = await client.get("/jugadas?loteria=euromillones&user_id=83&loteria_id=36")
            assert resp_unif_fr.status_code == 200
            assert len(resp_unif_fr.json()) >= 1

            resp_unif_es = await client.get("/jugadas?loteria=euromillones&user_id=83&loteria_id=25")
            assert resp_unif_es.status_code == 200
            assert len(resp_unif_es.json()) == 0
            print("PASS: unified /jugadas strictly separates plays by loteria_id!")

            print("\n--- Testing consistency validation (mismatched loteria_id + route) ---")
            resp_bad = await client.post(
                "/jugadas",
                json={
                    "user_id": "83",
                    "loteria_route": "melate",
                    "loteria_id": 36,  # 36 is euromillones, not melate
                    "numeros": [1, 2, 3, 4, 5],
                }
            )
            print(f"Mismatched response: {resp_bad.status_code} - {resp_bad.text}")
            assert resp_bad.status_code == 400, f"Expected 400, got {resp_bad.status_code}"
            print("PASS: Mismatched route and loteria_id correctly rejected with 400!")

            print("\n--- Testing ambiguity validation (shared route without loteria_id) ---")
            resp_ambiguous = await client.post(
                "/jugadas",
                json={
                    "user_id": "83",
                    "loteria_route": "euromillones",  # ambiguous: shared across France, Spain, Ireland, etc.
                    "numeros": [1, 2, 3, 4, 5],
                }
            )
            print(f"Ambiguous response: {resp_ambiguous.status_code} - {resp_ambiguous.text}")
            assert resp_ambiguous.status_code == 400, f"Expected 400, got {resp_ambiguous.status_code}"
            assert "ambigua" in resp_ambiguous.text or "loteria_id" in resp_ambiguous.text
            print("PASS: Ambiguous route without loteria_id correctly rejected with 400!")

            print("\n--- Testing valid creation with loteria_id ---")
            resp_good = await client.post(
                "/jugadas",
                json={
                    "user_id": "83",
                    "loteria_route": "euromillones",
                    "loteria_id": 36,
                    "numeros": [7, 14, 21, 28, 35, 1, 2],
                    "fecha_sorteo": "2026-09-15"
                }
            )
            print(f"Valid creation response: {resp_good.status_code} - {resp_good.text}")
            assert resp_good.status_code == 200, f"Expected 200, got {resp_good.status_code}"
            created = resp_good.json()
            assert created["loteria_id"] == 36
            print("PASS: Valid creation with loteria_id=36 succeeded!")

            # Clean up the test play
            await client.delete(f"/jugadas/{created['id']}?user_id=83&loteria=euromillones&loteria_id=36")
            print("Cleaned up test play successfully.")

            print("\n=== ALL CANONICAL LOTERIA_ID VERIFICATIONS SUCCEEDED! ===")

if __name__ == "__main__":
    asyncio.run(run_tests())
