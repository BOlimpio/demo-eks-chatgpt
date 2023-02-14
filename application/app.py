from flask import Flask, request
from flask_sqlalchemy import SQLAlchemy
from prometheus_client import Counter, Histogram, REGISTRY, make_wsgi_app
import functools

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///demo-eks-chatgpt.db'
db = SQLAlchemy(app)

# Define a counter and histogram metric for requests
REQUESTS_COUNTER = Counter(
    'demo_eks_chatgpt_requests_total', 
    'Number of requests to the demo-eks-chatgpt API',
    ['endpoint']
)

REQUEST_LATENCY = Histogram(
    'demo_eks_chatgpt_request_latency_seconds', 
    'Latency of requests to the demo-eks-chatgpt API',
    ['endpoint']
)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)

    def __repr__(self):
        return '<User %r>' % self.username

db.create_all()

# Decorators to track request count and latency
def track_requests(func):
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        endpoint = request.path
        REQUESTS_COUNTER.labels(endpoint).inc()
        with REQUEST_LATENCY.labels(endpoint).time():
            return func(*args, **kwargs)
    return wrapper

@app.route('/user', methods=['POST'])
@track_requests
def create_user():
    data = request.get_json()
    new_user = User(username=data['username'], email=data['email'])
    db.session.add(new_user)
    db.session.commit()
    return 'User created', 201

@app.route('/user/<int:id>', methods=['GET'])
@track_requests
def get_user(id):
    user = User.query.get(id)
    if not user:
        return 'User not found', 404
    return {'username': user.username, 'email': user.email}, 200

@app.route('/user/<int:id>', methods=['PUT'])
@track_requests
def update_user(id):
    user = User.query.get(id)
    if not user:
        return 'User not found', 404
    data = request.get_json()
    user.username = data['username']
    user.email = data['email']
    db.session.commit()
    return 'User updated', 200

@app.route('/user/<int:id>', methods=['DELETE'])
@track_requests
def delete_user(id):
    user = User.query.get(id)
    if not user:
        return 'User not found', 404
    db.session.delete(user)
    db.session.commit()
    return 'User deleted', 200

# Expose Prometheus metrics endpoint
metrics_app = make_wsgi_app()
app.wsgi_app = metrics_app

if __name__ == '__main__':
    app.run()
