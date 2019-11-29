package Kapalarm::Rule;
# set alarm rule based on Redis
use strict;
use warnings;
use English qw(-no_match_vars);
use Redis;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require Exporter;
@ISA = qw(Exporter);
@EXPORT    = qw( is_send is_white);
$VERSION = '0.1.0';

# use log2 algorithm to determin wheter send email or not, use step method
# list tcp retransmision ways:
# recvcnt: 1 2 3 4 5 6 7 8 9 ....
# sendcnt: 1 1 1 2 2 2 2 3 3.....
# is_send: Y N N Y N N N Y N ....
sub is_send {
  my $bound   = shift || 15;
  my %args    = @_;

  # send email when level change to OK from WARNING
  if ($args{level} eq 'OK' && $args{recvcnt} > 1 &&
       ($args{plevel} eq 'WARNING' || $args{plevel} eq 'CRITICAL')) {
    return 1;
  }

  my $rcnt = $args{recvcnt};
  my $scnt = $args{sendcnt};

  my $status = 0;
  # rcnt should be greater than 0;
  $status = 1 if $rcnt == 1;

  my $n = int(_log2($rcnt));
  # only greater than sendcnt by one
  if (($n - 1) >= $scnt) {
    # ignore when send many times email
    $status = 0 if $scnt > $bound;
    $status = 1;
  }
  
  return $status;
}

# get the log2 value
sub _log2 {
  my $n = shift;
  return log($n)/log(2);
}

sub is_white {
  my $r    = shift;
  my %args = @_;

  my $dc     = $args{dc};
  my $host   = $args{host};
  my $metric = $args{metric};

  unless ($r->is_white_dc_exist($dc)) {
    return 0;
  }

  my $bdc     = $r->white_get_dc($dc) || 0;

  my $hmeta   = $r->white_get_host_all($dc, $host);
  if (!defined($hmeta->{is_white}) 
          && !defined($hmeta->{$metric})) {
    return 0;
  }

  my $bhost   = $hmeta->{is_white} || 0;
  my $bmetric = $hmeta->{$metric} || 0;

  return _decide_bit($bdc, $bhost, $bmetric);
}

# determin whether the item is in white list
# dc:     0b100
# host:   0b010
# metric: 0b001
sub _decide_bit {
  my $bdc     = shift;
  my $bhost   = shift;
  my $bmetric = shift;

  my $bitset  = 0b . $bdc . $bhost . $bmetric;

  if ($bitset & 0b111) {
    return 1;
  }
  return 0;
}

1;
