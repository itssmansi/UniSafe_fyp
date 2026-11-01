from flask import Flask
from routes.missing_persons import missing_person_bp
from routes.sightings import sightings_bp
from routes.auth import auth_bp

app = Flask(__name__)

app.register_blueprint(auth_bp)
app.register_blueprint(missing_person_bp)
app.register_blueprint(sightings_bp)

@app.get("/health")
def health():
    return {"status": "ok"}

if __name__ == "__main__":
    app.run(host='0.0.0.0', debug=True)