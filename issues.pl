#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use File::Copy qw(move);
use Data::Dumper;

my ($version,$help,$verbose,$debug,$wikiformat,$ousername,$otype,
  $shorttemplate,$searchterms,$odue,$oshowc);
GetOptions('h' => \$help, 'v' => \$verbose,'d' => \$debug,'V' => \$version,
  'wf' => \$wikiformat,
  'u=s' => \$ousername,
  't=s' => \$otype,
  'short' => \$shorttemplate,
  's=s' => \$searchterms,
  'due=s' => \$odue,
  'showc' => \$oshowc
  ) or help_usage(1);

if($help) {
  help_usage(-1);
  help_subcommands();
  exit(0);
}
if($ousername) {
  die "Odd username $ousername\n" unless($ousername =~ /^[a-zA-Z][a-zA-Z0-9_]+$/);
}
if($otype) {
  die "Odd type $otype\n" unless($otype =~ /^bug|todo|idea$/);
}
  
my $workdir = get_workdir();
print "Working directory is $workdir\n" if($debug);

if($workdir eq "") {
  die "Not inside a git or svn working directory";
}
my $issuesdir = $workdir . "/issues";
unless (-d $issuesdir) {
  die "Issues directory $issuesdir does not exist";
}

$searchterms = "" unless($searchterms);

if($odue) {
  die "Not a valid date $odue, format must be yyyymmdd or yyyy-mm-dd" 
    unless ($odue =~ /^[12][0-9][0-9][0-9]-?[0-9][0-9]-?[0-9][0-9]$/);
  $odue =~ s/-//g;
}

## Get configuration 
my $editor = $ENV{"EDITOR"} || "vi";

## There should be at least one argument which must be the subcommand
help_usage(1) unless (@ARGV >= 1);
  

## now get all the issues and store the ids, numbers and descriptions
my %nr2id = ();
my %id2data = ();
opendir(DIR,$issuesdir);
my $n = 0;
my @files = readdir(DIR);
closedir(DIR);
foreach my $file (sort @files) {
  my ($date,$type,$user,$summary,$due,$assignedName,$priority,$severity,$serno);
  if($file =~ /^([12][0-9][0-9][0-9][0-9][0-9][0-9][0-9])-([0-9]+)-(todo|bug|idea)-([a-zA-Z0-9_]+)\.issue$/ ) {
    $date = $1;
    $serno = $2;
    $type = $3;
    $user = $4;
    $n++;
    ##print "Got issue $n: $date $type $user\n";
    my $id = "$date-$serno-$type-$user";
    $nr2id{$n} = $id;
    my $data = read_issue($issuesdir . "/" . $file);
    $data->{'!id!'} = $id;
    $id2data{$id} = $data;
  } else {
    next if ($file eq "." || $file eq ".." || $file eq "closed" || $file =~ /template/);
    print STDERR "WARNING: found odd file in directory $issuesdir: $file\n";
  }
}

## TODO: read in the closed issues (maybe just if we have an option already 
## that indicates we do want closed issues).

## check what the subcommand is
my $subcommand = shift;# $ARGV[0];

if($subcommand eq "ls") {
  my @searchterms = split(/ +/,$searchterms);
  ISSUE: for(my $i=1;$i<=$n;$i++) {
    my $data = $id2data{$nr2id{$i}};
    ##print STDERR "Data is ",Data::Dumper::Dumper($data),"\n";
    my $id = $data->{"!id!"};
    my ($idate,$serno,$itype,$iuser) = split(/-/,$id,4);
    if($otype) {
      next if($otype ne $itype);
    }
    if($ousername) {
      next if($ousername ne $iuser);
    }
    if(@searchterms) {
      my $text = $data->{'!text!'};
      foreach my $searchterm (@searchterms) {
        next ISSUE unless($text =~ /$searchterm/i);
      }
    }
    my $priority = $data->{"priority"} || '?/?';
    my $due = trim($data->{"due"}) || "2999-12-31";
    my $summary = $data->{"summary"} || "[field 'summary' is empty]";
    my $assigned = $data->{"assignedname"} || $data->{"assigned"} || '[unassigned]';
    ## if we limit by due date, then the issue only gets filtered out if
    ## the due date of the issue has the correct format and is after the
    ## due date specified as an option. If we do not recognize the format,
    ## we always list the issue.
    if($odue) {
      my $tdue = $due;
      if($tdue =~ /^[12][0-9][0-9][0-9]-?[0-9][0-9]-?[0-9][0-9]$/) {
        $tdue =~ s/-//g;
        ## print STDERR "Comparing $tdue and $odue yields ",($tdue cmp $odue),"\n";
        next unless (($tdue cmp $odue) <= 0 );
      } else {
        print STDERR "Warning: due date for $id has an odd format\n";
      }
    }
    if($wikiformat) {
      print "%3* $id $summary ($priority $due $assigned)\n";
      if($oshowc) {
        ## use block quote %" .. %" or verbatim %< .. %> ??
        print "\n",'%"',escapeForWiki($data->{'comments'}),'%"',"\n";  
      }
    } else {
      if($oshowc) { print "**** "; }
      print "$i/$id $summary ($priority $due $assigned)\n";
      if($oshowc) {
        print indentText($data->{'comments'},4),"\n\n";
      }
    }
  }
} elsif($subcommand eq "edit") {
  my $issuefile = get_issuefilepath();
  my $ret = system($editor,$issuefile);  
} elsif($subcommand eq "close") {
  my $closeddir = $issuesdir . "/closed";
  unless(-d $closeddir) {
    mkdir $closeddir or die "Could not create directory $closeddir: $!";
  }
  my $theid = get_issueId();
  my $issuefile = $issuesdir . "/" . $theid . ".issue";
  die "Issue file $issuefile not found" unless(-f $issuefile);
  my $closedfile = $closeddir . "/" . $theid . ".issue";
  move($issuefile,$closedfile) or die "Could not move $issuefile to $closedfile: $!";
} elsif($subcommand eq "rm") {
  my $issuefile = get_issuefilepath();
  ## TODO: this should get replaced by the git/svn style way of editing a tmp file
  print "Enter reason for removing the file or empty to abort:\n";
  my $reason = <STDIN>; # I moved chomp to a new line to make it more readable
  chomp $reason;
  if($reason) {
    unlink $issuefile or die "Could not delete file $issuefile: $!";
    print STDERR "Issue file $issuefile has been deleted\n";
  } else {
    print STDERR "Aborted, nothing deleted\n";
  }
} elsif($subcommand eq "add") {
  die "Option -t type must be specified for add\n" unless($otype);
  ## TODO: copy template file into issues directory
  my $thisuser = trim(`whoami`);
  my $today = trim(`date +%Y%m%d`);
  my $created = 0;
  for(my $i=1;$i<=99;$i++) {
    my $newid = "$today-$i-$otype-$thisuser";
    my $newfile = $issuesdir . "/" . $newid . ".issue";
    unless(-f $newfile) {
      ## TODO: actually create the file from the template(type) string
      ## (see bottom of file).
      ## Depending on the flag, use the long or short template
      my $content;
      if($shorttemplate) {
        $content = short_template($otype);
      } else  {
        $content = long_template($otype);
      }
      open(my $fh, '>', $newfile) or die "Could not open file '$newfile' $!";
      print $fh $content;
      close($fh);
      $created = 1;
      print STDERR "Created file $newfile\n";
      last;
    }
  }
  unless($created) {
    die "Something went wrong could not create the issue file";
  }
} else {
  die "Subcommand $subcommand not supported or not implemented yet";
}

sub indentText {
  my $text = shift;
  my $indent = shift;
  $indent = 4 unless($indent);
  my $spaces = " " x $indent;
  $text =~ s/\n/\n$spaces/g;
  $text = $spaces . $text;
  return $text;
}

sub escapeForWiki {
  my $text = shift;
  $text =~ s/\_/\\\_/g;
  $text =~ s/\*/\\\*/g;
  $text =~ s/\n/\%br\n/g;
  return $text;
}

## this consumes the next positional argument as an issueNumberOrId and
## returns the id
sub get_issueId {
  die "Need the number or id of the issue file" unless $ARGV[0];
  my $theid = $ARGV[0];
  if(trim("$theid") =~ /^[0-9]+$/) {
    $theid = $nr2id{$theid};
  }
  die "No issue $ARGV[0] found" unless($theid);
  return $theid;
}


## this consumes the next positional argument as an issueNumberOrId and
## returns the corresponding issue file path.
sub get_issuefilepath {
  my $theid = get_issueId();
  my $issuefile = $issuesdir . "/" . $theid . ".issue";
  die "Issue file $issuefile not found" unless(-f $issuefile);
return $issuefile;
}

sub help_usage {
  my $exitcode = shift;
  print STDERR "Usage: $0 [-h] subCommand [options]\n";
  exit $exitcode if($exitcode >= 0);
}

sub help_subcommands {
  print STDERR "Subcommands: add, edit, close, ls, rm\n";
  print STDERR "  ls [-wf] [-u user] [-t type]: show all open issues and the most important information about each\n";
  print STDERR "     [-wf]: use GATE CoW wiki output format\n";
  print STDERR "     [-u user] [-t type]: limit by username of type (bug, todo, idea)\n"; 
  print STDERR "     [-s 'searchterms']: limit to issues containing those search terms, case insensitive\n";
  print STDERR "     [-due yyyy-mm-dd]: limit to issues due until that date\n";
  print STDERR "     [-showc]: show the comments too (and use **** as an eyecatcher for the heading)\n";
  print STDERR "  add -t type: add a new issue of type todo, idea, bug\n";
  print STDERR "  edit numberOrId: edit the issue with that id or number\n";
  print STDERR "  rm numberOrId: remove the issue with that id or number\n";
  print STDERR "  help subcommand: show more detailed info about a subcommand\n";
}

## find the root of the current git or svn working directory, or return 
## the empty string if nothing could be found.
sub get_workdir {
  return git_root() || svn_root() || "";
}

## find the root of the current git working space, if any
sub git_root {
  my $wd = `git rev-parse --show-toplevel 2>/dev/null`;
  chomp $wd; 
  return $wd;
}

## find the root of the current svn working space, if any
sub svn_root {
  my $out = `svn info . 2>/dev/null` ;
  $out =~ /Working Copy Root Path: (.+)/;
  my $path = $1;
  return $path;
}

sub trim {
  my $str = shift;
  return "" unless $str;
  $str =~ s/^\s+|\s+$//g;
  return $str;
}

sub read_file {
  my $file = shift;
  local $/ = undef;
  open FILE, $file or die "ERROR: Could not open file $file: $!";
  my $s = <FILE>;
  close FILE;
  return $s;
}


sub read_issue {
  my $file = shift;
  my $text = read_file($file);
  my $fields = {};
  ## split the text by field names: a name at the beginning of the line, followed by a colon
  my @parts = split(/^(?=[a-zA-Z_-]+:\s+)/m,$text);
  ##print STDERR "INFO: splitting file $file\n";
  foreach my $field ( @parts ) {
    my ($fieldname,$fieldvalue) = split(/:\s+/,$field,2);
    $fieldname = lc(trim($fieldname));
    $fieldvalue = trim($fieldvalue);
    ## print STDERR "adding field >$fieldname< = $fieldvalue\n";
    $fields->{$fieldname} = $fieldvalue;    
  }
  $fields->{'!text!'} = $text;
  return $fields;
}


sub long_template {
  my $type = shift;
  return <<EOF;
summary: 
component: 
version: 
due: 
assignedName:
priority: 
severity:
comments:
EOF
}

sub short_template {
  my $type = shift;
  return <<EOF;
summary: 
component: 
version: 
due: 
assignedName:
priority: 
severity:
comments:
EOF
}

