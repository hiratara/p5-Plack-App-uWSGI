package Plack::App::uWSGI;
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use HTTP::Parser::XS qw(parse_http_response HEADERS_AS_ARRAYREF);
use parent 'Plack::Component';
use Plack::Util::Accessor qw/pass modifier1/;

our $VERSION = '0.01_1';

sub pack_env($) {
    my $env = shift;

    my $bytes = '';
    for my $k (keys %$env) {
        next unless ref \ $env->{$k} eq 'SCALAR';

        my $v = $env->{$k};
        $bytes .= (pack "v", length $k) . $k .
                  (pack "v", length $v) . $v;
    }

    return $bytes;
}

sub prepare_app {
    my $self = shift;
    $self->pass or die "Didn't set a pass parameter.";
    $self->modifier1('0') unless defined $self->modifier1;
}

sub send_env {
    my ($self, $handle, $env) = @_;
    my $env_bytes = pack_env $env;
    $handle->push_write(pack "CvC", $self->modifier1, length $env_bytes, 0);
    $handle->push_write($env_bytes);

    my $input = $env->{'psgi.input'};
    $handle->push_write(do { local $/; <$input> }); # TODO: async read
}

sub connect {
    my $self = shift;
    my $cv = AE::cv;

    my ($host, $port) = $self->pass =~ m/^([^:]+)(?::(\d+))?$/;

    tcp_connect $host => $port, sub {
        my $fh = shift;

        unless ($fh) {
            $cv->croak("unable to connect: $!");
        } else {
            my $handle = AnyEvent::Handle->new(fh => $fh);
            $cv->send($handle);
        }
    };

    return $cv;
}

sub call {
    my ($self, $env) = @_;
    $env->{'psgi.streaming'} or die "Server doesn't support psgi.streaming.";

    sub {
        my $respond = shift;
        my $done = AE::cv;

        my ($cur_handle, $cur_writer);
        $self->connect->cb(sub {
            my $cv = shift;
            my ($handle) = $cv->recv;
            $cur_handle = $handle;

            $handle->on_error(sub {
                my ($handle, $fatal, $message) = @_;
                $handle->destroy;
                if ($fatal and $! == 0) { # eof
                    $done->send;
                } else {
                    $done->croak($message);
                }
            });

            $self->send_env($handle, $env);
            $handle->push_read(chunk => 4, sub {
                my ($handle, $chunk) = @_;
                my ($modifier1, $length, $modifier2) = unpack "CvC", $chunk;
                $modifier1 == 72 or $done->croak("unknown response");

                $handle->push_read(regex => qr/\x0d\x0a\x0d\x0a/, sub {
                    my ($handle, $line) = @_;
                    my($ret, $minor_version, $status, $message, $headers)
                                                         = parse_http_response(
                        $chunk . $line, HEADERS_AS_ARRAYREF, {}
                    );
                    $ret > 0 or $done->croak("bad response: $ret");

                    $cur_writer = $respond->([$status, $headers]);
                    $handle->on_read(sub {
                        $cur_writer->write(delete $handle->{rbuf});
                    });
                });
            });
        });

        $done->cb(sub {
            my $cv = shift;
            $cur_writer = $respond->([500, ['Content-Type' => 'text/html']])
                                                            unless $cur_writer;
            eval { $cv->recv };
            $@ and $cur_writer->write($@);

            $cur_writer->close;
        });
        $done->recv unless $env->{"psgi.nonblocking"};
    };
}

1;

__END__

=head1 NAME

Plack::App::uWSGI - a PSGI frontend of uwsgi.

=head1 SYNOPSIS

  $ ./uwsgi --plugins python -s :4321 -w simple_app
  $ plackup -MPlack::App::uWSGI -e 'Plack::App::uWSGI->new(pass => "localhost:4321", modifier1 => "0")->to_app'

=head1 WARNING

B<This module is under development. Few features have been implemented.>

=head1 DESCRIPTION

Plack::App::uWSGI proxies $env to uWSGI servers.

=head1 AUTHOR

Masahiro Honma E<lt>hiratara@cpan.orgE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
