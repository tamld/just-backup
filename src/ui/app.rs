use eframe::egui;
use std::path::PathBuf;
use std::thread;
use crossbeam_channel::{unbounded, Receiver, Sender};
use crate::engine::backup::BackupSession;
use crate::restore::engine::restore_files;
use crate::models::manifest::Manifest;
use crate::models::identity::{Machine, User, Backup as BackupModel, BackupType};
use crate::models::drive::get_available_drives;

pub struct BackupApp {
    source_path: String,
    destination_path: String,
    status_msg: String,
    logs: Vec<String>,
    log_receiver: Receiver<String>,
    log_sender: Sender<String>,
}

impl Default for BackupApp {
    fn default() -> Self {
        let (log_sender, log_receiver) = unbounded();
        Self {
            source_path: String::new(),
            destination_path: String::new(),
            status_msg: String::new(),
            logs: Vec::new(),
            log_receiver,
            log_sender,
        }
    }
}

impl BackupApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        Self::default()
    }
}

impl eframe::App for BackupApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Drain incoming logs
        while let Ok(msg) = self.log_receiver.try_recv() {
            self.logs.push(msg.clone());
            self.status_msg = msg;
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Portable Backup Tool");

            ui.add_space(10.0);

            ui.horizontal(|ui| {
                ui.label("Nguồn (Source):");
                ui.text_edit_singleline(&mut self.source_path);
            });

            ui.horizontal(|ui| {
                ui.label("Đích (Destination):");
                ui.text_edit_singleline(&mut self.destination_path);
            });

            ui.add_space(10.0);

            ui.horizontal(|ui| {
                if ui.button("Dò ổ đĩa (Scan Drives)").clicked() {
                    let drives = get_available_drives();
                    for d in drives {
                        self.logs.push(format!("Phát hiện ổ đĩa: {:?} - ID: {}", d.mount_point, d.volume_id));
                    }
                }
            });

            ui.add_space(10.0);

            ui.horizontal(|ui| {
                if ui.button("Sao lưu (Backup)").clicked() {
                    let src = self.source_path.clone();
                    let dst = self.destination_path.clone();
                    let tx = self.log_sender.clone();

                    if src.is_empty() || dst.is_empty() {
                        let _ = tx.send("Lỗi: Nguồn và đích không được để trống.".into());
                    } else {
                        let _ = tx.send("Bắt đầu sao lưu trong nền...".into());
                        thread::spawn(move || {
                            let machine = Machine { machine_id: "local_id".into(), hostname: "local_host".into() };
                            let user = User { user_id: "local_user".into() };
                            let backup = BackupModel::new(BackupType::Full);
                            let manifest = Manifest::new(machine, user, backup);

                            let mut session = BackupSession::new(
                                manifest,
                                PathBuf::from(src),
                                PathBuf::from(dst)
                            );

                            let _ = tx.send("Đang lập kế hoạch... (Planning...)".into());
                            session.execute();
                            let _ = tx.send(format!("Trạng thái sao lưu: {:?}", session.manifest.status));
                        });
                    }
                }

                if ui.button("Phục hồi (Restore)").clicked() {
                    let src = self.destination_path.clone(); // In restore, dest is source
                    let dst = self.source_path.clone(); // In restore, source is dest
                    let tx = self.log_sender.clone();

                    if src.is_empty() || dst.is_empty() {
                        let _ = tx.send("Lỗi: Nguồn và đích không được để trống.".into());
                    } else {
                        let _ = tx.send("Bắt đầu phục hồi trong nền...".into());
                        thread::spawn(move || {
                            match restore_files(&PathBuf::from(&src), &PathBuf::from(&dst)) {
                                Ok(_) => { let _ = tx.send("Phục hồi thành công.".into()); },
                                Err(e) => { let _ = tx.send(format!("Lỗi phục hồi: {}", e)); }
                            }
                        });
                    }
                }
            });

            ui.add_space(10.0);
            ui.label(format!("Trạng thái: {}", self.status_msg));

            ui.add_space(10.0);
            ui.separator();
            ui.heading("Nhật ký (Logs)");

            egui::ScrollArea::vertical().show(ui, |ui| {
                for log in &self.logs {
                    ui.label(log);
                }
            });
        });
    }
}
