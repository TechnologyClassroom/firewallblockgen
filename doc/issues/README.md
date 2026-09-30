# Issues

When I have a brief moment to work on one of my personal repositories,
sometimes I am just on the command line and I do not have all of my passwords,
API keys, and credentials. GitHub is now often behind authentication likely due
to the same abuse from big tech that I am seeing so I might not have the notes
from my Issue Tracker handy.

This directory is a backup of my issue tracker and comments. This may not be
the most accurate, up-to-date copy.

## How was this created?

[mattduck/gh2md](https://github.com/mattduck/gh2md) works for this as of
2026-09-30.

### Installing gh2md

On a Debian system, you can install `pipx` with these commands:

    sudo apt update
    sudo apt install pipx

Install `gh2md` with pipx using this command:

    pipx install gh2md

### Creating a GitHub access token

* [Login](https://github.com/login) to [GitHub](https://github.com/).
* Click on your profile icon in the top-right and select the
  [Settings](https://github.com/settings/profile) option.
* Click on the [Credentials](https://github.com/settings/credentials) option.
* Click on the [Fine-grained personal access tokens](https://github.com/settings/personal-access-tokens) option.
* Click on the [Generate new token](https://github.com/settings/personal-access-tokens/new) button and enter your password again.
* Fill in the text box for `Token name`.
* Set an Expiration with the drop-down choices.
* Click on the `Add permissions` button and select the `Issue Fields` option.
* Click on the `Add permissions` button and select the `Issue Types` option.
* Click on the `Generate token` button.
* Copy the token to your password manager.
* Add the token to the `~/.config/gh2md/token` file.

### Pulling issues

You can pull all open issues for repositories with these commands:

    gh2md technologyclassroom/firewallblockgen firewallblockgen/doc/issues --multiple-files --no-prs --no-closed-issues
    gh2md technologyclassroom/logreview logreview/doc/issues --multiple-files --no-prs --no-closed-issues
    gh2md technologyclassroom/webserverwatcher webserverwatcher/doc/issues --multiple-files --no-prs --no-closed-issues

You can add them to git from this point.
