package Kapalarm::Redis;
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
@EXPORT    = qw( common_set common_get white_set_dc );
$VERSION = '0.1.0';

sub handle {
  my $self = shift;
  my %args = @_;

  delete $args{prefix};
  delete $args{log};
  $self->{handle} = Redis->new(%args);
  return $self->{handle};
}

sub new {
  my ($class, %args) = @_;

  if ($args{sentinels}) {
    $args{sentinels_cnx_timeout}   ||= 1;
    $args{sentinels_read_timeout}  ||= 1;
    $args{sentinels_write_timeout} ||= 1;
  } else {
    $args{reconnect}     ||= 2;
    $args{every}         ||= 100_000;
    $args{cnx_timeout}   ||= 1;
    $args{read_timeout}  ||= 1;
    $args{write_timeout} ||= 1;
  }

  # prefix should be set
  $args{prefix} ||= 'kapalarm';
  my $self = {};
  bless $self, $class;

  $self->{prefix} = $args{prefix};
  $self->{log}    = $args{log};
  $self->handle(%args);

  return $self;
}

sub is_key_exist {
  my $self = shift;
  my $key  = shift;

  # check wheter filed exists
  my $dc = $self->field_get($key, "dc");
  if (defined $dc) {
    return 1;
  }
  return 0;
}

sub common_set {
  my $self   = shift;
  my %args   = @_;

  my @require_args = qw(dc host metric id level plevel
                        sample finger duration );
  foreach my $arg (@require_args) {
    warn "I need a $arg argument" unless $args{$arg};
  }

  my $dc       = $args{dc};
  my $host     = $args{host};
  my $metric   = $args{metric};
  $args{recvcnt} ||= 1;
  $args{sendcnt} ||= 0;

  my $prefix = $self->{prefix};
  my $key = "$prefix-$dc-$host-$metric";

  # set basic message and sadd mysql repl members
  eval {
    $self->{handle}->hmset($key, %args);
  };
  if ($@) {
    $self->{log}->error("common_set error: $@");
    return 0;
  }

  if ($self->meta_set($dc, $host)) {
    $self->{log}->info("$key meta set ok");
  }

  return 1;
}

sub meta_get {
  my $self   = shift;

  my $prefix = $self->{prefix};
  my $key = "$prefix-meta";
  my $dcs;
  eval {
    $dcs = $self->{handle}->smembers($key);
  };
  if ($@) {
    $self->{log}->error("get $key error: $@");
    return undef;
  }
  return $dcs;
}

# host unit
sub meta_set {
  my $self   = shift;
  my $dc     = shift;
  my $host   = shift;

  my $prefix = $self->{prefix};
  my $meta         = "$prefix-meta";
  my $meta_dc      = "$prefix-meta-$dc";

  eval {
    $self->{handle}->sadd($meta, $dc);
    $self->{handle}->sadd($meta_dc, $host);
  };
  if ($@) {
    $self->{log}->error("add meta error: $@");
    return 0;
  }
  return 1;
}

sub meta_dc_get {
  my $self   = shift;
  my $prefix = $self->{prefix};

  my $key    = "$prefix-meta";

  my $dcs;
  eval {
    $dcs = $self->{handle}->smembers($key);
  };
  if ($@) {
    $self->{log}->error("get $key error: $@");
  }
  return $dcs;
}

sub meta_host_get {
  my $self   = shift;
  my $dc     = shift;

  my $prefix = $self->{prefix};
  my $key = "$prefix-meta-$dc";
  my @hosts;
  eval {
    @hosts = $self->{handle}->smembers($key);
  };
  if ($@) {
    $self->{log}->error("get $key error: $@");
    return undef;
  }
  return \@hosts;
}

# get dc white status, return string value
sub white_get_dc {
  my $self   = shift;
  my $dc     = shift;

  my $prefix   = $self->{prefix};
  my $is_white = shift || 0;
  my $key      = "$prefix-white-$dc";
  my $field    = "white";
  my $list;
  
  eval {
    $list = $self->{handle}->hget($key, $field);
  };
  if ($@) {
    $self->{log}->error("get white $key  error: $@");
    return undef;
  }

  return $list;
}

# get all host and metric white status, return hash ref
sub white_get_host_all {
  my $self   = shift;
  my $dc     = shift;
  my $host   = shift;

  my $prefix   = $self->{prefix};
  my $is_white = shift || 0;
  my $key      = "$prefix-white-$dc-$host";
  my %list;
  eval {
    %list = $self->{handle}->hgetall($key);
  };
  if ($@) {
    $self->{log}->error("get white $key  error: $@");
    return undef;
  }

  return \%list;
}

sub is_white_dc_exist {
  my $self     = shift;
  my $dc       = shift;
  my $is_white = shift || 0;

  my $prefix = $self->{prefix};
  my $key    = "$prefix-meta";
  my $status = 0;

  eval {
    $status = $self->{handle}->sismember($key, $dc);
  };
  if ($@) {
    $self->{log}->error("sismember $key error: $@");
    $status = 0;
  }
  return $status;
}

# dc unit
sub white_set_dc {
  my $self     = shift;
  my $dc       = shift;
  my $is_white = shift || 0;

  my $prefix= $self->{prefix};
  my $key   = "$prefix-white-$dc";
  my $field = "is_white";
  eval {
    $self->{handle}->hset($key, $field, $is_white);
  };
  if ($@) {
    $self->{log}->error("add $key $field -> $is_white error: $@");
    return 0;
  }
  return 1;
}

# host unit
sub white_set_host {
  my $self     = shift;
  my $dc       = shift;
  my $host     = shift;
  my $is_white = shift || 0;

  my $prefix= $self->{prefix};
  my $key   = "$prefix-white-$dc-$host";
  my $field = "is_white";
  eval {
    $self->{handle}->hset($key, $field, $is_white);
  };
  if ($@) {
    $self->{log}->error("add $key $field -> $is_white error: $@");
    return 0;
  }
  return 1;
}

sub white_set_metric {
  my $self   = shift;
  my $dc     = shift;
  my $host   = shift;
  my $metric = shift;

  my $prefix = $self->{prefix};
  my $is_white = shift || 0;
  my $key   = "$prefix-white-$dc-$host";
  my $field = "$metric";
  eval {
    $self->{handle}->hset($key, $field, $is_white);
  };
  if ($@) {
    $self->{log}->error("add $key $field -> $is_white error: $@");
    return 0;
  }
  return 1;
}

sub common_get {
  my $self = shift;
  my $key  = shift;

  my %res;
  foreach my $k ((qw(dc host metric id time level plevel
                     sample duration recvcnt sendcnt))) {
    $res{$k} = $self->field_get($key, $k);
  }

  return \%res;
}

sub key_get {
  my $self   = shift;
  my %args = @_;

  my @require_args = qw(dc host metric);
  foreach my $arg (@require_args) {
    unless ($args{$arg}) {
      $self->{log}->warning("key-get: need $arg argument");
      return undef;
    }
  }

  my $dc     = $args{dc};
  my $host   = $args{host};
  my $metric = $args{metric};
  my $prefix = $self->{prefix};

  return "$prefix-$dc-$host-$metric";
}

sub level_set {
  my $self = shift;
  my %args = @_;
  my ($key, $status)  = @_;

  eval {
    $self->{handle}->hsetnx($key, $key, $status);
  };
  if ($@) {
    $self->{log}->error("set $key error: $@");
    return 0;
  }
  return 1;
}

sub cnt_incre {
  my $self = shift;
  my ($key, $field) = @_;

  if ($field ne "recvcnt" && $field ne "sendcnt") {
    $self->{log}->warning("cnt_incre: must give recvcnt or sendcnt fileds.");
    return 0;
  }
  eval {
    $self->{handle}->hincrby($key, $field, 1);
  };
  if ($@) {
    $self->{log}->error("incre $key $field error: $@");
    return 0;
  }
  return 1;
}

sub field_set {
  my $self = shift;
  my ($key, $field, $value) = @_;

  eval {
    $self->{handle}->hset($key, $field, $value);
  };
  if ($@) {
    $self->{log}->error("hset $key $field value error: $@");
    return 0;
  }
  return 1;
}

sub field_get {
  my $self = shift;
  my ($key, $field) = @_;

  my $value = undef;
  eval {
    $value = $self->{handle}->hget($key, $field);
  };
  if ($@) {
    $self->{log}->error("hget $key $field value error: $@");
  }
  return $value;
}

1;
