## How to use

For the app to work you need to create an env file at `backend/.env` with an OpenAI key:

```
# backend/.env
OPENAI_API_KEY=sk-proj-<key>
```

Then start the Python server:

```
cd backend
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Then open the main app in Xcode and click 'Run'
