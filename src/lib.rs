use actix_web::dev::Server;
use actix_web::{web, App, HttpResponse, HttpServer};
use std::net::TcpListener;

pub fn run(address: TcpListener) -> Result<Server, std::io::Error> {
    let server = HttpServer::new(|| App::new().route("/health_check", web::get().to(health_check)))
        .listen(address)?
        .run();
    Ok(server)
}

pub async fn health_check() -> HttpResponse {
    // Note that the `HttpResonderBuilder implements the Responder trait
    HttpResponse::Ok().finish()
}
