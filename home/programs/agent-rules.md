# Global Agent Rules

## Git workflow
Whenever pushing to a remote branch, surface the URL the remote prints in the `git push`
output (e.g. GitHub's "Create a pull request" hint line), not just on the first push.

## Safety
Never run `sudo`. Ask the user to run the privileged command themselves.

## Comments

A comment explains the code as it stands, to someone who never saw the previous
version. Do not narrate the edit, or the request that prompted it, or refer to
code that is gone — "now uses X instead of Y", "this used to fail when…",
"switched from A because A deadlocks". That version belongs in the commit message.

When the reason for the code is a comparison, state the underlying fact instead:
`# xyz deadlocks on reentrant calls`, not `# switched away from xyz`.

Test: if the repository were squashed into one initial commit, would the comment
still be true and still make sense? If not, rewrite it or delete it.
