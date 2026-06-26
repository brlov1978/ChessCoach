from __future__ import annotations

import hashlib
import io
from datetime import datetime, timedelta, timezone
from threading import Thread
from typing import Any
from uuid import uuid4

import chess
import chess.pgn

from chess_coach.chesscom_api import fetch_games_since
from chess_coach.sqlite_store import SqliteStore
from chess_coach.puzzle_generator import PositionEvaluator, PuzzleCandidate


def _normalize_username(value: str) -> str:
    return value.strip().lower()


def _player_color(game: dict[str, Any], username: str) -> chess.Color | None:
    username = _normalize_username(username)
    white_name = _normalize_username(game.get("white", {}).get("username", ""))
    black_name = _normalize_username(game.get("black", {}).get("username", ""))

    if username == white_name:
        return chess.WHITE
    if username == black_name:
        return chess.BLACK
    return None


def _opening_name(headers: chess.pgn.Headers) -> str:
    return (
        headers.get("Opening")
        or headers.get("ECOUrl", "").rsplit("/", 1)[-1].replace("-", " ").strip()
        or "Unknown opening"
    )


def _phase_for_position(board: chess.Board) -> str:
    if board.fullmove_number <= 10:
        return "opening"

    material_points = 0
    for piece_type in [chess.QUEEN, chess.ROOK, chess.BISHOP, chess.KNIGHT]:
        count = len(board.pieces(piece_type, chess.WHITE)) + len(board.pieces(piece_type, chess.BLACK))
        if piece_type == chess.QUEEN:
            material_points += count * 9
        elif piece_type == chess.ROOK:
            material_points += count * 5
        else:
            material_points += count * 3

    return "endgame" if material_points <= 16 else "middlegame"


def _fen_hash(fen: str) -> str:
    key = " ".join(fen.split(" ")[:4])
    return hashlib.sha1(key.encode("utf-8")).hexdigest()


def _score_for_player(board: chess.Board, score_cp: int, player_color: chess.Color) -> int:
    return score_cp if board.turn == player_color else -score_cp


def _evaluate_single_cp(
    evaluator: PositionEvaluator,
    board: chess.Board,
    player_color: chess.Color,
) -> int | None:
    lines = evaluator.analyze(board)
    if not lines:
        return None
    raw = int(lines[0]["score"])
    return _score_for_player(board, raw, player_color)


def _parse_end_time(game_data: dict[str, Any]) -> datetime | None:
    value = game_data.get("end_time")
    if not value:
        return None
    try:
        return datetime.fromtimestamp(int(value), tz=timezone.utc)
    except Exception:
        return None


def _run_analysis_job(job_id: str, store: SqliteStore, options: dict[str, Any]) -> None:
    username = str(options["username"]).strip()
    months_back = int(options.get("months_back", 12))
    max_games = int(options.get("max_games", 500))
    analysis_depth = int(options.get("analysis_depth", 10))
    mistake_threshold_cp = int(options.get("mistake_threshold_cp", 90))
    allow_cloud_fallback = bool(options.get("allow_cloud_fallback", False))
    stockfish_path = options.get("stockfish_path")

    store.update_job(job_id, status="running", started=True)

    since = datetime.now(tz=timezone.utc) - timedelta(days=max(1, months_back) * 30)
    games = fetch_games_since(username, since=since, max_games=max_games)

    games_processed = 0
    positions_analyzed = 0
    mistakes_found = 0

    evaluator = PositionEvaluator(
        depth=analysis_depth,
        multipv=2,
        allow_cloud_fallback=allow_cloud_fallback,
        stockfish_path=stockfish_path,
    )

    try:
        total_games = max(1, len(games))
        for game_data in games:
            game_url = str(game_data.get("url", "")).strip()
            if game_url and store.is_game_processed(username=username, game_url=game_url):
                games_processed += 1
                continue

            player_color = _player_color(game_data, username)
            if player_color is None:
                if game_url:
                    store.mark_game_processed(username=username, game_url=game_url)
                games_processed += 1
                continue

            pgn_text = game_data.get("pgn", "")
            if not pgn_text:
                if game_url:
                    store.mark_game_processed(username=username, game_url=game_url)
                games_processed += 1
                continue

            game = chess.pgn.read_game(io.StringIO(pgn_text))
            if game is None:
                if game_url:
                    store.mark_game_processed(username=username, game_url=game_url)
                games_processed += 1
                continue

            board = game.board()
            moves = list(game.mainline_moves())

            opening = _opening_name(game.headers)
            opponent = (
                game_data.get("black", {}).get("username", "Unknown")
                if player_color == chess.WHITE
                else game_data.get("white", {}).get("username", "Unknown")
            )
            player_color_name = "White" if player_color == chess.WHITE else "Black"
            game_end_time = _parse_end_time(game_data)
            game_date = game_end_time.date().isoformat() if game_end_time else None
            time_format = str(game_data.get("time_class") or "").strip().lower() or None

            for ply_index, move in enumerate(moves):
                if board.turn != player_color:
                    board.push(move)
                    continue

                fen_before = board.fen()
                best_lines = evaluator.analyze(board)
                if not best_lines:
                    board.push(move)
                    continue

                best_move = best_lines[0]["move"]
                best_score_cp = _score_for_player(board, int(best_lines[0]["score"]), player_color)

                board_after_played = board.copy(stack=False)
                board_after_played.push(move)
                played_score_cp = _evaluate_single_cp(evaluator, board_after_played, player_color)
                if played_score_cp is None:
                    played_score_cp = best_score_cp

                eval_delta_cp = played_score_cp - best_score_cp
                centipawn_loss = max(0, best_score_cp - played_score_cp)
                phase = _phase_for_position(board)
                is_mistake = centipawn_loss >= mistake_threshold_cp

                store.insert_move_evaluation(
                    {
                        "username": username,
                        "game_url": game_data.get("url", ""),
                        "game_end_time": game_end_time,
                        "game_date": game_date,
                        "time_format": time_format,
                        "opening": opening,
                        "opponent": opponent,
                        "player_color": player_color_name,
                        "phase": phase,
                        "fen_before": fen_before,
                        "fen_hash": _fen_hash(fen_before),
                        "fullmove_number": board.fullmove_number,
                        "ply_index": ply_index,
                        "played_move_uci": move.uci(),
                        "best_move_uci": best_move.uci(),
                        "eval_best_cp": best_score_cp,
                        "eval_played_cp": played_score_cp,
                        "eval_delta_cp": eval_delta_cp,
                        "centipawn_loss": centipawn_loss,
                        "is_mistake": is_mistake,
                    }
                )

                if is_mistake:
                    mistakes_found += 1
                    store.upsert_mistake_pattern(
                        username=username,
                        fen_hash=_fen_hash(fen_before),
                        phase=phase,
                        centipawn_loss=centipawn_loss,
                    )

                positions_analyzed += 1

                if (ply_index + 1) % 10 == 0:
                    game_fraction = (ply_index + 1) / max(1, len(moves))
                    progress = int(((games_processed + game_fraction) / total_games) * 100)
                    store.update_job(
                        job_id,
                        progress_percent=min(99, progress),
                        games_processed=games_processed,
                        positions_analyzed=positions_analyzed,
                        mistakes_found=mistakes_found,
                    )
                board.push(move)

            games_processed += 1
            if game_url:
                store.mark_game_processed(
                    username=username,
                    game_url=game_url,
                    game_date=game_date,
                    time_format=time_format,
                )
            progress = int((games_processed / total_games) * 100)
            store.update_job(
                job_id,
                progress_percent=min(99, progress),
                games_processed=games_processed,
                positions_analyzed=positions_analyzed,
                mistakes_found=mistakes_found,
            )

        store.update_job(
            job_id,
            status="completed",
            progress_percent=100,
            games_processed=games_processed,
            positions_analyzed=positions_analyzed,
            mistakes_found=mistakes_found,
            finished=True,
        )
    except Exception as error:
        store.update_job(
            job_id,
            status="failed",
            error_message=str(error),
            games_processed=games_processed,
            positions_analyzed=positions_analyzed,
            mistakes_found=mistakes_found,
            finished=True,
        )
    finally:
        evaluator.close()


def start_analysis_job(store: SqliteStore, options: dict[str, Any]) -> str:
    job_id = str(uuid4())
    store.create_job(job_id=job_id, username=str(options["username"]).strip(), options=options)

    thread = Thread(target=_run_analysis_job, args=(job_id, store, options), daemon=True)
    thread.start()
    return job_id


def get_analysis_job(store: SqliteStore, job_id: str) -> dict[str, Any] | None:
    job = store.get_job(job_id)
    if job is None:
        return None

    options_text = str(job.get("options_json") or "{}")
    try:
        import json

        options = json.loads(options_text)
    except Exception:
        options = {}

    return {
        "id": job.get("id"),
        "username": job.get("username"),
        "status": job.get("status"),
        "progress_percent": int(job.get("progress_percent") or 0),
        "games_processed": int(job.get("games_processed") or 0),
        "positions_analyzed": int(job.get("positions_analyzed") or 0),
        "mistakes_found": int(job.get("mistakes_found") or 0),
        "error": job.get("error_message"),
        "created_at": str(job.get("created_at")) if job.get("created_at") else None,
        "started_at": str(job.get("started_at")) if job.get("started_at") else None,
        "finished_at": str(job.get("finished_at")) if job.get("finished_at") else None,
        "options": options,
    }


def generate_mistake_puzzles(
    store: SqliteStore,
    *,
    username: str,
    phase: str,
    months_back: int | None,
    min_repeat: int,
    min_centipawn_loss: int | None,
) -> tuple[list[PuzzleCandidate], dict[str, Any]]:
    since = (
        datetime.now(tz=timezone.utc) - timedelta(days=max(1, months_back) * 30)
        if months_back is not None
        else None
    )
    minimum_loss = max(0, int(min_centipawn_loss or 0))
    rows = store.fetch_mistake_rows(
        username=username.strip().lower(),
        phase=phase,
        min_repeat=min_repeat,
        min_centipawn_loss=minimum_loss,
        since=since,
        limit=None,
    )

    puzzles: list[PuzzleCandidate] = []
    for row in rows:
        fen = str(row["fen_before"])
        board = chess.Board(fen)

        best_move_uci = str(row["best_move_uci"])
        played_move_uci = str(row["played_move_uci"])

        try:
            best_move = chess.Move.from_uci(best_move_uci)
            best_move_san = board.san(best_move) if best_move in board.legal_moves else best_move_uci
        except Exception:
            best_move_san = best_move_uci

        try:
            played_move = chess.Move.from_uci(played_move_uci)
            played_move_san = board.san(played_move) if played_move in board.legal_moves else played_move_uci
        except Exception:
            played_move_san = played_move_uci

        occurrences = store.fetch_mistake_occurrences(
            username=username.strip().lower(),
            fen_hash=str(row.get("fen_hash") or ""),
            phase=str(row.get("phase") or ""),
            limit=20,
        )
        repeat_examples = [
            {
                "url": str(item.get("game_url") or ""),
                "date": str(item.get("game_date") or "Unknown date"),
                "format": str(item.get("time_format") or "unknown"),
            }
            for item in occurrences
            if str(item.get("game_url") or "").strip()
        ]
        repeat_count = int(row.get("times_seen") or len(repeat_examples) or 0)

        puzzles.append(
            PuzzleCandidate(
                title=f"Move {row['fullmove_number']}: fix a repeated {row['phase']} mistake",
                fen=fen,
                best_move_uci=best_move_uci,
                best_move_san=best_move_san,
                actual_move_san=played_move_san,
                played_best_move=False,
                evaluation_cp=int(row.get("eval_best_cp") or 0),
                mate_in=None,
                source_url=str(row.get("game_url") or ""),
                opening=str(row.get("opening") or "Unknown opening"),
                opponent=str(row.get("opponent") or "Unknown"),
                player_color=str(row.get("player_color") or "Unknown"),
                reason=(
                    f"You repeated this {row['phase']} mistake {repeat_count} times "
                    f"(about {row['centipawn_loss']} centipawns lost)."
                ),
                repeat_count=repeat_count,
                repeat_examples=repeat_examples,
            )
        )

    stats = {
        "source": "sqlite_mistakes",
        "username": username.strip().lower(),
        "phase": phase,
        "months_back": months_back,
        "min_repeat": min_repeat,
        "min_centipawn_loss": minimum_loss,
        "mistake_positions_considered": len(rows),
    }
    return puzzles, stats
