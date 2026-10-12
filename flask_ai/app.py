from flask import Flask
from routes.missing_persons import missing_person_bp

app = Flask(__name__)

app.register_blueprint(missing_person_bp)   # tells Flask Add all the routes contained inside this Blueprint to this application

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)