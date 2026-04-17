# Jules Cloud API Execution Workflow

## Context & Problem
When running the Jules AI CLI (`npx @google/jules`) natively on a Windows machine, Windows Defender frequently flags the downloaded `jules.exe` binary in the `%TEMP%` directory as untrusted and quarantines it immediately. This results in an `ENOENT` spawn error.

Additionally, running the CLI without arguments in a Headless CI environment (like GitHub Actions) will crash or hang indefinitely because it attempts to launch an interactive TUI (Terminal UI).

## The Standardized Solution (Knowledge)
To securely trigger a Jules session on Windows without tripping Defender, you MUST bypass the CLI binary entirely and interact directly with the Jules REST API using PowerShell's `Invoke-RestMethod`.

### API Workflow Pattern
1. Extract the `JULES_API_KEY` from the `.env` file.
2. Formulate a POST request to `https://jules.googleapis.com/v1alpha/sessions`.

```powershell
$apiKey = "YOUR_API_KEY"
$headers = @{
    "Content-Type" = "application/json"
    "x-goog-api-key" = $apiKey
}

$body = @{
    prompt = "Please review Pull Request #X. Focus on Y."
    sourceContext = @{
        source = "sources/github/tamld/just-backup"
        githubRepoContext = @{
            startingBranch = "feat/my-branch"
        }
    }
    title = "Review Task"
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://jules.googleapis.com/v1alpha/sessions" -Method Post -Headers $headers -Body $body
```

## Verification Checklist
1. Never suggest using `npx @google/jules` on a Windows host.
2. Verify that the `$body` JSON contains the correct `source` matching the repository and the correct `startingBranch`.
3. If running via CI, ensure `jules new "Prompt"` is used instead of just `jules` to avoid TUI hangs.
