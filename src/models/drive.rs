use sysinfo::{Disks, System};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct DriveInfo {
    pub mount_point: PathBuf,
    pub volume_id: String, // Or file system ID
    pub available_space: u64,
}

pub fn get_available_drives() -> Vec<DriveInfo> {
    let disks = Disks::new_with_refreshed_list();
    let mut available = Vec::new();

    for disk in disks.list() {
        // Simple fallback for volume_id if sysinfo doesn't provide a unique stable ID easily on windows
        // In a real windows scenario we'd use GetVolumeInformationW
        // Here we'll use a combination of file_system and total space as a mock ID, or real one if possible

        let vol_id = format!("{:?}-{}", disk.file_system(), disk.total_space());

        available.push(DriveInfo {
            mount_point: disk.mount_point().to_path_buf(),
            volume_id: vol_id,
            available_space: disk.available_space(),
        });
    }

    available
}
