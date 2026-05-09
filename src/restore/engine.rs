use std::path::Path;
#[cfg(not(test))]
use crate::engine::robocopy::run_robocopy;
#[cfg(test)]
use self::tests::mock_run_robocopy as run_robocopy;
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use crate::engine::robocopy::RobocopyResult;

    thread_local! {
        static MOCK_SUCCESS: RefCell<bool> = RefCell::new(true);
        static MOCK_EXIT_CODE: RefCell<i32> = RefCell::new(0);
        static MOCK_IO_ERROR: RefCell<Option<std::io::ErrorKind>> = RefCell::new(None);
    }

    pub(crate) fn mock_run_robocopy(
        _src: &Path,
        _dst: &Path,
        _log_file: &Path,
        _is_incremental: bool,
    ) -> Result<RobocopyResult, std::io::Error> {
        let err_kind = MOCK_IO_ERROR.with(|e| *e.borrow());
        if let Some(kind) = err_kind {
            return Err(std::io::Error::new(kind, "mock error"));
        }

        let success = MOCK_SUCCESS.with(|s| *s.borrow());
        let exit_code = MOCK_EXIT_CODE.with(|e| *e.borrow());

        Ok(RobocopyResult {
            exit_code,
            success,
            log_file: "mock_log.txt".to_string(),
        })
    }

    fn set_mock_success(success: bool, exit_code: i32) {
        MOCK_SUCCESS.with(|s| *s.borrow_mut() = success);
        MOCK_EXIT_CODE.with(|e| *e.borrow_mut() = exit_code);
        MOCK_IO_ERROR.with(|e| *e.borrow_mut() = None);
    }

    fn set_mock_error(kind: std::io::ErrorKind) {
        MOCK_IO_ERROR.with(|e| *e.borrow_mut() = Some(kind));
    }

    #[test]
    fn test_restore_files_success() {
        set_mock_success(true, 1);

        let source = Path::new("src_dir");
        let destination = Path::new("dst_dir");
        let result = restore_files(source, destination);

        assert!(result.is_ok());
    }

    #[test]
    fn test_restore_files_failure_exit_code() {
        set_mock_success(false, 8);

        let source = Path::new("src_dir");
        let destination = Path::new("dst_dir");
        let result = restore_files(source, destination);

        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Restore failed with exit code: 8");
    }

    #[test]
    fn test_restore_files_start_error() {
        set_mock_error(std::io::ErrorKind::NotFound);

        let source = Path::new("src_dir");
        let destination = Path::new("dst_dir");
        let result = restore_files(source, destination);

        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "Restore failed to start: mock error");
    }
}
