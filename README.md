# trello_backup.rb

Inspired by [mattab/trello-backup](https://github.com/mattab/trello-backup),
I hacked together a simple Ruby-based backup solution for Trello.

It focuses on a complete backup including all comments and attachments and
is intended to run as a dialy cronjob on combination with a backup tool like
[Borg](https://borgbackup.readthedocs.io/en/stable/).
