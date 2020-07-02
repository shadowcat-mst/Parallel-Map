use strict;
use warnings;
use List::Util qw(uniq);
use Parallel::Map;
use Test::More;

my @shared;

@shared = pmap_scalar {
  return { num => $_[0], pid => $$ };
} foreach => [1..10];

is @shared, 10, "data lands in subprocess shared variable";
cmp_ok scalar(uniq map $_->{pid}, @shared), '==', 5, "5 pids by default";

@shared = pmap_scalar {
  return { num => $_[0], pid => $$ };
} [1..10], concurrent => 3;

is @shared, 10, "data lands in subprocess shared variable";
cmp_ok scalar(uniq map $_->{pid}, @shared), '==', 3, "3 pids as requested";

@shared = pmap_scalar {
  return { num => $_[0], pid => $$ };
} foreach => [1..10], forks => 0;

is @shared, 10, "data lands in subprocess shared variable";

ok !(grep $_->{pid} != $$, @shared), "no forking with forks => 0";

done_testing;
