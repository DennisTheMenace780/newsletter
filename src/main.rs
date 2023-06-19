use env_logger::Env;
use newsletter::config::get_configuration;
use newsletter::startup::run;
use sqlx::PgPool;

use std::net::TcpListener;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    // Enable application wide logging
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();

    let cfg = get_configuration().expect("Failed to read configuration file");
    let connection = PgPool::connect(&cfg.database.connection_string())
        .await
        .expect("Failed to connect to Postgres");
    let address = format!("{}:{}", cfg.application_host, cfg.application_port);
    let listener = TcpListener::bind(&address).expect("Failed to bind to {&address}");
    run(listener, connection)?.await
}
