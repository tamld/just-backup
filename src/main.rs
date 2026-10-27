use just_backup::ui;
use tracing_subscriber;

fn main() -> eframe::Result<()> {
    tracing_subscriber::fmt::init();

    let options = eframe::NativeOptions {
        viewport: eframe::egui::ViewportBuilder::default()
            .with_inner_size([640.0, 440.0])
            .with_min_inner_size([420.0, 320.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Portable Backup Tool",
        options,
        Box::new(|cc| Ok(Box::new(ui::app::BackupApp::new(cc)))),
    )
}
