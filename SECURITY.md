# Security reporting

Please do not include credentials, personal data or exploit details in a public issue. Use the repository's
**Security → Report a vulnerability** flow to contact the maintainer privately.

Only the current main branch is maintained. A report should include the affected version or commit, the impact and
reproduction steps. The plugin reads a loopback URL and runs the pinned Theoria CLI through `node`, plus `curl`
and `omarchy-launch-webapp` from fixed system paths; it stores nothing and sends nothing off the machine.
