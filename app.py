from __future__ import annotations

import os
from typing import Any

from flask import Flask, jsonify, request
from flask_cors import CORS

from chess_coach.chesscom_api import ChessComAPIError
from chess_coach.config import load_app_config
from chess_coach.mistake_analysis import (
    generate_mistake_puzzles,
    get_analysis_job,
    start_analysis_job,
)
from chess_coach.sqlite_store import SqliteStore


def _coerce_int(value: Any, default: int, *, min_value: int, max_value: int) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    return max(min_value, min(max_value, parsed))


def _coerce_bool(value: Any, default: bool) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value

    parsed = str(value).strip().lower()
    if parsed in {"1", "true", "yes", "on"}:
        return True
    if parsed in {"0", "false", "no", "off"}:
        return False
    return default


def _serialize_puzzle(puzzle: Any) -> dict[str, Any]:
    if hasattr(puzzle, "to_dict"):
        return puzzle.to_dict()
    return dict(puzzle)


def create_app() -> Flask:
    app = Flask(__name__)
    CORS(app)
    config = load_app_config()
    store = SqliteStore.from_path(config.database_path)

    if store is not None:
        try:
            store.ensure_schema()
        except Exception:
            store = None

    @app.get("/")
    def index():
        return jsonify(
            {
                "name": "Chess Coach API",
                "message": "Use /api/analysis/jobs to analyze games and /api/puzzles/mistakes to load stored puzzles.",
            }
        )

    @app.get("/health")
    def health():
        return jsonify({"status": "ok"})

    @app.post("/api/puzzles")
    def create_puzzles():
        return (
            jsonify(
                {
                    "error": "On-the-fly generation is disabled. Run /api/analysis/jobs then use /api/puzzles/mistakes.",
                }
            ),
            410,
        )

    @app.post("/api/analysis/jobs")
    def create_analysis_job():
        if store is None:
            return jsonify({"error": "SQLite is not configured. Set database_path in config.json."}), 503

        payload = request.get_json(silent=True) or {}
        username = str(payload.get("username", "")).strip()
        if not username:
            return jsonify({"error": "Please provide a Chess.com username."}), 400

        options = {
            "username": username,
            "months_back": _coerce_int(payload.get("months_back"), 12, min_value=1, max_value=120),
            "max_games": _coerce_int(payload.get("max_games"), 500, min_value=10, max_value=5000),
            "analysis_depth": _coerce_int(payload.get("analysis_depth"), 10, min_value=6, max_value=20),
            "mistake_threshold_cp": _coerce_int(
                payload.get("mistake_threshold_cp"),
                90,
                min_value=20,
                max_value=600,
            ),
            "allow_cloud_fallback": _coerce_bool(
                payload.get("allow_cloud_fallback"),
                config.allow_cloud_fallback,
            ),
            "stockfish_path": str(
                payload.get("stockfish_path") or config.stockfish_path or ""
            ).strip()
            or None,
        }

        existing = store.get_running_job_for_username(username.strip().lower())
        if existing is not None:
            return (
                jsonify(
                    {
                        "job_id": existing["id"],
                        "status": existing["status"],
                        "message": "A job is already running for this user.",
                    }
                ),
                200,
            )

        try:
            job_id = start_analysis_job(store, options)
        except Exception as error:
            return jsonify({"error": str(error)}), 500

        return jsonify({"job_id": job_id, "status": "queued"}), 202

    @app.get("/api/analysis/jobs/<job_id>")
    def get_job_status(job_id: str):
        if store is None:
            return jsonify({"error": "SQLite is not configured. Set database_path in config.json."}), 503

        try:
            job = get_analysis_job(store, job_id)
        except Exception as error:
            return jsonify({"error": str(error)}), 500

        if job is None:
            return jsonify({"error": "Job not found."}), 404
        return jsonify(job)

    @app.post("/api/puzzles/mistakes")
    def create_mistake_puzzles():
        if store is None:
            return jsonify({"error": "SQLite is not configured. Set database_path in config.json."}), 503

        payload = request.get_json(silent=True) or {}
        username = str(payload.get("username", "")).strip()
        if not username:
            return jsonify({"error": "Please provide a Chess.com username."}), 400

        try:
            puzzles, stats = generate_mistake_puzzles(
                store,
                username=username,
                phase="any",
                months_back=None,
                min_repeat=1,
                min_centipawn_loss=None,
            )
        except Exception as error:
            return jsonify({"error": str(error)}), 500

        return jsonify(
            {
                "username": username,
                "puzzles": [_serialize_puzzle(puzzle) for puzzle in puzzles],
                "stats": stats,
            }
        )

    @app.errorhandler(ChessComAPIError)
    def handle_chesscom_error(error: ChessComAPIError):
        return jsonify({"error": str(error)}), 400

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "8000")), debug=True)
