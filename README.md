# Chess Coach

Chess Coach now uses:

- a Python backend API for downloading and analyzing Chess.com games
- a Flutter frontend for the user interface

## Features

- Fetches recent public games from the Chess.com API
- Parses PGN records with `python-chess`
- Finds tactical puzzle candidates from your real games
- Uses local Stockfish when available, with a cloud-eval fallback
- Provides a Flutter UI for entering usernames and reviewing puzzles

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
- If Stockfish is installed and available on your PATH, the analysis will be stronger.
- The first run may take a little time while positions are evaluated.
