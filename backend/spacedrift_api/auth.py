from dataclasses import dataclass
from typing import Any

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientError, PyJWTError

from spacedrift_api.settings import settings

bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class OIDCVerifier:
    issuer: str
    audience: str
    jwks_client: Any

    def verify(self, token: str) -> dict[str, Any]:
        signing_key = self.jwks_client.get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            signing_key,
            algorithms=["RS256"],
            audience=self.audience,
            issuer=self.issuer,
            options={"require": ["exp", "iat", "sub"]},
        )
        if not isinstance(claims.get("sub"), str) or not claims["sub"].strip():
            raise PyJWTError("subject_missing")
        return claims


def verifier_from_settings() -> OIDCVerifier:
    if not settings.oidc_issuer or not settings.oidc_audience or not settings.oidc_jwks_url:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="identity_provider_not_configured",
        )
    return OIDCVerifier(
        issuer=settings.oidc_issuer,
        audience=settings.oidc_audience,
        jwks_client=PyJWKClient(settings.oidc_jwks_url),
    )


def current_identity(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> dict[str, Any]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="authentication_required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        return verifier_from_settings().verify(credentials.credentials)
    except HTTPException:
        raise
    except (PyJWTError, PyJWKClientError, ValueError, OSError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid_access_token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
