use sysinfo::{Disk, Disks};
use std::path::{Path, PathBuf};
use std::ffi::OsStr;

pub trait DiskExt {
    fn file_system(&self) -> &OsStr;
    fn total_space(&self) -> u64;
    fn mount_point(&self) -> &Path;
    fn available_space(&self) -> u64;
}

impl DiskExt for Disk {
    fn file_system(&self) -> &OsStr {
        self.file_system()
    }
    fn total_space(&self) -> u64 {
        self.total_space()
    }
    fn mount_point(&self) -> &Path {
        self.mount_point()
    }
    fn available_space(&self) -> u64 {
        self.available_space()
    }
}

#[derive(Debug, Clone)]
pub struct DriveInfo {
    pub mount_point: PathBuf,
    pub volume_id: String, // Or file system ID
    pub available_space: u64,
}

pub fn extract_drive_info<'a, I, D>(disks: I) -> Vec<DriveInfo>
where
    I: IntoIterator<Item = &'a D>,
    D: DiskExt + 'a,
{
    let mut available = Vec::new();

    for disk in disks {
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

pub fn get_available_drives() -> Vec<DriveInfo> {
    let disks = Disks::new_with_refreshed_list();
    extract_drive_info(disks.list())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;

    struct MockDisk {
        file_system: OsString,
        total_space: u64,
        mount_point: PathBuf,
        available_space: u64,
    }

    impl DiskExt for MockDisk {
        fn file_system(&self) -> &OsStr {
            &self.file_system
        }
        fn total_space(&self) -> u64 {
            self.total_space
        }
        fn mount_point(&self) -> &Path {
            &self.mount_point
        }
        fn available_space(&self) -> u64 {
            self.available_space
        }
    }

    #[test]
    fn test_extract_drive_info_empty() {
        let disks: Vec<MockDisk> = vec![];
        let drives = extract_drive_info(&disks);
        assert!(drives.is_empty());
    }

    #[test]
    fn test_extract_drive_info_single() {
        let disk = MockDisk {
            file_system: OsString::from("NTFS"),
            total_space: 1000000,
            mount_point: PathBuf::from("C:\\"),
            available_space: 500000,
        };
        let disks = vec![disk];

        let drives = extract_drive_info(&disks);

        assert_eq!(drives.len(), 1);
        let drive = &drives[0];

        assert_eq!(drive.mount_point, PathBuf::from("C:\\"));
        assert_eq!(drive.available_space, 500000);
        // Fallback ID is format!("{:?}-{}", disk.file_system(), disk.total_space())
        assert_eq!(drive.volume_id, "\"NTFS\"-1000000");
    }

    #[test]
    fn test_extract_drive_info_multiple() {
        let disk1 = MockDisk {
            file_system: OsString::from("NTFS"),
            total_space: 1000000,
            mount_point: PathBuf::from("C:\\"),
            available_space: 500000,
        };
        let disk2 = MockDisk {
            file_system: OsString::from("FAT32"),
            total_space: 2000000,
            mount_point: PathBuf::from("D:\\"),
            available_space: 1500000,
        };
        let disks = vec![disk1, disk2];

        let drives = extract_drive_info(&disks);

        assert_eq!(drives.len(), 2);

        assert_eq!(drives[0].mount_point, PathBuf::from("C:\\"));
        assert_eq!(drives[0].volume_id, "\"NTFS\"-1000000");

        assert_eq!(drives[1].mount_point, PathBuf::from("D:\\"));
        assert_eq!(drives[1].volume_id, "\"FAT32\"-2000000");
        assert_eq!(drives[1].available_space, 1500000);
    }
}
