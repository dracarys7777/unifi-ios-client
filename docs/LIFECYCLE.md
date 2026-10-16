# Prompt to maintained product

## State machine

request -> triage -> accepted -> implementation -> review -> verified -> beta -> accepted-on-device -> release -> observed

A feature issue records outcome, acceptance criteria, constraints, related work and an owner decision when requirements conflict. Coding-agent assignment is a separate integration step; committing instructions does not activate an agent.

## Responsibilities

- Product/triage: de-duplicate requests and compare them with PRODUCT.md and open PRs.
- Developer: one scoped branch per issue, regression coverage and a reviewable PR.
- Reviewer: separate review pass, acceptance criteria, auth, storage, concurrency, API compatibility and accessibility.
- Conflict resolution: rerun checks against the actual combined revision after resolving textual conflicts; ask owner about conflicting product requirements.
- Maintenance: weekly upstream change detection, Dependabot for GitHub Actions, and scoped compatibility issues. SDK versions in project.yml are not managed by Dependabot.
- Release: signed builds only in a trusted release job; TestFlight first; public release requires owner acceptance.

## Automation actually included

GitHub CI runs Python tests and macOS simulator tests on PRs and main pushes. Upstream watch runs Mondays at 03:17 UTC (08:47 IST) after the workflow reaches the default branch, and can run manually. It compares SDK/tool release metadata and visible documentation text, reports changes in one tracking issue and fails visibly on source-fetch errors. This is a change detector, not a semantic assessment or self-repair agent. Upstream content is never executed or passed as instructions.

Dependabot checks GitHub Actions weekly. The monitor tracks Firebase releases separately because the app dependency is in XcodeGen YAML.

## Required service setup

Enable your chosen coding-agent integration for this repository and its independent review capability. Confirm plan/billing in that service. Assign accepted issues explicitly until successful operation is demonstrated. Provider-specific role prompts must follow AGENTS.md. Do not supply Apple signing or production credentials to coding jobs.

Configure branch rules after CI has run: require `validate` and `ios`, require a PR, dismiss stale approvals and prevent force pushes. Require owner review for workflow, signing, auth, billing, data migration and agent-policy changes. No automatic merge or public release is configured here.

## Operational controls still to implement

Crash/error telemetry with privacy filtering; bounded synthetic API probes; model lifecycle catalogue; remote feature flags; incident response; restore testing; dependency lockfile capture from first successful Mac build; pinned Xcode/XcodeGen versions from that validated build. The current macOS runner and Homebrew XcodeGen can drift and must be recorded in build logs.

Maximum two automated repair attempts per failure; one active maintenance fix per subsystem; no unbounded agent loops. Choose explicit monthly AI/build/API budgets before scheduling model-powered work. Cloud budget alerts are not guaranteed hard spending caps.

Recovery: disable a failing server/configured feature when supported; revert source and distribute a corrected native build. Source rollback does not replace already installed binaries.
