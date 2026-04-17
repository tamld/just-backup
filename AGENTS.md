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

### 2.2 Releasing Portable Builds
Before merging to `master` and updating `dist/RoboSync_Portable.bat`:
1. Run the `test_harness.ps1` script to verify 55/55 test steps.
2. Manually ensure that all UI/Modular changes are correctly synchronized from the `src/` modular folders into the single monolithic Portable file.
