from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.exceptions import PyJWTError

from spacedrift_api.auth import OIDCVerifier

ISSUER = "https://identity.example.test/"
AUDIENCE = "spacedrift-api"


@pytest.fixture
def verifier() -> tuple[OIDCVerifier, object]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    class FakeJwksClient:
        def get_signing_key_from_jwt(self, token: str) -> SimpleNamespace:
            return SimpleNamespace(key=public_key)

    return OIDCVerifier(issuer=ISSUER, audience=AUDIENCE, jwks_client=FakeJwksClient()), private_key


def token_for(private_key: object, **changes: object) -> str:
    now = datetime.now(timezone.utc)
    claims: dict[str, object] = {
        "sub": "synthetic-user-1",
        "iss": ISSUER,
        "aud": AUDIENCE,
        "iat": now,
        "exp": now + timedelta(minutes=5),
    }
    claims.update(changes)
    return jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": "test-key"})


def test_verifies_signature_issuer_audience_and_subject(verifier: tuple[OIDCVerifier, object]) -> None:
    instance, private_key = verifier
    claims = instance.verify(token_for(private_key))

    assert claims["sub"] == "synthetic-user-1"


@pytest.mark.parametrize(
    "changes",
    [
        {"iss": "https://wrong.example.test/"},
        {"aud": "another-api"},
        {"sub": ""},
        {"exp": datetime.now(timezone.utc) - timedelta(minutes=1)},
    ],
)
def test_rejects_invalid_required_claims(
    verifier: tuple[OIDCVerifier, object], changes: dict[str, object]
) -> None:
    instance, private_key = verifier
    with pytest.raises(PyJWTError):
        instance.verify(token_for(private_key, **changes))
