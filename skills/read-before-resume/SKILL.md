---
name: read-before-resume
description: Re-read the authoritative workflow documents before acting, at session start or after a context break, instead of working from memory of them. Use when an agent keeps acting on stale versions of documents it read earlier, or resumes work in the wrong place.
license: MIT
---

# Read Before Resume

The user invoked this skill at the start of a session, after a long break, or after catching the agent acting on outdated information. Your job is to rebuild your picture of the project from the documents as they are now, and only then act.

The failure this remedies: working from a mental copy. An agent that read a guideline yesterday answers from its memory of the guideline today, and the memory is a summary that has silently dropped the qualifications and missed every edit since. The workflow's documents state repeatedly that they are authoritative and that they change; this skill is the enforcement.

## Procedure

1. **Find the workflow root**: walk up from the working directory to the folder holding `guidelines/` and `workspace/`.
2. **Read, in order, as they are on disk now:**
   - `AGENTS.md`, the entry point.
   - `workspace/documentation/project-status.md`, the authoritative ledger.
   - `workspace/documentation/project-state.md`, the resume snapshot, remembering it is subordinate to the ledger where they disagree.
   - The stage document in `stages/` for whatever stage the ledger says is current.
3. **Verify the recorded next action against reality** before performing it. The ledger's "next action" was true when written. Check that the issue it names still exists and is still open, that the commit state matches (count it, do not trust it), and that nothing marked outstanding has quietly been done. If the records themselves are stale, fixing them comes first - that is its own job, and the `records-sync` skill covers it.
4. **Re-read the specific guideline before performing its procedure**, even if it was read earlier in the session. Validation cards come from `guidelines/manual-validation.md` as it reads today, not as remembered. The same for coding standards before implementing and for the evidence rules before recording anything.
5. Only then act.

## Rules

- Quoting a document from memory is not reading it. If a decision hangs on what a document says, open it at decision time.
- A summary produced by an earlier session, including your own, is context, not authority. It compresses; the compression is where the qualifications died.
- When a document contradicts the memory of it, the document wins without discussion, and the difference is worth a sentence to the user, because it may mean the document changed since the plan was made.

## Boundaries

- This skill orders reading; it does not replace any of it. The documents themselves say what to do next.
- It is the weakest remedy in this directory, and deliberately so: a skill can put the documents in front of an agent, but an agent that will not read cannot be fixed by one more document. If invoking this repeatedly changes nothing, the remedy is a more capable agent, not a longer skill.
