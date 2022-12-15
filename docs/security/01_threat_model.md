# Threat model

## Targets

Delta has two main functions:

* Collecting data from local authorities (LAs) and other organisations through forms
* Managing grant payments to local authorities from DLUHC

Primary targets:

* The grant payments are significant sums of money, and while Delta does not make the payments itself an attacker may be able to redirect funds
* Delta stores PII of its users and forms can collect PII of other persons

## Adversaries

Adversaries assumed to be capable and persistent, for example, a low to moderate priority target of nation state level actors.

## Assumed knowledge

This repository is assumed to be public, including CI/CD output.
We assume an attacker could have significant knowledge of the ecosystem and department, up to and including access to the source code from the other, private, repositories.

## Exclusions

The following are not in scope of our threat model:

* Compromise of AWS services or network
* Targeted use of zero-day exploits in supported software we use
* Direct action against individuals

As this repository is public, the security posture of the following will not be discussed in detail:

* Detailed discussion of the applications themselves
* DLUHC or supplier's organisation or corporate network
* AWS organisation
* GitHub organisation
* Security posture of the previous environment
* Systems Delta interacts with (EClaims, SAP)

These will instead be documented on DLUHC Confluence where relevant.
