use newsletter::{
    config::{get_configuration, DatabaseSettings},
    startup::run,
};
use sqlx::{Connection, Executor, PgConnection, PgPool};
use std::net::TcpListener;
use uuid::Uuid;

pub struct TestApp {
    pub address: String,
    pub connection_pool: PgPool,
}

#[tokio::test]
async fn health_check() {
    // Arrange
    let client = reqwest::Client::new(); // "web browser"
    let test_app = spawn_app().await;

    // Act
    let response = client
        .get(&format!("{}/health_check", &test_app.address))
        .send()
        .await
        .expect("Failed to execute request.");

    // Assert
    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

#[tokio::test]
async fn subscribe_returns_200_for_valid_form_submission() {
    // Arrange
    let test_app = spawn_app().await;
    let client = reqwest::Client::new();
    let encoded_body = "name=le%20guin&email=ursula_le_guin%40gmail.com";

    // Act
    let response = client
        .post(&format!("{}/subscriptions", &test_app.address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(encoded_body)
        .send()
        .await
        .expect("Failed to execute request.");

    // Assert
    assert_eq!(200, response.status().as_u16());

    let saved = sqlx::query!("SELECT email, name FROM subscriptions")
        .fetch_one(&test_app.connection_pool)
        .await
        .expect("Failed to fetch saved subscription");

    assert_eq!(saved.email, "ursula_le_guin@gmail.com");
    assert_eq!(saved.name, "le guin");
}

#[tokio::test]
async fn return_400_for_invalid_form_submission() {
    // Arrange
    let test_app = spawn_app().await;
    let client = reqwest::Client::new();
    let test_cases = vec![
        ("name=dennis%20gray", "missing the email"),
        ("email=djgray780%40gmail.com", "missing the name"),
        ("", "missing both name and email"),
    ];

    // Act
    for (invalid_body, error_msg) in test_cases {
        let response = client
            .post(&format!("{}/subscriptions", &test_app.address))
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(invalid_body)
            .send()
            .await
            .expect(error_msg);

        // Assert
        assert_eq!(
            400,
            response.status().as_u16(),
            // Message on test failure
            "API did not fail w/ 400 Bad Request when payload was {} ",
            error_msg
        )
    }
}

async fn spawn_app() -> TestApp {
    // The function sets up a TcpListener that waits for requests on IP:PORT.
    // Since we have set a random port, we'll figure out which port the listener is active on.
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind to random port");
    let port = listener
        .local_addr()
        .expect("Could not return port number")
        .port();
    let address = format!("http://127.0.0.1:{}", port);
    let mut configuration = get_configuration().expect("Failed to read configuration");
    // Randomize DB name for testing
    configuration.database.db_name = Uuid::new_v4().to_string();
    let connection_pool = configure_database(&configuration.database).await;
    // Once we know that active port we can pass the listener into the server and
    // run the application as a background Tokio task.
    let server = run(listener, connection_pool.clone()).expect("Failed to bind address");
    let _ = tokio::spawn(server);
    TestApp {
        address,
        connection_pool,
    }
}

pub async fn configure_database(config: &DatabaseSettings) -> PgPool {
    let mut connection = PgConnection::connect(&config.connection_string_without_db())
        .await
        .expect("Failed to connect to Postgres");
    connection
        .execute(&*format!(r#"CREATE DATABASE "{}";"#, config.db_name))
        .await
        .expect("Failed to create database.");
    // Migrate database
    let connection_pool = PgPool::connect(&config.connection_string())
        .await
        .expect("Failed to connect to Postgres.");
    sqlx::migrate!("./migrations")
        .run(&connection_pool)
        .await
        .expect("Failed to migrate the database");
    connection_pool
}
