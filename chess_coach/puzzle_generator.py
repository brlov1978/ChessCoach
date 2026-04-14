from __future__ import annotations

import io
import os
import shutil
import time
from dataclasses import asdict, dataclass
from typing import Any

import chess
import chess.engine
import chess.pgn
import requests


@dataclass
class PuzzleCandidate:
    title: str
    fen: str
    best_move_uci: str
    best_move_san: str
    actual_move_san: str | None
    played_best_move: bool
    evaluation_cp: int
    mate_in: int | None
    source_url: str
    opening: str
    opponent: str
    player_color: str
    reason: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


class PositionEvaluator:
    def __init__(self, depth: int = 12, multipv: int = 2) -> None:
        self.depth = depth
        self.multipv = multipv
        self.session = requests.Session()
        self.cache: dict[str, list[dict[str, Any]]] = {}
        self.engine_path = self._discover_stockfish()
        self.engine: chess.engine.SimpleEngine | None = None
        self.source = "Lichess Cloud Eval"

        if self.engine_path:
            self.engine = chess.engine.SimpleEngine.popen_uci(self.engine_path)
            self.source = f"Stockfish ({self.engine_path})"

    def close(self) -> None:
        if self.engine is not None:
            self.engine.quit()

    def _discover_stockfish(self) -> str | None:
        candidates = [
            os.environ.get("STOCKFISH_PATH"),
            shutil.which("stockfish"),
            shutil.which("stockfish.exe"),
            os.path.join(os.getcwd(), "bin", "stockfish", "stockfish.exe"),
        ]

        for candidate in candidates:
            if candidate and os.path.exists(candidate):
                return candidate
        return None

    def analyze(self, board: chess.Board) -> list[dict[str, Any]]:
        fen = board.fen()
        if fen in self.cache:
            return self.cache[fen]

        if self.engine is not None:
            lines = self._analyze_local(board)
        else:
            lines = self._analyze_cloud(board)

        self.cache[fen] = lines
        return lines

    def _analyze_local(self, board: chess.Board) -> list[dict[str, Any]]:
        info = self.engine.analyse(
            board,
            chess.engine.Limit(depth=self.depth),
            multipv=self.multipv,
        )

        if isinstance(info, dict):
            info = [info]

        lines: list[dict[str, Any]] = []
        for item in info:
            pv = item.get("pv") or []
            if not pv:
                continue

            score = item["score"].pov(board.turn)
            lines.append(
                {
                    "move": pv[0],
                    "score": score.score(mate_score=100000) or 0,
                    "mate": score.mate(),
                }
            )
        return lines

    def _analyze_cloud(self, board: chess.Board) -> list[dict[str, Any]]:
        try:
            response = self.session.get(
                "https://lichess.org/api/cloud-eval",
                params={"fen": board.fen(), "multiPv": self.multipv},
                headers={"Accept": "application/json", "User-Agent": "ChessCoach/1.0"},
                timeout=6,
            )
            response.raise_for_status()
            data = response.json()
        except Exception:
            return []

        lines: list[dict[str, Any]] = []
        for pv in data.get("pvs", []):
            moves = (pv.get("moves") or "").split()
            if not moves:
                continue

            try:
                move = chess.Move.from_uci(moves[0])
            except ValueError:
                continue

            lines.append(
                {
                    "move": move,
                    "score": int(pv.get("cp", 0)),
                    "mate": pv.get("mate"),
                }
            )
        return lines


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
    return headers.get("Opening") or headers.get("ECOUrl", "").rsplit("/", 1)[-1].replace("-", " ").strip() or "Unknown opening"


def _score_gap(lines: list[dict[str, Any]]) -> int:
    if len(lines) < 2:
        return abs(lines[0]["score"]) if lines else 0
    return lines[0]["score"] - lines[1]["score"]


def _difficulty_thresholds(level: str) -> dict[str, int]:
    normalized = level.strip().lower()
    presets = {
        "easy": {"min_strength": 130, "min_gap": 40, "min_unplayed": 250},
        "medium": {"min_strength": 180, "min_gap": 70, "min_unplayed": 320},
        "hard": {"min_strength": 260, "min_gap": 120, "min_unplayed": 420},
    }
    return presets.get(normalized, presets["medium"])


PIECE_VALUES = {
    chess.PAWN: 100,
    chess.KNIGHT: 320,
    chess.BISHOP: 330,
    chess.ROOK: 500,
    chess.QUEEN: 900,
    chess.KING: 0,
}


def _heuristic_best_move(board: chess.Board) -> dict[str, Any] | None:
    best_candidate: dict[str, Any] | None = None

    for move in board.legal_moves:
        is_capture = board.is_capture(move)
        captured_piece = board.piece_at(move.to_square) if is_capture else None

        board.push(move)
        is_mate = board.is_checkmate()
        gives_check = board.is_check()
        board.pop()

        if is_mate:
            return {"move": move, "score": 100000, "mate": 1}

        if captured_piece is None:
            continue

        score = PIECE_VALUES.get(captured_piece.piece_type, 0)
        if gives_check:
            score += 50

        if score >= 320 and (best_candidate is None or score > best_candidate["score"]):
            best_candidate = {"move": move, "score": score, "mate": None}

    return best_candidate


def generate_puzzles(
    games: list[dict[str, Any]],
    username: str,
    max_puzzles: int = 8,
    analysis_depth: int = 12,
    evaluator: PositionEvaluator | None = None,
    time_budget_seconds: float = 20.0,
    difficulty_level: str = "medium",
    multipv: int = 2,
) -> tuple[list[PuzzleCandidate], dict[str, Any]]:
    created_evaluator = evaluator is None
    evaluator = evaluator or PositionEvaluator(depth=analysis_depth, multipv=multipv)

    primary_puzzles: list[PuzzleCandidate] = []
    fallback_puzzles: list[PuzzleCandidate] = []
    soft_fallback_puzzles: list[PuzzleCandidate] = []
    seen_fens: set[str] = set()
    positions_checked = 0
    deadline = time.perf_counter() + max(8.0, time_budget_seconds)
    max_positions_per_game = max(2, min(4, max_puzzles))
    difficulty_rules = _difficulty_thresholds(difficulty_level)
    relaxed_rules = {
        "min_strength": max(90, difficulty_rules["min_strength"] - 100),
        "min_gap": max(15, difficulty_rules["min_gap"] - 60),
        "min_unplayed": max(160, difficulty_rules["min_unplayed"] - 160),
    }

    try:
        for game_data in games:
            if len(primary_puzzles) >= max_puzzles or time.perf_counter() >= deadline:
                break

            added_for_game = False
            positions_in_game = 0
            player_color = _player_color(game_data, username)
            if player_color is None:
                continue

            pgn_text = game_data.get("pgn", "")
            if not pgn_text:
                continue

            game = chess.pgn.read_game(io.StringIO(pgn_text))
            if game is None:
                continue

            board = game.board()
            moves = list(game.mainline_moves())

            for ply_index, move in enumerate(moves):
                if time.perf_counter() >= deadline or positions_in_game >= max_positions_per_game:
                    break

                board.push(move)

                if board.turn != player_color:
                    continue

                if board.fullmove_number < 4 or board.is_game_over():
                    continue

                positions_checked += 1
                positions_in_game += 1
                engine_lines = evaluator.analyze(board)
                lines = list(engine_lines)
                heuristic = _heuristic_best_move(board)

                if heuristic and (not lines or heuristic["score"] > lines[0]["score"]):
                    lines = [heuristic] + lines[:1]

                if not lines:
                    continue

                best = lines[0]
                if best["move"] is None or best["move"] not in board.legal_moves:
                    continue

                strength_score = best["score"]
                display_score = engine_lines[0]["score"] if engine_lines else strength_score
                mate_in = best.get("mate")
                gap = _score_gap(lines)

                next_move = moves[ply_index + 1] if ply_index + 1 < len(moves) else None
                played_best_move = next_move == best["move"] if next_move else False

                fen = board.fen()
                if fen in seen_fens:
                    continue
                seen_fens.add(fen)

                best_san = board.san(best["move"])
                actual_san = board.san(next_move) if next_move else None
                color_name = "White" if player_color == chess.WHITE else "Black"
                opponent = game_data.get("black", {}).get("username", "Unknown") if player_color == chess.WHITE else game_data.get("white", {}).get("username", "Unknown")

                if mate_in is not None and mate_in > 0:
                    reason = f"There is a forcing line here with mate in {mate_in}."
                elif played_best_move:
                    reason = "This winning move was found in your real game."
                else:
                    reason = "This position offered a strong tactical opportunity."

                candidate = PuzzleCandidate(
                    title=f"Move {board.fullmove_number}: find the best move for {color_name}",
                    fen=fen,
                    best_move_uci=best["move"].uci(),
                    best_move_san=best_san,
                    actual_move_san=actual_san,
                    played_best_move=played_best_move,
                    evaluation_cp=display_score,
                    mate_in=mate_in,
                    source_url=game_data.get("url", ""),
                    opening=_opening_name(game.headers),
                    opponent=opponent,
                    player_color=color_name,
                    reason=reason,
                )

                is_strong_candidate = True
                if mate_in is None and strength_score < difficulty_rules["min_strength"]:
                    is_strong_candidate = False
                if mate_in is None and gap < difficulty_rules["min_gap"] and strength_score < difficulty_rules["min_unplayed"]:
                    is_strong_candidate = False
                if not played_best_move and mate_in is None and strength_score < difficulty_rules["min_unplayed"]:
                    is_strong_candidate = False

                if is_strong_candidate:
                    if not added_for_game:
                        primary_puzzles.append(candidate)
                        added_for_game = True

                        if len(primary_puzzles) >= max_puzzles:
                            break
                    else:
                        fallback_puzzles.append(candidate)
                elif (
                    mate_in is not None
                    or strength_score >= relaxed_rules["min_strength"]
                    or gap >= relaxed_rules["min_gap"]
                    or played_best_move
                ):
                    soft_fallback_puzzles.append(candidate)
    finally:
        if created_evaluator:
            evaluator.close()

    puzzles = primary_puzzles[:max_puzzles]
    if len(puzzles) < max_puzzles:
        puzzles.extend(fallback_puzzles[: max_puzzles - len(puzzles)])
    if len(puzzles) < max_puzzles:
        used_fens = {puzzle.fen for puzzle in puzzles}
        for candidate in soft_fallback_puzzles:
            if candidate.fen in used_fens:
                continue
            puzzles.append(candidate)
            used_fens.add(candidate.fen)
            if len(puzzles) >= max_puzzles:
                break

    stats = {
        "games_scanned": len(games),
        "positions_checked": positions_checked,
        "engine_source": evaluator.source,
        "difficulty": difficulty_level,
        "time_budget_seconds": round(time_budget_seconds, 1),
    }
    return puzzles, stats
