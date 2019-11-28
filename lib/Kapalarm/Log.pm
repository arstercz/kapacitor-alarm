package Kapalarm::Log;

use strict;
use warnings;
use English qw(-no_match_vars);
use Log::Dispatch qw(add log);
#use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use POSIX qw(strftime);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use constant PTDEBUG => $ENV{PTDEBUG} || 0;
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

require Exporter;
@ISA = qw(Exporter);
@EXPORT    = qw( debug info notice warning error critical alert emergency );
@EXPORT_OK = qw( log );
$VERSION = '0.1.0';

sub filename {
    my $self = shift;
    $self->{filename} = shift if @_;
    return $self->{filename};
}

sub min_level {
    my $self = shift;
    $self->{min_level} = shift if @_;
    return $self->{'min_level'}
}

sub handle {
    my ($self, $mode, $screen) = @_;

    $mode ||= 'append';
    #$self->{handle} = Log::Dispatch->new(
    #    outputs => [
    #        [ 'File',   min_level => 'debug', filename => $self->{filename}, mode => $mode ],
    #    ],
    #);

    
    $self->{handle} = Log::Dispatch->new();
    $self->{handle}->add(
        Log::Dispatch::File->new(
            name     => 'log',
            min_level => $self->{min_level},
            filename  => $self->{filename},
            mode      => $mode,
        )
    );
    
    if( $screen ) {
        $self->{handle}->add(
            Log::Dispatch::Screen->new(
                name       => 'screen',
                min_level  => $self->{min_level},
            )
        );
    }
    return $self->{handle};
}

sub new {
    my ($class, %args) = @_;
    PTDEBUG && _debug(%args);

    
    my $self = {};
    bless $self, $class;
    $self->filename( $args{'filename'} );
    $self->min_level( $args{'min_level'} );
    $self->handle($args{'mode'}, $args{'screen'});

    PTDEBUG && _debug($self->{handle});
    return $self;
}

sub _get_time {
    my $cur_time = strftime( "%Y-%m-%dT%H:%M:%S", localtime(time) );
    return $cur_time;
}

sub log {
   my ($self, %args) = @_;

   my $log_f = $self->{handle};
   foreach my $arg ( qw( message ) ) {
       warn "Need message." unless $args{$arg};
   }

   #print Dumper(%args);
   my $cur_time = _get_time();
   my $level = $args{level};
   my $tag   = "$cur_time -" . " [$level]" . ' ';
   my $msg   = ref($args{message}) eq 'ARRAY' 
             ? $tag . join(" - ", @{$args{message}}) . "\n"
             : $tag . $args{message} . "\n";


   $log_f->log( level => $level, message => $msg );
   return 1;
}

sub debug {
    my $self = shift;
    my $message  = shift || '';
    return $self->log('level' => 'debug', 'message' => $message );
}

sub info {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'info', 'message' => $message );
}

sub notice {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'notice', 'message' => $message );
}

sub warning {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'warning', 'message' => $message );
}

sub error {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'error', 'message' => $message );
}

sub critical {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'critical', 'message' => $message );
}

sub alert {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'alert', 'message' => $message );
}

sub emergency {
    my $self = shift;
    my $message = shift || '';
    return $self->log('level' => 'emergency', 'message' => $message );
}

sub _debug {
  my ($package, undef, $line ) = caller;
  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp }
       map { defined $_ ? $_ : 'undef' }
       @_;

  print STDERR "+-- # $package: $line $PID", join(' ', @_), "\n";
}

1;

# ###################################################################################################
#  Documentation.
# ###################################################################################################

=pod

=head1 NAME

  MMMM::Log::Record - Wrap the Log::Dispatch and log message with a readable format, timestamp 
                            and level info was added.

=head1 REQUIRES

  Log::Dispatch
  Log::Dispatch::File
  Log::Dispatch::Screen

=head1 SYNOPSIS

Examples:

    use MMMM::Log::Record;

    my $log = MMMM::Log::Record->new(
        'filename' => '/var/log/mmm-manager/mmm.log',
        'mode'     => 'append',
        'screen'   => 1,
    );

    my @msg;
    push @msg, 'master status';
    push @msg, 'slave status';

    $log->debug(\@msg);
    $log->error("hello world");

Note that only SCALAR and ARRAY ref type can be allowed. timestamp and level info set in the message
header.

=head1 RISKS

Only several methods in Log::Dispatch are inovked by this module, means that the other method in 
Log::Dispatch cannot be used. common use of this module provide following method:

  Log::Dispatch->new()
  Log::Dispatch->add()
  Log::Dispatch->log()
  Log::Dispatch::File
  Log::Dispatch::Screen

=head1 CONSTRUCTOR

=head2 new ([ ARGS ])

Create a C<SQL::Audit::Log::Record>. filename, mode and screen can be provided which is optinal.

=over 4

=item filename

the file path and file name consist the filename parameter, such as:

    'filename' => './log/audit.log'

Note that it will return error if there is no log directory or no permission to write.

=item mode

defined the open mode to log, default is append, '>>' means append; '>' means overwrite. 
the mode is equivalent to Log::Dispatch open mode

=item screen

enable message output to STDOUT if values great than 0, else disable it.
    
=back

=head1 METHODS

=over 4

=item handle

Return Log::Dispatch handle and the default mode set to append.

=item log

Format the message with timestamp and level info header, and invoke Log::Dispatch->log()
to write message to the file. SCALAR or ARRAY REF type shoule be used.

=item level message

There are  following level message can be used:

    DEBUG
    INFO
    NOTICE
    WARNING
    ERROR
    CRITICAL
    ALERT
    EMERGENCY

invoke method with differ level, such as:

    $log->debug(...)
    $log->notice(..)

=back 

=head1 AUTHOR

arstercz@gmail.com

=head1 CHANGELOG

v0.1.0 version

=cut

