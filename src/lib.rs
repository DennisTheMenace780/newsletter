use actix_web::dev::Server;
use actix_web::{web, App, HttpResponse, HttpServer};
use serde::Deserialize;
use std::net::TcpListener;
// Extractors
use actix_web::web::Form;

pub fn run(address: TcpListener) -> Result<Server, std::io::Error> {
    let server = HttpServer::new(|| {
        App::new()
            .route("/health_check", web::get().to(health_check))
            .route("/subscriptions", web::post().to(subscribe))
    })
    .listen(address)?
    .run();
    Ok(server)
}

pub async fn health_check() -> HttpResponse {
    HttpResponse::Ok().finish()
}

pub async fn subscribe(Form(form): Form<EmailInfo>) -> HttpResponse {
    println!("{} and {}", form.email, form.name);
    HttpResponse::Ok().finish()
}

#[derive(Deserialize)]
pub struct EmailInfo {
    email: String,
    name: String,
}
