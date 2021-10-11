# How to edit these scripts

**Before You Begin**, ensure you are following the
 [Automation Request Process](https://confluence.il2management.local/display/CP/Request+for+Automation+Process)

You will also need "Git Bash" installed (these instructions assume you are
using Windows)

## Create a branch
 - if you are working on a JIRA ticket, "create branch" within the Jira ticket
 - otherwise, click "create branch" in the Bitbucket repo view
 
## Download the new branch to your laptop

`git fetch`   will pull down the new branch name and list it for you.

`git checkout <branch-name>`   switches you to that branch. Ensure use do **not** have the word "origin/" on the beginning of the branch name

For example, to switch to a newly-created branch called **add-more-magic**
```
$ git fetch
remote: Counting objects: 108, done.
remote: Compressing objects: 100% (102/102), done.
remote: Total 107 (delta 5), reused 98 (delta 2)
Receiving objects: 100% (107/107), 57.28 KiB | 0 bytes/s, done.
Resolving deltas: 100% (5/5), done.
From ssh://git/cse/cse_read_only
   22b2aa7..2d6aa8a  master                    -> origin/master
 * [new branch]      add-more-magic            -> origin/add-more-magic
 * [new branch]      feature/Dudley's-Stuff    -> origin/feature/Dudley's-Stuff

$ git checkout add-more-magic
Branch add-more-magic set up to track remote branch add-more-magic from origin.
Switched to a new branch 'add-more-magic'
```

You can now make the relevant modifications

# Editing the code

Remember the rules (and seek help if you don't understand):
 - develop against a *development* environment (not against Production)
 - test it (against a *test* environment)
 - never store credentials in the source code
 - write it so that it will make sense when you come back to it after a year.
 - Follow the conventions (which are there to make everyone's life easier)
 - Commit often (you're working in a branch, so you're not treading on
   anyone's toes) `git add <filename(s)>` followed by `git commit`
 - Push your commits regularly `git push`
 
# Run the tests
 
# Initiate a code review
  - Click "Create pull request" on the left in the Bitbucket UI
  - select your branch, merge to "master"
  - Continue
  - Add a description of your change and choose reviewers
  - Create
  
The purpose of a Code review is to share the changes among the team and
to ensure the code meets the requirements, coding standards etc.

Reviewers can comment and make suggestions.

Alter the code as necessary following the review comments

Once the reviewers are happy with the code, they can "Approve" it with a click
of the "Approve" button.

# Merge the code back to master
Once approved, the code can be merged. Click the "Merge" button on the UI.
On the following page, tick "delete source branch" before clicking "Merge".

# Deploying
The code is deployed by copying it to an agreed location on the F: drive.
This allows it to be made available on all jump boxes by mounting the F: drive
when connecting to the Remote Desktop.

To deploy to the F: drive:
- open a "Git Bash" window and navigate to where you have this code checked
  out
- `git checkout master`
- `git pull`
- `git checkout-index -a -f --prefix "/F/Technical Unrestricted/Support/Tactical Automation/cse_read_only/"`
- **Note** the trailing slash is vital! 
- **Note** this will only copy checked in files
