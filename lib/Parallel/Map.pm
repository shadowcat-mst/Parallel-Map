package Parallel::Map;

our $VERSION = '0.000002'; # v0.0.2

$VERSION = eval $VERSION;

use strict;
use warnings;
use Carp;
use IO::Async::Function;
use IO::Async::Loop;
use Future::Utils;
use Exporter 'import';

our @EXPORT = qw(pmap_void pmap_scalar pmap_concat);

my %valid_keys = map +($_ => 1), qw(foreach generate forks concurrent);

my %excludes_key = (
  foreach => 'generate',
  concurrent => 'forks',
);

sub _pmap {
  my ($type, $code, @rest) = @_;

  croak "Invalid Parallel::Map type ${type}"
    unless my $fmap = Future::Utils->can("fmap_${type}");

  if (ref($rest[0]) eq 'ARRAY') {
    push @rest, foreach => shift(@rest);
  } elsif (ref($rest[0]) eq 'CODE') {
    push @rest, generate => shift(@rest);
  }

  croak "Uneven Parallel::Map args" if @rest % 2;

  my %args = @rest;

  if (my @invalid = grep !$valid_keys{$_}, keys %args) {
    croak "Invalid keys for Parallel::Map: ".join(', ', @invalid);
  }

  foreach my $key (keys %args) {
    if (my $excluded = $excludes_key{$key}) {
      croak "Can't pass Parallel::Map both ${key} and ${excluded}"
        if exists $args{$excluded};
    }
  }

  $args{concurrent} = delete $args{forks} if exists $args{forks};

  my $loop = IO::Async::Loop->new;

  my ($call, $func) = do {
    my $wrapped = do {
      my $base_w = sub { local $_ = $_[0]; $code->($_[0]) };
      ($type eq 'scalar'
        ? sub { scalar $base_w->(@_) }
        : ($type eq 'void'
            ? sub { $base_w->(@_); return }
            : $base_w)
      );
    };
    if (!$ENV{PERL_PARALLEL_MAP_NO_FORK}
        and my $par = $args{concurrent} //= 5) {
      my $func = IO::Async::Function->new(code => $wrapped);
      $func->configure(max_workers => $par);
      $loop->add($func);
      (sub { $func->call(args => [ @_ ]) }, $func);
    } else {
      (sub { Future->done($wrapped->(@_)) });
    }
  };

  my $done_f = $fmap->($call, %args);

  my $final_f = $loop->await($done_f);

  if ($func) {
    $loop->await($func->stop);
    $loop->remove($func);
  }

  return $final_f->get;
}

sub pmap_void   (&;@) { _pmap void => @_ }
sub pmap_scalar (&;@) { _pmap scalar => @_ }
sub pmap_concat (&;@) { _pmap concat => @_ }

1;

=head1 NAME

Parallel::Map - Multi processing parallel map code

=head1 SYNOPSIS

  use Parallel::Map;
  
  pmap_void {
    sleep 1;
    warn "${_}\n";
    Future->done;
  } foreach => \@choices, forks => 5;

=head1 DESCRIPTION

All subroutines match L<Future::Utils> C<fmap_> subroutines of the same name.

=head2 pmap_void

  pmap_void { <block> } foreach => \@input;
  pmap_void { <block> } generate => sub { <iterator> }

=head2 pmap_scalar

  pmap_scalar { <block> } foreach => \@input;
  pmap_scalar { <block> } generate => sub { <iterator> }

=head2 pmap_concat

  pmap_concat { <block> } foreach => \@input;
  pmap_concat { <block> } generate => sub { <iterator> }

=head1 AUTHOR

 mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

None yet - maybe this software is perfect! (ahahahahahahahahaha)

=head1 COPYRIGHT

Copyright (c) 2020 the Parallel::Map L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.
