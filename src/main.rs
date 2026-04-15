mod models;
mod engine;
mod restore;
mod ui;

use tracing_subscriber;

fn main() -> eframe::Result<()> {
    tracing_subscriber::fmt::init();

    let options = eframe::NativeOptions {
        viewport: eframe::egui::ViewportBuilder::default().with_inner_size([600.0, 400.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Portable Backup Tool",
        options,
        Box::new(|cc| Ok(Box::new(ui::app::BackupApp::new(cc)))),
    )
}
