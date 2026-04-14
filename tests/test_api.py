from app import app


def test_generate_puzzles_endpoint_returns_json(monkeypatch):
    sample_games = [{"url": "https://example.com/game", "pgn": "demo"}]
    sample_puzzles = [
        {
            "title": "Find the best move",
            "fen": "8/8/8/8/8/8/8/8 w - - 0 1",
            "best_move_uci": "e2e4",
            "best_move_san": "e4",
            "actual_move_san": "e4",
            "played_best_move": True,
            "evaluation_cp": 250,
            "mate_in": None,
            "source_url": "https://example.com/game",
            "opening": "Italian Game",
            "opponent": "Opponent",
            "player_color": "White",
            "reason": "This winning move was found in your real game.",
        }
    ]
    captured = {}

    def fake_fetch_recent_games(username, max_games=10):
        captured["username"] = username
        captured["max_games"] = max_games
        return sample_games

    def fake_generate_puzzles(
        games,
        username,
        max_puzzles=5,
        analysis_depth=12,
        difficulty_level="medium",
        time_budget_seconds=20.0,
        multipv=2,
    ):
        captured["max_puzzles"] = max_puzzles
        captured["analysis_depth"] = analysis_depth
        captured["difficulty_level"] = difficulty_level
        captured["time_budget_seconds"] = time_budget_seconds
        captured["multipv"] = multipv
        return sample_puzzles, {"games_scanned": 1, "positions_checked": 4, "engine_source": "fake"}

    monkeypatch.setattr("app.fetch_recent_games", fake_fetch_recent_games)
    monkeypatch.setattr("app.generate_puzzles", fake_generate_puzzles)

    client = app.test_client()
    response = client.post(
        "/api/puzzles",
        json={
            "username": "coachuser",
            "max_games": 40,
            "max_puzzles": 5,
            "analysis_depth": 16,
            "speed_mode": "fast",
            "difficulty": "hard",
            "time_budget_seconds": 30,
        },
    )

    assert response.status_code == 200
    data = response.get_json()
    assert data["games_count"] == 1
    assert len(data["puzzles"]) == 1
    assert data["stats"]["engine_source"] == "fake"
    assert captured["username"] == "coachuser"
    assert captured["max_games"] == 20
    assert captured["analysis_depth"] == 10
    assert captured["difficulty_level"] == "hard"
    assert captured["time_budget_seconds"] == 12
    assert captured["multipv"] == 1
