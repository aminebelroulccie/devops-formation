//! API Formini (Rust / tiny_http) — même contrat que les API Go, Python et Node.
//!   GET  /health      → "ok"
//!   GET  /api/info    → identité du service + état de PostgreSQL et Redis
//!   GET  /api/tasks   → liste des tâches (table partagée)
//!   POST /api/tasks   → {"title": "..."} crée une tâche
//!   GET  /api/hits    → incrémente et renvoie le compteur Redis de ce service
use std::env;
use std::io::Read;

use chrono::{DateTime, Utc};
use postgres::{Client, NoTls};
use redis::Commands;
use serde::{Deserialize, Serialize};
use serde_json::json;
use tiny_http::{Header, Method, Request, Response, Server};

const SERVICE: &str = "api-rust";

#[derive(Serialize)]
struct Task {
    id: i32,
    title: String,
    done: bool,
    created_by: String,
    created_at: DateTime<Utc>,
}

#[derive(Deserialize)]
struct TaskIn {
    title: String,
}

struct App {
    db: Client,
    cache: redis::Connection,
}

fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".into());
    let db_url = env::var("DATABASE_URL").expect("DATABASE_URL manquante");
    let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| "redis://cache:6379/0".into());

    let db = Client::connect(&db_url, NoTls).expect("connexion PostgreSQL");
    let cache = redis::Client::open(redis_url)
        .expect("URL Redis")
        .get_connection()
        .expect("connexion Redis");
    let mut app = App { db, cache };

    let server = Server::http(format!("0.0.0.0:{port}")).expect("port occupé");
    eprintln!("{SERVICE} en écoute sur :{port}");

    for request in server.incoming_requests() {
        let method = request.method().clone();
        let url = request.url().to_string();
        let response = app.route(&method, &url, request);
        if let Err(e) = response {
            eprintln!("erreur : {e}");
        }
    }
}

impl App {
    fn route(&mut self, method: &Method, url: &str, mut req: Request) -> std::io::Result<()> {
        match (method, url) {
            (&Method::Get, "/health") => req.respond(Response::from_string("ok")),
            (&Method::Get, "/api/info") => {
                let pg = match self.db.simple_query("SELECT 1") {
                    Ok(_) => "ok".to_string(),
                    Err(e) => format!("erreur : {e}"),
                };
                let rd = match redis::cmd("PING").query::<String>(&mut self.cache) {
                    Ok(_) => "ok".to_string(),
                    Err(e) => format!("erreur : {e}"),
                };
                let body = json!({
                    "service": SERVICE,
                    // RUSTC_VERSION est fourni par le Dockerfile au moment de la compilation
                    "language": format!("Rust {}", option_env!("RUSTC_VERSION").unwrap_or("?")),
                    "hostname": env::var("HOSTNAME").unwrap_or_else(|_| "inconnu".into()),
                    "postgres": pg,
                    "redis": rd,
                });
                req.respond(json_response(200, &body))
            }
            (&Method::Get, "/api/tasks") => match self.list_tasks() {
                Ok(tasks) => req.respond(json_response(200, &json!(tasks))),
                Err(e) => req.respond(json_response(500, &json!({ "error": e.to_string() }))),
            },
            (&Method::Post, "/api/tasks") => {
                let mut body = String::new();
                req.as_reader().read_to_string(&mut body)?;
                let title = serde_json::from_str::<TaskIn>(&body)
                    .map(|t| t.title.trim().to_string())
                    .unwrap_or_default();
                if title.is_empty() {
                    return req.respond(json_response(400, &json!({ "error": "title requis" })));
                }
                match self.create_task(&title) {
                    Ok(t) => req.respond(json_response(201, &json!(t))),
                    Err(e) => req.respond(json_response(500, &json!({ "error": e.to_string() }))),
                }
            }
            (&Method::Get, "/api/hits") => {
                let r: redis::RedisResult<i64> = self.cache.incr(format!("hits:{SERVICE}"), 1);
                match r {
                    Ok(n) => req.respond(json_response(200, &json!({ "service": SERVICE, "hits": n }))),
                    Err(e) => req.respond(json_response(500, &json!({ "error": e.to_string() }))),
                }
            }
            _ => req.respond(json_response(404, &json!({ "error": "route inconnue" }))),
        }
    }

    fn list_tasks(&mut self) -> Result<Vec<Task>, postgres::Error> {
        let rows = self.db.query(
            "SELECT id, title, done, created_by, created_at FROM tasks ORDER BY id DESC LIMIT 50",
            &[],
        )?;
        Ok(rows.iter().map(row_to_task).collect())
    }

    fn create_task(&mut self, title: &str) -> Result<Task, postgres::Error> {
        let row = self.db.query_one(
            "INSERT INTO tasks (title, created_by) VALUES ($1, $2) RETURNING id, title, done, created_by, created_at",
            &[&title, &SERVICE],
        )?;
        Ok(row_to_task(&row))
    }
}

fn row_to_task(r: &postgres::Row) -> Task {
    Task {
        id: r.get("id"),
        title: r.get("title"),
        done: r.get("done"),
        created_by: r.get("created_by"),
        created_at: r.get("created_at"),
    }
}

fn json_response(status: u16, body: &serde_json::Value) -> Response<std::io::Cursor<Vec<u8>>> {
    Response::from_string(body.to_string())
        .with_status_code(status)
        .with_header(Header::from_bytes("Content-Type", "application/json").unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;

    // Test unitaire sans base ni cache : la construction d'une réponse JSON.
    #[test]
    fn json_response_sets_status_and_content_type() {
        let r = json_response(201, &json!({ "service": SERVICE }));
        assert_eq!(r.status_code().0, 201);
        let ct = r
            .headers()
            .iter()
            .find(|h| h.field.equiv("Content-Type"))
            .map(|h| h.value.as_str().to_string());
        assert_eq!(ct.as_deref(), Some("application/json"));
    }
}
