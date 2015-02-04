# simple-issues-tracker
A very simple way to track ideas, todos, or bugs as files inside a Subversion or Git repository.

The idea of this simple script is that for small projects it can be 
too much overhad to set up a issue tracker and one would just like to 
keep the ideas, todos and bugs with the project repository.

The file issues.pl is a simple script that simplifies doing this and working 
with the following conventions:
* The root of the subversion or git repository contains a directory "issues"  which contains one file for each idea, todo or bug
* The file name for an issue contains the creation date, sequence number per date, issue type and user name: 20141221-1-idea-jsmith.issue 
* Closed issues are moved to the directory "issues/closed". All issues in the "isses"  directory are open. 
* Each issue file can contain arbitrary text, separated into arbitrary "fields" 
* A field has a name and a content 
* A field name must start at the beginning of a line, consist of just ascii letters, numbers and "_" and must start with a letter. It must be followed by a colon and a blank
* The content of a field can be arbitrary text that is not a field name 
* The following fields are known and should be used:
  * summary: a one line summary of the issue
  * priority: something of the form m/n where m >=0 and m<=n and n and m are integers, e.g. 2/10, meaning 2 of 10. This reflects the importance to deal with the issue.
  * severity: same format as priority. This reflects how big the problem is (usually only used for bugs, not ideas or todos)
  * due: a date in the format yyyymmdd or yyyy-mm-dd 
  * commets: detailed comments describing the issue. The comment field can be arbitrarily structured as long as it does not contain something that looks like a field name. #
  
This can all be followed manually, the script issues.pl simply tries to make some of the
most frequent actions easier and less error-prone.

# Installation

1. clone the git repository somewhere: `git clone https://github.com/johann-petrak/simple-issues-tracker.git`
2. Do one of the following things to make the script `issues.pl` accessible as a command:
  1. copy the file to a directory that is already in your PATH, optionally renaming to a command name that you like better
  2. OR add the directory you created by cloning to your PATH
  3. OR create a symbolic link to `issues.pl` in a directory that is already in your PATH, e.g. `cd <mybindir>; ln -s <dirwheregotclonewasdone>/simple-issues-tracker/issues.pl sit` will make the script accessible as the `sit` command 

# Usage

Run `issues.pl -h` to show usage information.
