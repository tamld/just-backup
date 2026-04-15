use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Machine {
    pub machine_id: String,
    pub hostname: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct User {
    pub user_id: String, // SID or equivalent
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Target {
    pub target_id: String, // Volume identity
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum BackupType {
    Full,
    Incremental,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Backup {
    pub backup_id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub backup_type: BackupType,
}

impl Backup {
    pub fn new(backup_type: BackupType) -> Self {
        Self {
            backup_id: Uuid::new_v4(),
            timestamp: Utc::now(),
            backup_type,
        }
    }
}
