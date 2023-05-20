use std::net::TcpListener;

#[tokio::test]
async fn health_check() {
    // Arrange
    let address = spawn_app();
    let client = reqwest::Client::new();

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

fn spawn_app() -> String {
    // The function sets up a TcpListener that waits for requests on IP:PORT.
    // Since we have set a random port, we'll figure out which port the listener is active on.
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind to random port");
    let port = listener.local_addr().expect("Could not return port number").port();
    // Once we know that active port we can pass the listener into the server and 
    // run the application as a background Tokio task. 
    let server = newsletter::run(listener).expect("Failed to bind address");
    let _ = tokio::spawn(server);
    format!("http://127.0.0.1:{}", port)
}



