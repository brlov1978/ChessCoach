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

    monkeypatch.setattr("app.fetch_recent_games", lambda username, max_games=10: sample_games)
    monkeypatch.setattr(
        "app.generate_puzzles",
        lambda games, username, max_puzzles=5, analysis_depth=12: (sample_puzzles, {"games_scanned": 1, "positions_checked": 4, "engine_source": "fake"}),
    )

    client = app.test_client()
    response = client.post(
        "/api/puzzles",
        json={
            "username": "coachuser",
            "max_games": 10,
            "max_puzzles": 5,
            "analysis_depth": 12,
        },
    )

    assert response.status_code == 200
    data = response.get_json()
    assert data["games_count"] == 1
    assert len(data["puzzles"]) == 1
    assert data["stats"]["engine_source"] == "fake"
