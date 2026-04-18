# AGENTS.md — AI Agent Governance for just-backup

> **SYSTEM DIRECTIVE**: This file is auto-loaded into your `<project_context>`.
> It dictates the absolute rules and routing protocols for any AI agent operating on this repository.

---

## Layer 0 — Identity & Context (WHO you are serving)

This repository (`just-backup`) is a **Windows CMD/Batch legacy tool** currently undergoing modernization.
- **Goal**: Maintain 100% portability without relying on external installations (no heavy runtimes).
- **Environment**: Strict Windows Execution Policies and enterprise environments.
- **Your Role**: You are an AI Agent (Antigravity, Jules, or Claude) assisting a Tech Lead. You must prioritize robustness and defensive programming in CMD over aesthetics.

---

## Layer 1 — Instinct (WHAT you must never violate)

These directives are hardcoded into your behavior. Violating ANY of them triggers immediate failure.

### I1: Language Strictness
All documentation, GitHub Issues, Pull Request descriptions, and inline code comments **MUST be in 100% English**. No exceptions.

### I2: UAC Elevation Integrity
[LAZY LOAD: `.agents/knowledge/ki_uac_elevation.md`]

### I3: CMD Parser Safety
[LAZY LOAD: `.agents/knowledge/ki_cmd_parser_traps.md`]

---

## Layer 2 — Routing & Protocols (HOW to act)

### 2.1 Triggering Jules Adversarial Reviews
[LAZY LOAD: `.agents/knowledge/ki_jules_api_workflow.md`]

**API Key Rotation Strategy**:
To optimize resource usage across accounts, we follow a project-based rotation:
- **Jules Ultra**: Reserved for Core Engine logic, Security Audits, and complex architectural refactors (e.g., `just-backup`).
- **Jules Pro**: Prioritized for UI components, standard business logic, and boilerplate generation (e.g., `web-login-solo`).

### 2.2 Releasing Portable Builds
Before merging to `master` and updating `dist/RoboSync_Portable.bat`:
1. Run the `test_harness.ps1` script to verify 55/55 test steps.
2. Manually ensure that all UI/Modular changes are correctly synchronized from the `src/` modular folders into the single monolithic Portable file.

---

## Layer 3 — Knowledge Schema Contract (File Type Consistency)

To prevent Context Rot and data inconsistency, all Agents contributing to the `.agents/knowledge/` Project Base MUST adhere to this strict schema contract when selecting file types:

### 3.1 Markdown (`.md`)
- **Context:** Standard operating procedures, rich explanations, workflows, or complex design patterns.
- **Detail Level:** Fully Detailed (Verbose).
- **Mandatory Schema:** Must include sections for `# Context & Problem`, `## Solution`, and `## Verification Checklist`.

### 3.2 JSON Lines (`.jsonl`)
- **Context:** Ledgers, independent events, historical logs (e.g., list of newly discovered parser bugs or sequential decisions).
- **Detail Level:** Extremely Concise. Optimized for scanning massive lists of records without consuming excessive tokens.

### 3.3 JSON (`.json`)
- **Context:** Static configurations, deterministic payload templates, strict machine-readable hierarchies.
- **Detail Level:** Structurally Strict. Use when the data must be parsed programmatically without ambiguity.

### 3.4 CSV (`.csv`)
- **Context:** Large 1-to-1 mapping tables or matrices (e.g., Error Code to Solution matrices).
- **Detail Level:** Tabular. Maximum token efficiency for categorical data.
