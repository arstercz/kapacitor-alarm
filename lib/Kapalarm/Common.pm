package Kapalarm::Common;
# Common methods
# <arstercz@gmail.com>

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant DEBUG => $ENV{DEBUG} || 0;
use POSIX qw(strftime);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use Date::Parse;
use Digest::MD5 qw(md5_hex);

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(time_print second_convert utc_to_local msg_finger msg_md5 msg_quote);

sub new {
  my ($class, %args) = @_;

  my $self = {};
  return bless $self, $class;
}

sub time_print {
  my $msg  = shift;
  my $zone = shift; # such as 'UTC', 'Asia/Shanghai';

  local $ENV{TZ} = "$zone" if defined $zone;
  my $timestr = 
         strftime("%Y-%m-%dT%H:%M:%S", localtime(time));
  print "[$timestr] $msg\n"
}

sub second_convert {
  my $sec = shift || 0;
  my $res;
  while($sec >= 0) {
    if ($sec >= 24*60*60) {
      $res .= sprintf("%dd", int($sec/(24*60*60)));
      $sec = $sec % (24*60*60);
    }   
    elsif ($sec >= 60*60) {
      $res .= sprintf("%dh", int($sec/(60*60)));
      $sec = $sec % (60*60);
    }   
    elsif ($sec >= 60) {
      $res .= sprintf("%dm", int($sec/60));
      $sec = $sec % 60; 
    }   
    else {
      $res .= sprintf("%ds", $sec);
      $sec = -1;
    }   
  }
  return $res;
}

sub utc_to_local {
  my $time = shift;
  
  # default is now
  my $unixtime = str2time($time, "UTC") || time();
  return strftime("%Y-%m-%dT%H:%M:%S", localtime($unixtime));
}

sub msg_finger {
  my $msg = shift;
  # 'WARNING: dc/hostname/memory - used_pct: 70.26%, used: 88.00GB, buffer/cached: 26.00GB, total:125.00GB'
  $msg =~ s/:\s*\d+(?:.\d+){0,1}/: xxx/g;
  return "$msg";
}

sub msg_md5 {
  my $msg = shift;
  return md5_hex($msg);
}

sub msg_quote {
  my $msg = shift;
  $msg =~ s/`/``/g;
  $msg =~ s/^"|"$//g;
  $msg =~ s/""/"/g;
  return "$msg";
}

1;
