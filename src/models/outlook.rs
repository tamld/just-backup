use sysinfo::{System, Process};
use std::path::Path;

pub fn is_outlook_running() -> bool {
    let mut sys = System::new_all();
    sys.refresh_processes(sysinfo::ProcessesToUpdate::All, true);

    for (_, process) in sys.processes() {
        if let Some(name) = process.name().to_str() {
            if name.to_lowercase().contains("outlook.exe") {
                return true;
            }
        }
    }
    false
}

pub fn is_outlook_data_file(path: &Path) -> bool {
    if let Some(ext) = path.extension() {
        let ext = ext.to_string_lossy().to_lowercase();
        return ext == "pst" || ext == "ost";
    }
    false
}
