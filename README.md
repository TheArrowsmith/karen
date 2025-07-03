## How to use

Karen is a standalone macOS app that includes its own Python backend server. Simply:

1. **Set your OpenAI API key as an environment variable:**
   ```bash
   export OPENAI_API_KEY=sk-proj-<your-key>
   ```
   
   Or add it to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.)

2. **Launch the app:** Just open `Karen.app` - the backend server starts automatically!

The app bundles its own Python runtime and dependencies, so no need to install Python or manage virtual environments.

## Development Setup

If you're developing Karen, you can still run the backend manually for testing:

```bash
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

The production app includes the backend as a single binary built with PyInstaller.
