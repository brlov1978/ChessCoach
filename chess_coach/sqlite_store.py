from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class SqliteStore:
    def __init__(self, db_path: str) -> None:
        self.db_path = str(Path(db_path))

    @classmethod
    def from_path(cls, db_path: str | None) -> "SqliteStore | None":
        value = (db_path or "").strip()
        if not value:
            return None
        return cls(value)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def ensure_schema(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS analysis_jobs (
                  id TEXT PRIMARY KEY,
                  username TEXT NOT NULL,
                  status TEXT NOT NULL,
                  options_json TEXT NOT NULL,
                  progress_percent INTEGER NOT NULL DEFAULT 0,
                  games_processed INTEGER NOT NULL DEFAULT 0,
                  positions_analyzed INTEGER NOT NULL DEFAULT 0,
                  mistakes_found INTEGER NOT NULL DEFAULT 0,
                  error_message TEXT,
                  created_at TEXT NOT NULL,
                  started_at TEXT,
                  finished_at TEXT
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS move_evaluations (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT NOT NULL,
                  game_url TEXT NOT NULL,
                  game_end_time INTEGER,
                                    game_date TEXT,
                                    time_format TEXT,
                  opening TEXT NOT NULL,
                  opponent TEXT NOT NULL,
                  player_color TEXT NOT NULL,
                  phase TEXT NOT NULL,
                  fen_before TEXT NOT NULL,
                  fen_hash TEXT NOT NULL,
                  fullmove_number INTEGER NOT NULL,
                  ply_index INTEGER NOT NULL,
                  played_move_uci TEXT NOT NULL,
                  best_move_uci TEXT NOT NULL,
                  eval_best_cp INTEGER NOT NULL,
                  eval_played_cp INTEGER NOT NULL,
                  eval_delta_cp INTEGER NOT NULL,
                  centipawn_loss INTEGER NOT NULL,
                  is_mistake INTEGER NOT NULL,
                  created_at TEXT NOT NULL
                )
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_move_evals_lookup
                ON move_evaluations (username, is_mistake, phase, game_end_time DESC)
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS mistake_patterns (
                  username TEXT NOT NULL,
                  fen_hash TEXT NOT NULL,
                  phase TEXT NOT NULL,
                  times_seen INTEGER NOT NULL DEFAULT 1,
                  avg_centipawn_loss REAL NOT NULL,
                  max_centipawn_loss INTEGER NOT NULL,
                  last_seen_at TEXT NOT NULL,
                  PRIMARY KEY (username, fen_hash, phase)
                )
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS analyzed_games (
                  username TEXT NOT NULL,
                  game_url TEXT NOT NULL,
                  game_date TEXT,
                  time_format TEXT,
                  analyzed_at TEXT NOT NULL,
                  PRIMARY KEY (username, game_url)
                )
                """
            )

            # Schema migrations for existing DBs.
            self._ensure_column(conn, "move_evaluations", "game_date", "TEXT")
            self._ensure_column(conn, "move_evaluations", "time_format", "TEXT")
            self._ensure_column(conn, "analyzed_games", "game_date", "TEXT")
            self._ensure_column(conn, "analyzed_games", "time_format", "TEXT")
            conn.commit()

    def _ensure_column(self, conn: sqlite3.Connection, table_name: str, column_name: str, column_type: str) -> None:
        rows = conn.execute(f"PRAGMA table_info({table_name})").fetchall()
        existing = {str(row[1]) for row in rows}
        if column_name in existing:
            return
        conn.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}")

    def create_job(self, *, job_id: str, username: str, options: dict[str, Any]) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO analysis_jobs (
                  id, username, status, options_json, created_at
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    job_id,
                    username,
                    "queued",
                    json.dumps(options),
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()

    def update_job(
        self,
        job_id: str,
        *,
        status: str | None = None,
        progress_percent: int | None = None,
        games_processed: int | None = None,
        positions_analyzed: int | None = None,
        mistakes_found: int | None = None,
        error_message: str | None = None,
        started: bool = False,
        finished: bool = False,
    ) -> None:
        updates: list[str] = []
        params: list[Any] = []

        if status is not None:
            updates.append("status = ?")
            params.append(status)
        if progress_percent is not None:
            updates.append("progress_percent = ?")
            params.append(progress_percent)
        if games_processed is not None:
            updates.append("games_processed = ?")
            params.append(games_processed)
        if positions_analyzed is not None:
            updates.append("positions_analyzed = ?")
            params.append(positions_analyzed)
        if mistakes_found is not None:
            updates.append("mistakes_found = ?")
            params.append(mistakes_found)
        if error_message is not None:
            updates.append("error_message = ?")
            params.append(error_message)
        if started:
            updates.append("started_at = COALESCE(started_at, ?)")
            params.append(datetime.now(timezone.utc).isoformat())
        if finished:
            updates.append("finished_at = ?")
            params.append(datetime.now(timezone.utc).isoformat())

        if not updates:
            return

        params.append(job_id)
        with self._connect() as conn:
            conn.execute(
                f"UPDATE analysis_jobs SET {', '.join(updates)} WHERE id = ?",
                tuple(params),
            )
            conn.commit()

    def get_job(self, job_id: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, username, status, options_json, progress_percent,
                       games_processed, positions_analyzed, mistakes_found,
                       error_message, created_at, started_at, finished_at
                FROM analysis_jobs
                WHERE id = ?
                """,
                (job_id,),
            ).fetchone()

        if row is None:
            return None
        return dict(row)

    def get_running_job_for_username(self, username: str) -> dict[str, Any] | None:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT id, username, status, options_json, progress_percent,
                       games_processed, positions_analyzed, mistakes_found,
                       error_message, created_at, started_at, finished_at
                FROM analysis_jobs
                WHERE username = ? AND status IN ('queued', 'running')
                ORDER BY created_at DESC
                LIMIT 1
                """,
                (username,),
            ).fetchone()
        if row is None:
            return None
        return dict(row)

    def insert_move_evaluation(self, row: dict[str, Any]) -> None:
        game_end_time = row.get("game_end_time")
        game_end_ts = int(game_end_time.timestamp()) if game_end_time else None

        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO move_evaluations (
                                    username, game_url, game_end_time, game_date, time_format, opening, opponent, player_color,
                  phase, fen_before, fen_hash, fullmove_number, ply_index,
                  played_move_uci, best_move_uci, eval_best_cp, eval_played_cp,
                  eval_delta_cp, centipawn_loss, is_mistake, created_at
                ) VALUES (
                                    ?, ?, ?, ?, ?, ?, ?, ?,
                  ?, ?, ?, ?, ?,
                  ?, ?, ?, ?,
                  ?, ?, ?, ?
                )
                """,
                (
                    row["username"],
                    row["game_url"],
                    game_end_ts,
                                        row.get("game_date"),
                                        row.get("time_format"),
                    row["opening"],
                    row["opponent"],
                    row["player_color"],
                    row["phase"],
                    row["fen_before"],
                    row["fen_hash"],
                    row["fullmove_number"],
                    row["ply_index"],
                    row["played_move_uci"],
                    row["best_move_uci"],
                    row["eval_best_cp"],
                    row["eval_played_cp"],
                    row["eval_delta_cp"],
                    row["centipawn_loss"],
                    1 if row["is_mistake"] else 0,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()

    def upsert_mistake_pattern(
        self,
        *,
        username: str,
        fen_hash: str,
        phase: str,
        centipawn_loss: int,
    ) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO mistake_patterns (
                  username, fen_hash, phase, times_seen, avg_centipawn_loss,
                  max_centipawn_loss, last_seen_at
                ) VALUES (
                  ?, ?, ?, 1, ?, ?, ?
                )
                ON CONFLICT (username, fen_hash, phase)
                DO UPDATE SET
                  times_seen = mistake_patterns.times_seen + 1,
                  avg_centipawn_loss =
                    ((mistake_patterns.avg_centipawn_loss * mistake_patterns.times_seen) + excluded.avg_centipawn_loss)
                    / (mistake_patterns.times_seen + 1),
                  max_centipawn_loss = MAX(mistake_patterns.max_centipawn_loss, excluded.max_centipawn_loss),
                  last_seen_at = excluded.last_seen_at
                """,
                (
                    username,
                    fen_hash,
                    phase,
                    float(centipawn_loss),
                    centipawn_loss,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()

    def fetch_mistake_rows(
        self,
        *,
        username: str,
        phase: str,
        min_repeat: int,
        min_centipawn_loss: int,
        since: datetime | None,
        limit: int | None = None,
    ) -> list[dict[str, Any]]:
        where = ["m.username = ?", "m.is_mistake = 1", "m.centipawn_loss >= ?", "p.times_seen >= ?"]
        params: list[Any] = [username, min_centipawn_loss, min_repeat]

        if phase != "any":
            where.append("m.phase = ?")
            params.append(phase)

        if since is not None:
            where.append("(m.game_end_time IS NULL OR m.game_end_time >= ?)")
            params.append(int(since.replace(tzinfo=timezone.utc).timestamp()))

        sql = f"""
            WITH ranked AS (
              SELECT
                m.fen_before,
                m.fen_hash,
                m.best_move_uci,
                m.played_move_uci,
                m.eval_best_cp,
                m.centipawn_loss,
                m.phase,
                m.game_date,
                m.time_format,
                m.game_url,
                m.opening,
                m.opponent,
                m.player_color,
                m.fullmove_number,
                m.game_end_time,
                p.times_seen,
                ROW_NUMBER() OVER (
                  PARTITION BY m.username, m.fen_hash, m.phase
                  ORDER BY m.centipawn_loss DESC, m.game_end_time DESC, m.id DESC
                ) AS rn
              FROM move_evaluations m
              JOIN mistake_patterns p
                ON p.username = m.username
               AND p.fen_hash = m.fen_hash
               AND p.phase = m.phase
              WHERE {' AND '.join(where)}
            )
            SELECT
              fen_before,
              fen_hash,
              best_move_uci,
              played_move_uci,
              eval_best_cp,
              centipawn_loss,
              phase,
              game_date,
              time_format,
              game_url,
              opening,
              opponent,
              player_color,
              fullmove_number,
              times_seen
            FROM ranked
            WHERE rn = 1
            ORDER BY times_seen DESC, centipawn_loss DESC, game_end_time DESC
        """

        if limit is not None:
            sql += "\nLIMIT ?"
            params.append(limit)

        with self._connect() as conn:
            rows = conn.execute(sql, tuple(params)).fetchall()

        return [dict(row) for row in rows]

    def fetch_mistake_occurrences(
        self,
        *,
        username: str,
        fen_hash: str,
        phase: str,
        limit: int = 20,
    ) -> list[dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute(
                """
                SELECT game_url, game_date, time_format, centipawn_loss
                FROM move_evaluations
                WHERE username = ?
                  AND fen_hash = ?
                  AND phase = ?
                  AND is_mistake = 1
                ORDER BY game_end_time DESC, id DESC
                LIMIT ?
                """,
                (username, fen_hash, phase, limit),
            ).fetchall()
        return [dict(row) for row in rows]

    def is_game_processed(self, *, username: str, game_url: str) -> bool:
        with self._connect() as conn:
            row = conn.execute(
                """
                SELECT 1
                FROM analyzed_games
                WHERE username = ? AND game_url = ?
                LIMIT 1
                """,
                (username, game_url),
            ).fetchone()
        return row is not None

    def mark_game_processed(
        self,
        *,
        username: str,
        game_url: str,
        game_date: str | None = None,
        time_format: str | None = None,
    ) -> None:
        with self._connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO analyzed_games (
                  username, game_url, game_date, time_format, analyzed_at
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    username,
                    game_url,
                    game_date,
                    time_format,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()