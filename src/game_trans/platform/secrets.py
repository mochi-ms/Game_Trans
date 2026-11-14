"""API key storage in Windows Credential Manager (via keyring). Never written to disk/config/logs."""

from __future__ import annotations

import keyring
import keyring.errors

SERVICE = "GameTrans"
ACCOUNT = "gemini_api_key"


def get_api_key() -> str | None:
    return keyring.get_password(SERVICE, ACCOUNT)


def set_api_key(key: str) -> None:
    keyring.set_password(SERVICE, ACCOUNT, key.strip())


def delete_api_key() -> None:
    try:
        keyring.delete_password(SERVICE, ACCOUNT)
    except keyring.errors.PasswordDeleteError:
        pass


def mask(key: str | None) -> str:
    if not key:
        return "(없음)"
    return f"{key[:4]}{'•' * 16}{key[-3:]}"
