use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::Path;

pub fn read_exclusions(config_path: &Path) -> Vec<String> {
    let mut exclusions = Vec::new();
    if let Ok(file) = File::open(config_path) {
        let reader = BufReader::new(file);
        for line in reader.lines() {
            if let Ok(line) = line {
                let trimmed = line.trim();
                if !trimmed.is_empty() && !trimmed.starts_with(';') && !trimmed.starts_with('#') {
                    exclusions.push(trimmed.to_string());
                }
            }
        }
    }
    exclusions
}
