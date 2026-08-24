# Test Documentation Standard

This rule applies whenever you are asked to run tests in a folder and document the results. You must follow this procedure rigorously.

## BEFORE RUNNING — Version reconciliation (do this first, not after):
1. List every test/benchmark script in the target folder, along with its last-modified date and (if available) git log for that file.
2. Check for scripts that test the same claim under different filenames or versions (e.g., "evaluate_lcm_storage.sql" vs "evaluate_lcm_storage_rigorous.sql" vs "evaluate_lcm_storage_realistic.sql"). If more than one script tests the same underlying claim, treat the most recently modified / most methodologically corrected one as canonical, and flag the others as superseded rather than running and reporting them as if current.
3. Cross-reference against known truth documents before writing anything. If a script's expected output conflicts with a number already published in one of those documents, do not silently report the new number as fact — stop and flag the conflict for human review before finalizing the document.
4. If you cannot determine whether a script is current or superseded (e.g., no git history available, ambiguous naming), say so explicitly in the output rather than guessing or silently picking one.

## WHILE RUNNING:
5. Report methodology and results factually — describe what was tested and what was measured. Do not add interpretive or promotional language (e.g., "validates the architecture," "proves the premise"). State the measured number and let it speak for itself.
6. For every quantitative claim, state explicitly whether it was DIRECTLY MEASURED (from a live run) or MODELED/ASSUMED (from a formula applied to sampled inputs, e.g., a materialization-rate sensitivity table). Never let a modeled number appear without that label attached, including in section headers and summary lines, not just a footnote.
7. If a script fails, errors, or produces an unexpected result, report that directly — do not omit failed runs or retry silently until one succeeds without noting the earlier failures. A defect found during testing is a result, not noise to be cleaned up before reporting.

## AFTER RUNNING:
8. Add a short "Version & Supersession Note" section at the top of the output listing: which scripts were run, which (if any) known-older scripts in the same folder were deliberately skipped and why, and which prior documents (if any) this output supersedes or conflicts with. Use the exact markdown template provided below.
9. Do not delete or silently overwrite prior test-result documents. Prior versions stay in place for audit purposes; new documents reference and supersede them explicitly by name.
10. End with a short, explicit list of what this test run does NOT establish (scope limits, untested conditions, assumptions baked into the setup) — do not let a passing test suite imply broader coverage than what was tested.

### Standard Template: Version & Supersession Note
Must be placed at the top of all test output documents.

```markdown
## Version & Supersession Note

**Document:** [name/code, e.g., AGEI-BENCH-012-revision2]
**Date generated:** [date]
**Scripts executed this run:**
- [script name] — [path] — last modified [date/commit]
- [script name] — [path] — last modified [date/commit]

**Known older/sibling scripts NOT run, and why:**
- [script name] — superseded by [current script] because [one-line reason, e.g., "used degenerate synthetic payload causing TOAST compression artifact"]
- (none, if not applicable)

**Relationship to prior documents:**
- [ ] This document supersedes: [doc name/section] — reason: [...]
- [ ] This document is superseded by: [doc name/section]
- [ ] This document is standalone / does not conflict with prior documents
- [ ] UNRESOLVED CONFLICT — flagged for human review, not yet reconciled: [describe the conflicting claim and both source numbers]

**Claims in this document, by evidentiary status:**
| Claim | Status (MEASURED / MODELED) | Source |
|---|---|---|
| [claim] | [ ] | [script/section] |

**Scope boundary:** This document does not establish: [one-line list, or "see Section X / Not Established"]
```
