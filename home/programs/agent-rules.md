# Global Agent Rules

## Git workflow
Whenever pushing to a remote branch, surface the URL the remote prints in the `git push`
output (e.g. GitHub's "Create a pull request" hint line), not just on the first push.

## Safety
Never run `sudo`. Ask the user to run the privileged command themselves.
