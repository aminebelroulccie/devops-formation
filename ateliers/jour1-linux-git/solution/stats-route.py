# Solution personne A — à insérer dans create_app() de app.py, après la route /api/tasks
#
#     @app.get("/api/stats")
#     def stats():
#         total = Task.query.count()
#         done = Task.query.filter_by(done=True).count()
#         return jsonify(total=total, done=done, open=total - done)
#
# Solution personne B — à ajouter dans tests/test_api.py
#
#     def test_stats(client):
#         client.post("/api/tasks", json={"title": "A"})
#         t = client.post("/api/tasks", json={"title": "B"}).get_json()
#         client.put(f"/api/tasks/{t['id']}", json={"done": True})
#         r = client.get("/api/stats")
#         assert r.status_code == 200
#         assert r.get_json() == {"total": 2, "done": 1, "open": 1}
