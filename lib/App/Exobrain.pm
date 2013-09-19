package App::Exobrain;
use v5.010;
use strict;
use warnings;
use autodie;
use Moose;

# ABSTRACT: Bloop de bloop blah

# VERSION: Generated by DZP::OurPkg:Version

use App::Exobrain::Bus;
use App::Exobrain::Message;

has 'config' => (
    is => 'ro',
    isa => 'App::Exobrain::Config',
    builder => '_build_config',
);

# Pub/Sub interfaces to our bus. These don't get generated unless
# our end code actually asks for them. Many things will only require
# one, or will use higher-level functions to do their work.

has 'pub' => (
    is => 'ro',
    isa => 'App::Exobrain::Bus',
    builder => '_build_pub',
    lazy => 1,
);

has 'sub' => (
    is => 'ro',
    isa => 'App::Exobrain::Bus',
    builder => '_build_sub',
    lazy => 1,
);

sub _build_config { return App::Exobrain::Config->new; };
sub _build_pub    { return App::Exobrain::Bus->new(type => 'PUB') }
sub _build_sub    { return App::Exobrain::Bus->new(type => 'SUB') }

=for Pod::Coverage BUILD DEMOLISH

=cut

1;
