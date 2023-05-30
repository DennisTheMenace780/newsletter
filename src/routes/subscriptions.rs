use actix_web::{web::Form, HttpResponse};
use serde::Deserialize;

pub async fn subscribe(Form(form): Form<EmailInfo>) -> HttpResponse {
    println!("{} and {}", form.email, form.name);
    HttpResponse::Ok().finish()
}

#[derive(Deserialize)]
pub struct EmailInfo {
    pub email: String,
    pub name: String,
}
