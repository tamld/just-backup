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

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;
    use std::fs;
    use std::process::Command;
    use std::time::Duration;

    #[test]
    fn test_is_outlook_data_file() {
        assert!(is_outlook_data_file(Path::new("test.pst")));
        assert!(is_outlook_data_file(Path::new("test.ost")));
        assert!(is_outlook_data_file(Path::new("TEST.PST")));
        assert!(is_outlook_data_file(Path::new("TEST.OST")));
        assert!(!is_outlook_data_file(Path::new("test.txt")));
        assert!(!is_outlook_data_file(Path::new("test")));
        assert!(!is_outlook_data_file(Path::new("pst"))); // No extension, just name "pst"
    }

    #[test]
    fn test_is_outlook_running() {
        // Create an isolated temp directory to avoid conflicts
        let uuid = uuid::Uuid::new_v4();
        let temp_dir = env::temp_dir().join(uuid.to_string());
        fs::create_dir_all(&temp_dir).expect("Failed to create isolated temp dir");

        // The process name check looks for "outlook.exe" substring, so the binary name should be "outlook.exe"
        let dummy_exe = temp_dir.join("outlook.exe");

        // Copy a long-running benign command to "outlook.exe" to simulate the process.
        // On Unix, `sleep` is ubiquitous. On Windows, `ping` is used because `timeout` fails without a console.
        #[cfg(unix)]
        let source_bin = "/bin/sleep";
        #[cfg(windows)]
        let source_bin = "C:\\Windows\\System32\\ping.exe"; // Fallback for Windows

        if Path::new(source_bin).exists() {
            fs::copy(source_bin, &dummy_exe).expect("Failed to create dummy outlook.exe");

            // Make it executable on unix
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut perms = fs::metadata(&dummy_exe).unwrap().permissions();
                perms.set_mode(0o755);
                fs::set_permissions(&dummy_exe, perms).unwrap();
            }

            let mut cmd = Command::new(&dummy_exe);

            #[cfg(unix)]
            cmd.arg("10"); // sleep 10

            #[cfg(windows)]
            cmd.args(&["127.0.0.1", "-n", "10"]);

            let mut child = cmd.spawn().expect("Failed to spawn dummy outlook.exe");

            // Give the process manager a moment to register the process
            std::thread::sleep(Duration::from_millis(500));

            // System info needs to refresh and see the new process
            let is_running = is_outlook_running();

            // Cleanup
            let _ = child.kill();
            let _ = child.wait();

            assert!(is_running, "outlook.exe should be detected as running");
        } else {
            // If we can't find a dummy binary to copy, we skip the positive test,
            // but the test passes.
            println!("Skipping positive process test: source binary not found.");
        }

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
