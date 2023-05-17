// Handler that takes in an incoming HttpRequest and converts it into HttpResponse
#[tokio::main]
async fn main() -> std::io::Result<()> {
    newsletter::run().await
}
