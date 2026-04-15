use std::process::{Command, ExitStatus};
use std::path::Path;

#[derive(Debug, Clone)]
pub struct RobocopyResult {
    pub exit_code: i32,
    pub success: bool,
    pub log_file: String,
}

pub fn run_robocopy(
    src: &Path,
    dst: &Path,
    log_file: &Path,
    is_incremental: bool,
) -> Result<RobocopyResult, std::io::Error> {
    let mut cmd = Command::new("robocopy");

    // Convert paths to string safely, assuming they might have Unicode
    // The Command::arg on Windows properly handles Unicode strings.
    cmd.arg(src)
       .arg(dst)
       .arg("/E")            // Copy subdirectories, including empty ones
       .arg("/COPY:DAT")     // Copy Data, Attributes, Timestamps
       .arg("/DCOPY:DAT")    // Copy Directory Data, Attributes, Timestamps
       .arg("/R:3")          // 3 retries on failed copies
       .arg("/W:5")          // Wait 5 seconds between retries
       .arg("/MT:8")         // Multithreading with 8 threads
       .arg("/XJ")           // Exclude junction points
       .arg("/FFT")          // Assume FAT file times (2-second granularity)
       .arg("/TEE")          // Output to console window, as well as log file
       .arg(format!("/LOG:{}", log_file.display()));

    // Exclude system files and common temporary folders/files
    cmd.arg("/XD")
       .arg("System Volume Information")
       .arg("$Recycle.Bin")
       .arg("Windows\\Temp");

    cmd.arg("/XF")
       .arg("pagefile.sys")
       .arg("hiberfil.sys")
       .arg("swapfile.sys");

    // Do NOT use /MIR by default. Only standard copy which skips identical files naturally.
    // If it is an incremental backup, Robocopy handles it perfectly by default because it skips files that haven't changed (based on size/timestamp).

    let status = cmd.status()?;
    let exit_code = status.code().unwrap_or(8); // If killed or no code, assume failure (8+)

    // Exit code 0-7 is success for robocopy
    let success = exit_code <= 7;

    Ok(RobocopyResult {
        exit_code,
        success,
        log_file: log_file.to_string_lossy().into_owned(),
    })
}
