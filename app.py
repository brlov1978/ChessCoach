from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

from chess_coach.chesscom_api import ChessComAPIError, fetch_recent_games
from chess_coach.puzzle_generator import generate_puzzles

ROOT_DIR = Path(__file__).resolve().parent
FRONTEND_BUILD_DIR = ROOT_DIR / "flutter_app" / "build" / "web"
NO_CACHE_FILES = {
    "index.html",
    "flutter_service_worker.js",
    "manifest.json",
    "version.json",
}


def _coerce_int(value: Any, default: int, *, min_value: int, max_value: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(min_value, min(max_value, parsed))


def _serialize_puzzle(puzzle: Any) -> dict[str, Any]:
    if hasattr(puzzle, "to_dict"):
        return puzzle.to_dict()
    return dict(puzzle)


def _send_frontend_file(path: str):
    response = send_from_directory(FRONTEND_BUILD_DIR, path)
    if path in NO_CACHE_FILES:
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "0"
    return response


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)

    @app.get("/")
    def index():
        if (FRONTEND_BUILD_DIR / "index.html").exists():
            return _send_frontend_file("index.html")

        return jsonify(
            {
                "name": "Chess Coach API",
                "message": "Send a POST request to /api/puzzles to generate puzzles from Chess.com games.",
            }
        )

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"})

    @app.post("/api/puzzles")
    def create_puzzles():
        payload = request.get_json(silent=True) or {}
        username = str(payload.get("username", "")).strip()

        if not username:
            return jsonify({"error": "Please provide a Chess.com username."}), 400

        max_games = _coerce_int(payload.get("max_games"), 15, min_value=1, max_value=100)
        max_puzzles = _coerce_int(payload.get("max_puzzles"), 6, min_value=1, max_value=20)
        analysis_depth = _coerce_int(payload.get("analysis_depth"), 12, min_value=6, max_value=18)

        games = fetch_recent_games(username, max_games=max_games)
        puzzles, stats = generate_puzzles(
            games,
            username=username,
            max_puzzles=max_puzzles,
            analysis_depth=analysis_depth,
        )

        return jsonify(
            {
                "username": username,
                "games_count": len(games),
                "puzzles": [_serialize_puzzle(puzzle) for puzzle in puzzles],
                "stats": stats,
            }
        )

    @app.get("/<path:path>")
    def frontend(path: str):
        asset_path = FRONTEND_BUILD_DIR / path
        if asset_path.exists() and asset_path.is_file():
            return _send_frontend_file(path)

        if (FRONTEND_BUILD_DIR / "index.html").exists():
            return _send_frontend_file("index.html")

        return jsonify({"error": "Not found."}), 404

    @app.errorhandler(ChessComAPIError)
    def handle_chesscom_error(error: ChessComAPIError):
        return jsonify({"error": str(error)}), 400

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")), debug=True)
