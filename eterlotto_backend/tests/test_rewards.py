"""Reward regressions with mocked connections; never contacts a database."""
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch
from urllib.parse import urlencode
from uuid import uuid4
import base64

os.environ.setdefault("SECRET_KEY", "rewards-unit-test-only")

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import HTTPException

from app.infrastructure import reward_repository as repo
from app.infrastructure import reward_ssv as ssv
from app.api.routers import rewards as routes


class RewardRepositoryTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.connection = MagicMock()
        self.connection.fetchval = AsyncMock(side_effect=[42, None])
        self.connection.fetchrow = AsyncMock()
        self.connection.execute = AsyncMock()
        pool = MagicMock()
        pool.acquire.return_value.__aenter__.return_value = self.connection
        self.connection.transaction.return_value.__aenter__.return_value = None
        patcher = patch.object(repo, "get_pool", return_value=pool)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.now = datetime.now(timezone.utc)
        self.session_id = uuid4()
        self.session = {
            "id": self.session_id, "user_id": 42, "origen": "regalo",
            "funcion_clave": None, "estado": "pendiente",
            "creada_en": self.now - timedelta(minutes=2),
            "expira_en": self.now + timedelta(hours=23),
            "admob_transaction_id": None,
        }

    async def credit(self):
        return await repo.credit_verified_video(
            self.session_id, 42, "transaction-12345", "4124989907", self.now,
        )

    async def test_seventh_verified_video_creates_available_pass_without_activation(self):
        self.connection.fetchrow.side_effect = [
            self.session, {"id": uuid4(), "videos_verificados": 6},
        ]
        result = await self.credit()
        self.assertTrue(result["pass_earned"])
        queries = [call.args[0] for call in self.connection.execute.await_args_list]
        self.assertTrue(any("INSERT INTO public.recompensa_pases" in q and
                            "'disponible'" in q for q in queries))
        self.assertFalse(any("SET estado='activo'" in q for q in queries))
        self.assertFalse(any("INSERT INTO public.recompensa_desbloqueos" in q for q in queries))

    async def test_feature_video_credits_and_unlocks_only_that_feature(self):
        self.session.update(origen="funcion", funcion_clave="statistics")
        self.connection.fetchrow.side_effect = [
            self.session, {"id": uuid4(), "videos_verificados": 1},
        ]
        result = await self.credit()
        self.assertEqual(result["videos_completed"], 2)
        unlocks = [call for call in self.connection.execute.await_args_list
                   if "INSERT INTO public.recompensa_desbloqueos" in call.args[0]]
        self.assertEqual(len(unlocks), 1)
        self.assertIn("INTERVAL '30 minutes'", unlocks[0].args[0])
        self.assertEqual(unlocks[0].args[1:], (42, "statistics", self.session_id))

    async def test_duplicate_callback_does_not_credit_twice(self):
        self.session.update(estado="verificada", admob_transaction_id="transaction-12345")
        self.connection.fetchrow.return_value = self.session
        self.assertFalse((await self.credit())["credited"])
        self.connection.execute.assert_not_awaited()

    async def test_different_transaction_cannot_reuse_session(self):
        self.session.update(estado="verificada", admob_transaction_id="other-transaction")
        self.connection.fetchrow.return_value = self.session
        with self.assertRaises(repo.RewardRejected):
            await self.credit()
        self.connection.execute.assert_not_awaited()

    async def test_session_from_another_user_cannot_be_credited(self):
        self.session["user_id"] = 99
        self.connection.fetchrow.return_value = self.session
        with self.assertRaises(repo.RewardRejected):
            await self.credit()
        self.connection.execute.assert_not_awaited()

    async def test_session_lookup_is_scoped_to_authenticated_user(self):
        self.connection.fetchrow.return_value = None
        self.assertIsNone(await repo.get_video_session_status(42, self.session_id))
        self.assertEqual(self.connection.fetchrow.await_args.args[1:], (self.session_id, 42))

    async def test_expired_pending_session_is_not_verified(self):
        self.connection.fetchrow.return_value = {"estado": "pendiente", "expired": True}
        result = await repo.get_video_session_status(42, self.session_id)
        self.assertFalse(result["verified"])
        self.assertEqual(result["state"], "vencida")

    async def test_late_delivery_of_an_earned_reward_remains_valid(self):
        # Delivery can arrive after expiry if the signed earn time was valid.
        self.session.update(creada_en=self.now - timedelta(days=2),
                            expira_en=self.now - timedelta(days=1))
        earned_at = self.now - timedelta(days=1, hours=1)
        self.connection.fetchrow.side_effect = [
            self.session, {"id": uuid4(), "videos_verificados": 0},
        ]
        result = await repo.credit_verified_video(
            self.session_id, 42, "transaction-12345", "4124989907", earned_at,
        )
        self.assertTrue(result["credited"])


class SsvSignatureTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.key = ec.generate_private_key(ec.SECP256R1())

    def callback(self, unit="4124989907"):
        query = urlencode({
            "ad_unit": unit, "custom_data": str(uuid4()),
            "timestamp": int(datetime.now(timezone.utc).timestamp() * 1000),
            "transaction_id": "transaction-12345", "user_id": 42,
        }).encode()
        signature = self.key.sign(query, ec.ECDSA(hashes.SHA256()))
        return query + b"&signature=" + base64.urlsafe_b64encode(signature).rstrip(b"=") + b"&key_id=7"

    async def test_valid_signature_accepts_suffix_and_full_ad_unit_id(self):
        with patch.object(ssv, "_fetch_google_keys", AsyncMock(return_value={7: self.key.public_key()})):
            for unit in ["4124989907", "ca-app-pub-9637733995937134/4124989907"]:
                result = await ssv.verify_admob_callback(self.callback(unit), {"4124989907"})
                self.assertEqual(result["user_id"], 42)
                self.assertEqual(result["ad_unit"], "4124989907")

    async def test_modified_signed_user_id_is_rejected(self):
        raw = self.callback().replace(b"user_id=42", b"user_id=99")
        with patch.object(ssv, "_fetch_google_keys", AsyncMock(return_value={7: self.key.public_key()})):
            with self.assertRaises(HTTPException) as error:
                await ssv.verify_admob_callback(raw, {"4124989907"})
        self.assertEqual(error.exception.status_code, 403)

    async def test_other_unit_is_rejected_even_with_a_valid_signature(self):
        with patch.object(ssv, "_fetch_google_keys", AsyncMock(return_value={7: self.key.public_key()})):
            with self.assertRaises(HTTPException) as error:
                await ssv.verify_admob_callback(self.callback("not-allowed"), {"4124989907"})
        self.assertEqual(error.exception.status_code, 403)


class RewardRouteTests(unittest.IsolatedAsyncioTestCase):
    async def test_demo_ad_is_rejected_before_creating_session(self):
        with patch.object(routes, "start_video_session", AsyncMock()) as start:
            with self.assertRaises(HTTPException) as error:
                await routes.video_session(routes.RewardVideoSessionRequest(
                    origen="regalo", ad_unit_id="ca-app-pub-3940256099942544/5224354917",
                ), {"user_id": "42"})
            self.assertEqual(error.exception.detail, "SSV_DEMO_AD_UNIT")
            start.assert_not_awaited()

    async def test_missing_ssv_configuration_rejects_even_an_older_client(self):
        with patch.dict(os.environ, {"REWARDS_SSV_AD_UNIT_IDS": ""}):
            with patch.object(routes, "start_video_session", AsyncMock()) as start:
                with self.assertRaises(HTTPException) as error:
                    await routes.video_session(
                        routes.RewardVideoSessionRequest(origen="regalo"), {"user_id": "42"},
                    )
                self.assertEqual(error.exception.status_code, 503)
                start.assert_not_awaited()

    async def test_configured_unit_creates_session_for_authenticated_account(self):
        with patch.dict(os.environ, {"REWARDS_SSV_AD_UNIT_IDS": "4124989907"}):
            with patch.object(routes, "start_video_session", AsyncMock(return_value={"session_id": "new"})) as start:
                result = await routes.video_session(routes.RewardVideoSessionRequest(
                    origen="funcion", funcion_clave="statistics",
                    ad_unit_id="ca-app-pub-9637733995937134/4124989907",
                ), {"user_id": "42"})
                self.assertEqual(result["session_id"], "new")
                start.assert_awaited_once_with(42, "funcion", "statistics")

if __name__ == "__main__":
    unittest.main()
