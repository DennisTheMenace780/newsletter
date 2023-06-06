use newsletter::config::get_configuration;
use newsletter::startup::run;

use std::net::TcpListener;

#[tokio::main]
async fn main() -> std::io::Result<()> {
    let cfg = get_configuration().expect("Failed to read configuration file");
    let address = format!("{}:{}", cfg.application_host, cfg.application_port);
    let listener = TcpListener::bind(&address).expect("Failed to bind to {&address}");
    run(listener)?.await
}
