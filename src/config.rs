use config;
use serde::Deserialize;

#[derive(Deserialize)]
pub struct Settings {
    pub database: DatabaseSettings,
    pub application_port: u16,
    pub application_host: String,
}

#[derive(Deserialize)]
pub struct DatabaseSettings {
    pub username: String,
    pub password: String,
    pub db_name: String,
    pub port: u16,
    pub host: String,
}

pub fn get_configuration() -> Result<Settings, config::ConfigError> {
    // Since we're using a version of config greater than 12, the documentation recommends using
    // the builder pattern.
    let settings = config::Config::builder().add_source(config::File::new(
        "configuration.yaml",
        config::FileFormat::Yaml,
    ));

    let settings = match settings.build() {
        Ok(settings) => settings,
        Err(e) => return Err(e),
    };

    settings.try_deserialize::<Settings>()
}
