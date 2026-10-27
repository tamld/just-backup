use std::fs;
use std::path::Path;
use just_backup::models::outlook::is_outlook_data_file;
use just_backup::models::manifest::{BackupStatus, Manifest};
use just_backup::models::identity::{Backup, BackupType, Machine, User};
use just_backup::restore::engine::restore_files;
use just_backup::ui::app::{BackupApp, MAX_LOG_ITEMS, MAX_LOGS_PER_FRAME};

#[test]
fn test_unicode_path_handling() {
    let test_dir = Path::new("test_unicode_temp");
    fs::create_dir_all(test_dir).unwrap();

    let unicode_folder = test_dir.join("NguoiDung").join("Tài liệu");
    fs::create_dir_all(&unicode_folder).unwrap();

    let file_path = unicode_folder.join("test_file_ảnh.txt");
    fs::write(&file_path, "test data").unwrap();

    assert!(file_path.exists());

    fs::remove_dir_all(test_dir).unwrap();
}

#[test]
fn test_is_outlook_data_file_authentic_import() {
    assert!(is_outlook_data_file(Path::new("C:\\path\\data.pst")));
    assert!(is_outlook_data_file(Path::new("C:\\path\\data.ost")));
    assert!(is_outlook_data_file(Path::new("C:\\path\\ARCHIVE.PST")));
    assert!(!is_outlook_data_file(Path::new("C:\\path\\data.txt")));
    assert!(!is_outlook_data_file(Path::new("C:\\path\\no_extension")));
}

#[test]
fn test_manifest_and_error_handling_model() {
    let machine = Machine {
        machine_id: "m-01".into(),
        hostname: "workstation".into(),
    };
    let user = User {
        user_id: "S-1-5-21".into(),
    };
    let backup = Backup::new(BackupType::Full);
    let manifest = Manifest::new(machine, user, backup);
    assert_eq!(manifest.status, BackupStatus::Scanning);

    let failed_json = r#"{"Failed":"Access Denied"}"#;
    let decoded: BackupStatus = serde_json::from_str(failed_json).unwrap();
    assert_eq!(decoded, BackupStatus::Failed("Access Denied".into()));
}

#[test]
fn test_restore_files_engine_edge_cases() {
    let missing_src = Path::new("nonexistent_restore_src_9999");
    let missing_dst = Path::new("nonexistent_restore_dst_9999");
    let res = restore_files(missing_src, missing_dst);
    // On non-Windows or missing robocopy / invalid path, restore_files cleanly returns Err
    assert!(res.is_err());
}

#[test]
fn test_ui_log_batching_and_memory_cap() {
    let mut app = BackupApp::default();
    let tx = app.log_sender();
    for i in 0..(MAX_LOG_ITEMS + 120) {
        tx.send(format!("log-entry-{}", i)).unwrap();
    }

    let first_batch = app.drain_channel_logs();
    assert_eq!(first_batch, MAX_LOGS_PER_FRAME);

    while app.drain_channel_logs() > 0 {}

    assert_eq!(app.logs().len(), MAX_LOG_ITEMS);
    assert_eq!(app.logs().first().unwrap(), "log-entry-120");
}
