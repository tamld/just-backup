use std::path::{Path, PathBuf};
use crate::models::manifest::{Manifest, BackupStatus, SkippedFile};
use crate::models::identity::BackupType;
use crate::engine::robocopy::run_robocopy;
use crate::models::outlook::{is_outlook_running, is_outlook_data_file};
use tracing::{info, warn, error};

pub struct BackupSession {
    pub manifest: Manifest,
    pub source: PathBuf,
    pub destination: PathBuf, // The final <target_id>/.../data/C folder equivalent
}

impl BackupSession {
    pub fn new(manifest: Manifest, source: PathBuf, destination: PathBuf) -> Self {
        Self {
            manifest,
            source,
            destination,
        }
    }

    pub fn execute(&mut self) {
        self.manifest.status = BackupStatus::Planning;
        info!("Starting backup planning...");

        if is_outlook_running() {
            warn!("Outlook is running. Email data may not be fully backed up.");
            // We should ideally scan and log PST files that might be skipped.
            // For now, we will handle skips based on Robocopy's failures or pre-scanning.
        }

        self.manifest.status = BackupStatus::Copying;
        info!("Starting copying process from {:?} to {:?}", self.source, self.destination);

        let log_file = self.destination.parent().unwrap().join(format!("log_{}.txt", self.manifest.backup.backup_id));
        let is_incremental = self.manifest.backup.backup_type == BackupType::Incremental;

        match run_robocopy(&self.source, &self.destination, &log_file, is_incremental) {
            Ok(result) => {
                if result.success {
                    info!("Robocopy succeeded with exit code: {}", result.exit_code);
                    self.manifest.status = BackupStatus::Finalizing;
                    // In a full implementation, we would parse the log_file to find skipped/failed files
                    // and populate self.manifest.skipped_files.
                } else {
                    error!("Robocopy failed with exit code: {}", result.exit_code);
                    self.manifest.status = BackupStatus::Failed(format!("Robocopy exit code {}", result.exit_code));
                }
            }
            Err(e) => {
                error!("Failed to execute Robocopy: {}", e);
                self.manifest.status = BackupStatus::Failed(e.to_string());
            }
        }

        if let BackupStatus::Finalizing = self.manifest.status {
            info!("Finalizing backup session...");
            self.manifest.status = BackupStatus::Completed;
        }
    }
}
