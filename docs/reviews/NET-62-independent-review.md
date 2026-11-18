# NET-62 independent code review

Codex reviewed the Kubernetes workload check at `ddb68d9` on 18 November 2026. The review focused on repository inventory, local rendering, the scope of cluster consent, and the tests and instructions for those paths.

## High · A context switch could send queries to another cluster

The cluster pass looked up the current context after consent and used it for every namespace query. The agent compared the context with the offer only after the script returned. Namespace mode now requires the approved context and compares it with the local current context before making a network request. The stand-in test checks that a mismatch logs only the local context lookup and prints no table.

## High · A partial directory walk could look complete

List mode piped each directory walk into a successful text filter, masking traversal errors. A readable manifest next to an inaccessible directory could therefore appear to be the entire inventory. The reader now checks each walk before processing its output. A test supplies a failing walker that prints one candidate first and verifies exit 4 with no inventory. The render preflight also stops when its search for links fails.

## High · The reader failed to start under macOS sh

Apple's system shell rejected a case pattern inside the Helm dependency command substitution. The parse error prevented every reader mode from starting, including inventory and help. A paired opening parenthesis makes the pattern unambiguous to that shell. Verified with the system shell's syntax check and a listing of the fleetboard fixture on macOS.

Cluster behaviour was exercised with the bundled stand-in. No live cluster was queried.
