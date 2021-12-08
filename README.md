# git-conflict-monitor
A service which monitors a git repo to avoid conflict hell before it happens.

See https://softwareengineering.stackexchange.com/questions/412628/proactive-git-branch-conflict-detection

- Heuristically track "active work" over time
- Every possible pair of combinations of separate "active work branches" are attempted in a git merge
- If a conflict is detected, emails are sent to both relevant authors (open question: is it 
    possible to alert only the more recently contributing author?)

This service needs to be used with care because it is easy to generate unwanted spam. My thesis is 
that the service could provide more value than the annoyance that it may generate.
