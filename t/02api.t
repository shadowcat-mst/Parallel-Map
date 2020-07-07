use strict;
use warnings;
use Parallel::Map;
use Test::More;
use Test::Exception;
use Test::Warnings;

my @shared;

lives_ok {
    pmap_void { 'boo'} [1];
} "just an arrayref";

lives_ok {
    pmap_void { 'boo'} foreach => [1];
} "array ref as key";

lives_ok {
    pmap_void { 'boo' } sub { () };
} "generator as subref";

lives_ok {
    pmap_void { 'boo' } generate => sub { () };
} "generator as key";


dies_ok {
    pmap_void { 'boo'} [1], 4;
} "only foreach or genreate can be implicit" and diag $@;

lives_ok {
    pmap_void { 'boo'} foreach => [1], forks => 1;
} "array ref as key with forks as key";

dies_ok {
    pmap_void { 'boo' } sub { () },  1;
} "only foreach or generate can be implicit" and diag $@;

lives_ok {
    pmap_void { 'boo' } generate => sub { () }, forks => 1;
} "generator as key with forks as key";

dies_ok {
    pmap_void { 'boo' } sub { () },  farks => 1;
} "misspell forks makes life sad" and diag $@;

done_testing;
