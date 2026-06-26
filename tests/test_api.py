from app import app


def test_on_the_fly_endpoint_is_disabled():
    client = app.test_client()
    response = client.post(
        "/api/puzzles",
        json={"username": "coachuser"},
    )

    assert response.status_code == 410
    data = response.get_json()
    assert "On-the-fly generation is disabled" in data["error"]


def test_analysis_job_endpoint_accepts_request():
    client = app.test_client()
    response = client.post(
        "/api/analysis/jobs",
        json={"username": "coachuser"},
    )

    assert response.status_code in (200, 202)
    data = response.get_json()
    assert data["status"] in ("queued", "running")
    assert data["job_id"]


def test_mistake_puzzles_endpoint_returns_json():
    client = app.test_client()
    response = client.post(
        "/api/puzzles/mistakes",
        json={"username": "coachuser"},
    )

    assert response.status_code == 200
    data = response.get_json()
    assert data["username"] == "coachuser"
    assert isinstance(data["puzzles"], list)
