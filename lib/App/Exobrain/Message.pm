package App::Exobrain::Message;

use 5.010;
use strict;
use warnings;
use Method::Signatures;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Carp;
use ZMQ::Constants qw(ZMQ_SNDMORE);
use ZMQ::LibZMQ2;
use JSON::Any;

has timestamp => ( is => 'ro', isa => 'Int', default => sub { time() } );
has exobrain  => ( is => 'ro', isa => 'App::Exobrain');
has raw       => ( is => 'ro', isa => 'Ref' );
has namespace => ( is => 'ro', isa => 'Str', required => 1 );
has source    => ( is => 'ro', isa => 'Str', required => 1 );

# This can be used to explicitly set the data, ignoring the
# payload attributes.
has _data     => ( is => 'ro', isa => 'Ref' );

# Many classes will provide their own way of getting summary
# data.

requires qw(summary);

# Automatic conversion between JSON and Perl Refs.

my $json = JSON::Any->new;

subtype 'JSON', as   'Str', where { $json->decode($_) } ;
coerce  'JSON', from 'Ref', via   { $json->encode($_) } ;

=method payload

    payload size => ( isa => 'Int' );

Convenience method which sets the 'payload' trait on an attribute,
as well as marking it as 'ro' and required by default (these
can be overridden).

=cut

func payload($name, @args) {

    # We need to call 'has' from the caller's perspective, so let's
    # find out where we're being called from.

    my ($uplevel) = caller();
    my $uphas = join('::', $uplevel, 'has');

    # Now we'll make the call, as well as adding he payload and ro
    # attributes. We need to turn off strict 'refs' here to assure
    # perl that really it's okay that we're using a string as a
    # subroutine ref.

    no strict 'refs';
    return $uphas->( $name => (traits => [qw(Payload)], is => 'ro', @args) );
}

# TODO: Add method to automatically provide data from payloads.

=method data

    my $data = $message->data;

Messages automatically create a data method (needed for transmitting
over the exobrain bus) by tallying payload attributes.

=cut

use constant PAYLOAD_CLASS => 'App::Exobrain::Message::Trait::Payload';

method data() {
    my $meta     = $self->meta;
    my @attrs    = $self->meta->get_attribute_list;

    my @payloads = grep 
        { $meta->get_attribute($_)->does( PAYLOAD_CLASS ) } @attrs
    ;

    my $data = {};

    # Walk through all our attributes and populate them into a hash.

    foreach my $attr (@payloads) {
        $data->{ $attr } = $self->$attr;
    }

    return $data;
}

=method send_msg($socket?)

Sends the message across the exobrain bus. If no socket is provided,
the one from the exobrain object (if we were built with one) is used.

=cut

method send_msg($socket?) {

    # If we don't have a socket, grab it from our exobrain object
    # (if it exists)

    if (not $socket) {
        if (my $exobrain = $self->exobrain) {
            $socket = $exobrain->pub->_socket;
        }
        else {
            croak "send_msg() is missing a socket or exobrain";
        }
    }

    # For some reason multipart sends don't work right now,
    # $socket->ZMQ::Socket::send_multipart( $self->frames );

    my @frames = $self->_frames;
    my $last   = pop(@frames);

    foreach my $frame ( @frames) {
        zmq_send($socket, $frame, ZMQ_SNDMORE);
    }

    zmq_send($socket,$last);

    return;
}

# Internal method for creating the required frame structure

method _frames() {
    my @frames;

    push(@frames, join("_", "EXOBRAIN", $self->namespace, $self->source));
    push(@frames, "XXX - JSON - timestamp => " . $self->timestamp);
    push(@frames, $self->summary // "");
    push(@frames, $json->encode( $self->data ));
    push(@frames, $json->encode( $self->raw  ));

    return @frames;
}

=method dump()

    my $pkt_debug = $msg->dump;

Provides a string containing a dump of universal packet attributes.
Intended for debugging.

=cut

method dump() {
    my $dumpstr = "";

    foreach my $method ( qw(namespace timestamp source data raw summary)) {
        $dumpstr .= "$method : " . $self->$method . "\n";
    }

    return $dumpstr;
}

package App::Exobrain::Message::Trait::Payload;
use Moose::Role;

Moose::Util::meta_attribute_alias('Payload');

# The payload attribute desn't actually do anything directly, but
# we test for it elsewhere to see if something is part of a
# payload that should be transmitted.

1;
