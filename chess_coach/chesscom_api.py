from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import requests

BASE_URL = "https://api.chess.com/pub/player"
DEFAULT_HEADERS = {
    "User-Agent": "ChessCoach/1.0 (local app)",
    "Accept": "application/json",
}


class ChessComAPIError(RuntimeError):
    """Raised when Chess.com data cannot be fetched."""


def _get_json(url: str) -> dict[str, Any]:
    response = requests.get(url, headers=DEFAULT_HEADERS, timeout=20)

    if response.status_code == 404:
        raise ChessComAPIError("Chess.com username not found.")

    response.raise_for_status()
    return response.json()


def fetch_recent_games(username: str, max_games: int = 25) -> list[dict[str, Any]]:
    username = username.strip().lower()
    if not username:
        raise ChessComAPIError("Please enter a Chess.com username.")

    archives_url = f"{BASE_URL}/{username}/games/archives"
    archives_data = _get_json(archives_url)
    archives = list(reversed(archives_data.get("archives", [])))

    if not archives:
        return []

    games: list[dict[str, Any]] = []
    for archive_url in archives:
        archive_data = _get_json(archive_url)
        monthly_games = archive_data.get("games", [])
        games.extend(monthly_games)
        if len(games) >= max_games:
            break

    public_games = [game for game in games if game.get("pgn")]
    public_games.sort(key=lambda item: item.get("end_time", 0), reverse=True)
    return public_games[:max_games]


def fetch_games_since(
    username: str,
    since: datetime | None,
    max_games: int = 500,
) -> list[dict[str, Any]]:
    username = username.strip().lower()
    if not username:
        raise ChessComAPIError("Please enter a Chess.com username.")

    since_ts = int(since.replace(tzinfo=timezone.utc).timestamp()) if since else 0
    archives_url = f"{BASE_URL}/{username}/games/archives"
    archives_data = _get_json(archives_url)
    archives = list(reversed(archives_data.get("archives", [])))

    if not archives:
        return []

    games: list[dict[str, Any]] = []
    for archive_url in archives:
        archive_data = _get_json(archive_url)
        monthly_games = archive_data.get("games", [])

        if since_ts:
            monthly_games = [
                game for game in monthly_games if int(game.get("end_time", 0) or 0) >= since_ts
            ]

        games.extend(monthly_games)

        if len(games) >= max_games:
            break

    public_games = [game for game in games if game.get("pgn")]
    public_games.sort(key=lambda item: item.get("end_time", 0), reverse=True)
    return public_games[:max_games]
