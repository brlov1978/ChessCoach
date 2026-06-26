# Chess Coach

Chess Coach now uses:

- a Python backend API for downloading and analyzing Chess.com games
- a Flutter frontend for the user interface

## Features

- Fetches recent public games from the Chess.com API
- Parses PGN records with `python-chess`
- Finds tactical puzzle candidates from your real games
- Uses a local Stockfish engine by default for faster analysis
- Provides a Flutter UI for entering usernames and reviewing puzzles
- Supports SQLite-backed mistake mining with background analysis jobs

## Backend setup

1. Create or activate your Python environment
2. Install dependencies:

   ```powershell
   pip install -r requirements.txt
   ```

3. Start the backend API:

   ```powershell
   python app.py
   ```

The API will run on `http://localhost:8000`.

### Configuration file

Backend runtime settings are read from `config.json` in the project root:

```json
{
   "database_path": "chess_coach.sqlite3",
   "stockfish_path": "C:/tools/stockfish/stockfish-windows-x86-64-avx2.exe",
   "allow_cloud_fallback": false
}
```

- `database_path`: path to the SQLite database file used for analysis jobs and mistake mining.
- `stockfish_path`: absolute path to your local Stockfish executable.
- `allow_cloud_fallback`: if `true`, cloud eval can be used when local engine is unavailable.

## Flutter frontend setup

1. Change into the Flutter app folder:

   ```powershell
   cd flutter_app
   ```

2. Get packages:

   ```powershell
   flutter pub get
   ```

3. Run the app:

   ```powershell
   flutter run -d chrome
   ```

If you use an Android emulator, set the backend URL in the app to `http://10.0.2.2:8000`.

## Render deployment

This project is now set up so one Render web service can host both the backend API and the built Flutter web app.

### Recommended setup

1. Push the project to GitHub.
2. In Render, create a new Blueprint or Web Service from the repo.
3. Use the build command defined in the Render config to:
   - install Python dependencies
   - download Flutter
   - build the web frontend
4. Start the app with Gunicorn.

Once deployed, the site and API will share the same URL, so the frontend should connect automatically.

## Notes

- Only public Chess.com games can be downloaded.
- The backend now requires a local Stockfish binary by default.
- Set `stockfish_path` in `config.json` if the binary is not on your PATH.
- Set `allow_cloud_fallback` in `config.json` to allow Lichess cloud eval when no local engine is found.
- Set `database_path` in `config.json` to enable SQLite-backed analysis jobs and mistake-based puzzles.
- The first run may take a little time while positions are evaluated.

## SQLite mistake mining API

When `database_path` is configured, the backend enables these endpoints:

- `POST /api/analysis/jobs`
   - Starts a background job to process games and store move-by-move eval deltas.
   - Request fields: `username`, `months_back`, `max_games`, `analysis_depth`, `mistake_threshold_cp`.
- `GET /api/analysis/jobs/<job_id>`
   - Returns job status and progress counters.
- `POST /api/puzzles/mistakes`
   - Generates puzzles from stored repeated mistakes.
   - Request fields: `username`.
