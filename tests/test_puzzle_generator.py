import chess

from chess_coach.puzzle_generator import generate_puzzles


class FakeEvaluator:
    source = "fake"

    def analyze(self, board: chess.Board):
        tactical_move = chess.Move.from_uci("f3e5")
        if tactical_move in board.legal_moves:
            return [
                {"move": tactical_move, "score": 350, "mate": None},
                {"move": chess.Move.from_uci("c4f7"), "score": 40, "mate": None},
            ]

        first_legal = next(iter(board.legal_moves))
        return [{"move": first_legal, "score": 0, "mate": None}]

    def close(self):
        return None


class LowScoreEvaluator:
    source = "fake-low"

    def analyze(self, board: chess.Board):
        quiet_move = chess.Move.from_uci("c4b5")
        if quiet_move in board.legal_moves:
            return [
                {"move": quiet_move, "score": 30, "mate": None},
                {"move": chess.Move.from_uci("f3d4"), "score": 20, "mate": None},
            ]

        first_legal = next(iter(board.legal_moves))
        return [{"move": first_legal, "score": 0, "mate": None}]

    def close(self):
        return None


class AlwaysTacticalEvaluator:
    source = "fake-diverse"

    def analyze(self, board: chess.Board):
        legal_moves = list(board.legal_moves)
        best_move = legal_moves[0]
        second_move = legal_moves[1] if len(legal_moves) > 1 else legal_moves[0]
        return [
            {"move": best_move, "score": 420, "mate": None},
            {"move": second_move, "score": 30, "mate": None},
        ]

    def close(self):
        return None


def test_generate_puzzles_returns_candidate_from_game():
    sample_game = {
        "white": {"username": "CoachUser"},
        "black": {"username": "Opponent"},
        "url": "https://www.chess.com/game/live/123",
        "pgn": """
[Event \"Live Chess\"]
[Site \"Chess.com\"]
[Date \"2026.04.14\"]
[Round \"-\"]
[White \"CoachUser\"]
[Black \"Opponent\"]
[Result \"1-0\"]
[Opening \"Italian Game\"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Bxf7+ Ke7 6. O-O Qxe5 7. Bxg8 Rxg8 8. c3 Ne6 1-0
""",
    }

    puzzles, stats = generate_puzzles(
        [sample_game],
        username="CoachUser",
        max_puzzles=1,
        evaluator=FakeEvaluator(),
    )

    assert len(puzzles) == 1
    assert puzzles[0].best_move_uci == "f3e5"
    assert puzzles[0].played_best_move is True
    assert stats["engine_source"] == "fake"


def test_generate_puzzles_keeps_engine_eval_when_heuristic_picks_move():
    sample_game = {
        "white": {"username": "CoachUser"},
        "black": {"username": "Opponent"},
        "url": "https://www.chess.com/game/live/456",
        "pgn": """
[Event \"Live Chess\"]
[Site \"Chess.com\"]
[Date \"2026.04.14\"]
[Round \"-\"]
[White \"CoachUser\"]
[Black \"Opponent\"]
[Result \"1-0\"]
[Opening \"Italian Game\"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 1-0
""",
    }

    puzzles, _ = generate_puzzles(
        [sample_game],
        username="CoachUser",
        max_puzzles=1,
        evaluator=LowScoreEvaluator(),
    )

    assert len(puzzles) == 1
    assert puzzles[0].best_move_uci == "f3d4"
    assert puzzles[0].evaluation_cp == 30


def test_generate_puzzles_prefers_one_per_game_when_possible():
    italian_pgn = """
[Event \"Live Chess\"]
[Site \"Chess.com\"]
[Date \"2026.04.14\"]
[Round \"-\"]
[White \"CoachUser\"]
[Black \"OpponentA\"]
[Result \"1-0\"]
[Opening \"Italian Game\"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. d3 Nf6 5. Nc3 d6 6. Bg5 h6 7. Bh4 g5 8. Bg3 a6 1-0
"""
    queens_gambit_pgn = """
[Event \"Live Chess\"]
[Site \"Chess.com\"]
[Date \"2026.04.14\"]
[Round \"-\"]
[White \"CoachUser\"]
[Black \"OpponentB\"]
[Result \"1-0\"]
[Opening \"Queen's Gambit\"]

1. d4 d5 2. c4 e6 3. Nc3 Nf6 4. Bg5 Be7 5. e3 O-O 6. Nf3 h6 7. Bh4 b6 8. cxd5 exd5 1-0
"""
    games = [
        {
            "white": {"username": "CoachUser"},
            "black": {"username": "OpponentA"},
            "url": "https://www.chess.com/game/live/100",
            "pgn": italian_pgn,
        },
        {
            "white": {"username": "CoachUser"},
            "black": {"username": "OpponentB"},
            "url": "https://www.chess.com/game/live/200",
            "pgn": queens_gambit_pgn,
        },
    ]

    puzzles, _ = generate_puzzles(
        games,
        username="CoachUser",
        max_puzzles=2,
        evaluator=AlwaysTacticalEvaluator(),
    )

    assert len(puzzles) == 2
    assert len({puzzle.source_url for puzzle in puzzles}) == 2


def test_generate_puzzles_allows_second_puzzle_if_not_enough_games():
    sample_game = {
        "white": {"username": "CoachUser"},
        "black": {"username": "OpponentA"},
        "url": "https://www.chess.com/game/live/300",
        "pgn": """
[Event \"Live Chess\"]
[Site \"Chess.com\"]
[Date \"2026.04.14\"]
[Round \"-\"]
[White \"CoachUser\"]
[Black \"OpponentA\"]
[Result \"1-0\"]
[Opening \"Italian Game\"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. d3 Nf6 5. Nc3 d6 6. Bg5 h6 7. Bh4 g5 8. Bg3 a6 1-0
""",
    }

    puzzles, _ = generate_puzzles(
        [sample_game],
        username="CoachUser",
        max_puzzles=2,
        evaluator=AlwaysTacticalEvaluator(),
    )

    assert len(puzzles) == 2
    assert {puzzle.source_url for puzzle in puzzles} == {"https://www.chess.com/game/live/300"}
