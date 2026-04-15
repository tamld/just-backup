use serde::{Deserialize, Serialize};
use crate::models::identity::{Machine, User, Backup};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub machine: Machine,
    pub user: User,
    pub backup: Backup,
    pub skipped_files: Vec<SkippedFile>,
    pub deleted_files: Vec<String>, // Paths relative to source
    pub status: BackupStatus,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkippedFile {
    pub path: String,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum BackupStatus {
    Scanning,
    Planning,
    Copying,
    Finalizing,
    Completed,
    Failed(String),
}

impl Manifest {
    pub fn new(machine: Machine, user: User, backup: Backup) -> Self {
        Self {
            machine,
            user,
            backup,
            skipped_files: Vec::new(),
            deleted_files: Vec::new(),
            status: BackupStatus::Scanning,
        }
    }
}
