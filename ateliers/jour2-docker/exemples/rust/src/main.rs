//! Formini Hello — service HTTP minimal en Rust (tiny_http).
//! Routes : GET /  → JSON de bienvenue, GET /health → 200 "ok".
use std::env;
use tiny_http::{Header, Response, Server};

fn main() {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{port}");
    let server = Server::http(&addr).expect("impossible d'ouvrir le port");
    let hostname = env::var("HOSTNAME").unwrap_or_else(|_| "inconnu".to_string());
    eprintln!("formini-hello-rust en écoute sur {addr}");

    for request in server.incoming_requests() {
        let response = match request.url() {
            "/health" => Response::from_string("ok"),
            path => {
                let body = format!(
                    r#"{{"service":"formini-hello-rust","message":"Bonjour Formini","path":"{path}","hostname":"{hostname}"}}"#
                );
                Response::from_string(body).with_header(
                    Header::from_bytes("Content-Type", "application/json").unwrap(),
                )
            }
        };
        let _ = request.respond(response);
    }
}
