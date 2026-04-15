use std::path::Path;
use crate::engine::robocopy::run_robocopy;
use tracing::{info, error};

pub fn restore_files(source: &Path, destination: &Path) -> Result<(), String> {
    info!("Starting restore from {:?} to {:?}", source, destination);

    let log_file = destination.join("restore_log.txt");

    // For restore, it's essentially a copy back.
    // We treat it as an incremental copy so we don't overwrite identical files unnecessarily,
    // but the conflict resolution logic should be handled according to user preferences.
    // For simplicity, we use the standard robocopy backup logic.
    match run_robocopy(source, destination, &log_file, false) {
        Ok(result) => {
            if result.success {
                info!("Restore succeeded.");
                Ok(())
            } else {
                let msg = format!("Restore failed with exit code: {}", result.exit_code);
                error!("{}", msg);
                Err(msg)
            }
        }
        Err(e) => {
            let msg = format!("Restore failed to start: {}", e);
            error!("{}", msg);
            Err(msg)
        }
    }
}
