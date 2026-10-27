use eframe::egui;
use std::path::PathBuf;
use std::thread;
use crossbeam_channel::{unbounded, Receiver, Sender};
use crate::models::identity::{Machine, User, Backup as BackupModel, BackupType};
use crate::models::manifest::Manifest;
use crate::engine::backup::BackupSession;
use crate::restore::engine::restore_files;
use crate::models::drive::get_available_drives;

pub const MAX_LOG_ITEMS: usize = 500;
pub const MAX_LOGS_PER_FRAME: usize = 64;

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
            logs: Vec::with_capacity(128),
            log_receiver,
            log_sender,
        }
    }
}

impl BackupApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        Self::default()
    }

    pub fn push_log(&mut self, msg: String) {
        self.logs.push(msg);
        if self.logs.len() > MAX_LOG_ITEMS {
            let overflow = self.logs.len() - MAX_LOG_ITEMS;
            self.logs.drain(0..overflow);
        }
    }

    pub fn drain_channel_logs(&mut self) -> usize {
        let mut drained = 0;
        while drained < MAX_LOGS_PER_FRAME {
            match self.log_receiver.try_recv() {
                Ok(msg) => {
                    self.status_msg = msg.clone();
                    self.push_log(msg);
                    drained += 1;
                }
                Err(_) => break,
            }
        }
        drained
    }

    pub fn logs(&self) -> &[String] {
        &self.logs
    }

    pub fn log_sender(&self) -> Sender<String> {
        self.log_sender.clone()
    }
}

impl eframe::App for BackupApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // Batched non-blocking log drain with bounded ring buffer
        let drained = self.drain_channel_logs();
        if drained == MAX_LOGS_PER_FRAME {
            ctx.request_repaint();
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Portable Backup Tool");
            ui.add_space(10.0);

            egui::Grid::new("backup_paths_grid")
                .num_columns(2)
                .min_col_width(110.0)
                .spacing([12.0, 8.0])
                .show(ui, |ui| {
                    ui.label("Nguồn (Source):");
                    ui.add_sized(
                        [ui.available_width(), 24.0],
                        egui::TextEdit::singleline(&mut self.source_path),
                    );
                    ui.end_row();

                    ui.label("Đích (Destination):");
                    ui.add_sized(
                        [ui.available_width(), 24.0],
                        egui::TextEdit::singleline(&mut self.destination_path),
                    );
                    ui.end_row();
                });

            ui.add_space(10.0);

            ui.horizontal_wrapped(|ui| {
                if ui.button("Dò ổ đĩa (Scan Drives)").clicked() {
                    let drives = get_available_drives();
                    for d in drives {
                        self.push_log(format!("Phát hiện ổ đĩa: {:?} - ID: {}", d.mount_point, d.volume_id));
                    }
                }

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
                    let src = self.destination_path.clone();
                    let dst = self.source_path.clone();
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
            ui.add(egui::Label::new(format!("Trạng thái: {}", self.status_msg)).wrap());

            ui.add_space(10.0);
            ui.separator();
            ui.heading("Nhật ký (Logs)");

            egui::ScrollArea::vertical()
                .auto_shrink([false; 2])
                .stick_to_bottom(true)
                .show(ui, |ui| {
                    for log in &self.logs {
                        ui.add(egui::Label::new(log).wrap());
                    }
                });
        });
    }
}
