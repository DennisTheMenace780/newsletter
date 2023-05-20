use std::net::TcpListener;

#[tokio::test]
async fn health_check() {
    // Arrange
    let client = reqwest::Client::new(); // "web browser"
    let address = spawn_app();

    // Act
    let response = client
        .get(&format!("{}/health_check", &address))
        .send()
        .await
        .expect("Failed to execute request.");

    // Assert
    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

#[tokio::test]
async fn return_200_for_valid_form_submission() {
    // Arrange
    let address = spawn_app();
    let client = reqwest::Client::new();
    let encoded_body = "name=dennis%20/gray&email=djgray780%40gmail.com";

    // Act
    let response = client
        .post(&format!("{}/subscriptions", &address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(encoded_body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(Some(1), response.content_length())
}

#[tokio::test]
async fn return_400_for_invalid_form_submission() {
    // Arrange
    let address = spawn_app();
    let client = reqwest::Client::new();
    let test_cases = vec![
        ("name=dennis%20gray", "missing the email"),
        ("email=djgray780%40gmail.com", "missing the name"),
        ("", "missing both name and email"),
    ];

    // Act
    for (invalid_body, error_msg) in test_cases {
        let response = client
            .post(&format!("{}/subscriptions", &address))
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

fn spawn_app() -> String {
    // The function sets up a TcpListener that waits for requests on IP:PORT.
    // Since we have set a random port, we'll figure out which port the listener is active on.
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind to random port");
    let port = listener
        .local_addr()
        .expect("Could not return port number")
        .port();
    // Once we know that active port we can pass the listener into the server and
    // run the application as a background Tokio task.
    let server = newsletter::run(listener).expect("Failed to bind address");
    let _ = tokio::spawn(server);
    format!("http://127.0.0.1:{}", port)
}
